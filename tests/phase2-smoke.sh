#!/usr/bin/env bash
# Phase 2 API smoke against a running AFJ server.
set -euo pipefail

BASE="${HQ_BASE:-${BASE_URL:-http://127.0.0.1:30000}}"
PASS=0
FAIL=0

assert_http() {
  local name="$1" got="$2" want="$3"
  if [[ "$got" == "$want" ]]; then
    echo "PASS  $name (HTTP $got)"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $name (HTTP $got, want $want)"
    FAIL=$((FAIL + 1))
  fi
}

json_field() {
  python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get(sys.argv[1],""))' "$1"
}

echo "[phase2-smoke] base=$BASE"

code=$(curl -sS -o /tmp/bw-h.json -w '%{http_code}' "$BASE/health")
assert_http "GET /health" "$code" "200"

code=$(curl -sS -o /tmp/bw-login.json -w '%{http_code}' -X POST "$BASE/admin/login" \
  -H 'content-type: application/json' -d '{"username":"admin","password":"admin123"}')
assert_http "POST /admin/login" "$code" "200"
TOKEN=$(json_field token < /tmp/bw-login.json)
AUTH="Authorization: Bearer $TOKEN"

PHONE="010-$(printf '%04d' $((RANDOM % 10000)))-$(printf '%04d' $((RANDOM % 10000)))"
code=$(curl -sS -o /tmp/bw-reg.json -w '%{http_code}' -X POST "$BASE/as/register" \
  -H 'content-type: application/json' \
  -d "{\"customer_name\":\"스모크\",\"customer_phone\":\"$PHONE\",\"equipment_name\":\"테스트\",\"symptom\":\"자동검증\",\"address\":\"서울\"}")
assert_http "POST /as/register" "$code" "201"
AS_ID=$(json_field id < /tmp/bw-reg.json)

code=$(curl -sS -o /tmp/bw-sched.json -w '%{http_code}' -X POST "$BASE/as/$AS_ID/schedule" \
  -H "$AUTH" -H 'content-type: application/json' \
  -d '{"scheduled_date":"2026-10-01","scheduled_time":"10:00","technician_id":"tech-smoke"}')
assert_http "POST /as/:id/schedule" "$code" "201"

code=$(curl -sS -o /tmp/bw-schg.json -w '%{http_code}' "$BASE/as/$AS_ID/schedule" -H "$AUTH")
assert_http "GET /as/:id/schedule" "$code" "200"

B64='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='
code=$(curl -sS -o /tmp/bw-ph.json -w '%{http_code}' -X POST "$BASE/as/$AS_ID/photo" \
  -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"photo_type\":\"before\",\"image_base64\":\"$B64\",\"mime\":\"image/png\"}")
assert_http "POST /as/:id/photo before" "$code" "201"

code=$(curl -sS -o /tmp/bw-ph2.json -w '%{http_code}' -X POST "$BASE/as/$AS_ID/photo" \
  -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"photo_type\":\"after\",\"image_base64\":\"$B64\",\"mime\":\"image/png\"}")
assert_http "POST /as/:id/photo after" "$code" "201"

code=$(curl -sS -o /tmp/bw-phs.json -w '%{http_code}' "$BASE/as/$AS_ID/photos" -H "$AUTH")
assert_http "GET /as/:id/photos" "$code" "200"

code=$(curl -sS -o /tmp/bw-log.json -w '%{http_code}' -X PUT "$BASE/as/$AS_ID/service-log" \
  -H "$AUTH" -H 'content-type: application/json' \
  -d '{"work_description":"스모크 점검","labor_time":1,"parts_used":[{"name":"필터","quantity":1,"price":1000}]}')
assert_http "PUT /as/:id/service-log" "$code" "200"

code=$(curl -sS -o /tmp/bw-logg.json -w '%{http_code}' "$BASE/as/$AS_ID/service-log" -H "$AUTH")
assert_http "GET /as/:id/service-log" "$code" "200"

code=$(curl -sS -o /tmp/bw-bill.json -w '%{http_code}' -X POST "$BASE/as/$AS_ID/billing" \
  -H "$AUTH" -H 'content-type: application/json' \
  -d '{"parts_cost":1000,"labor_cost":2000,"service_fee":3000,"payment_method":"card","payment_status":"pending"}')
assert_http "POST /as/:id/billing" "$code" "201"

code=$(curl -sS -o /tmp/bw-list.json -w '%{http_code}' "$BASE/as/list" -H "$AUTH")
assert_http "GET /as/list" "$code" "200"

code=$(curl -sS -o /tmp/bw-cust.json -w '%{http_code}' "$BASE/customer/requests?phone=$PHONE")
assert_http "GET /customer/requests" "$code" "200"

code=$(curl -sS -o /dev/null -w '%{http_code}' "$BASE/register.html")
assert_http "GET /register.html" "$code" "200"

code=$(curl -sS -o /dev/null -w '%{http_code}' "$BASE/customer.html")
assert_http "GET /customer.html" "$code" "200"

echo ""
echo "PASS=$PASS FAIL=$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
echo "ALL PASS"
