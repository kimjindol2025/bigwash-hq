#!/usr/bin/env bash
# 돈 모듈 손테스트 1–8 + 패치 확인 (부분수금 모달 표식, 용병 일정)
set -euo pipefail
BASE="${HQ_BASE:-${BASE_URL:-http://127.0.0.1:30000}}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0; FAIL=0
pass(){ echo "PASS  $1"; PASS=$((PASS+1)); }
fail(){ echo "FAIL  $1 — $2"; FAIL=$((FAIL+1)); }
j(){ python3 -c 'import json,sys; d=json.load(sys.stdin); '"$1"; }

echo "[hq-money] $BASE"
TOK=$(curl -sS -X POST "$BASE/hq/login" -H 'content-type: application/json' -d '{"login":"admin","password":"admin123"}' | j 'print(d["token"])')
AUTH="Authorization: Bearer $TOK"

# UI 표식: prompt 제거, 시간 필드, 급여 블록은 경리만
HTML=$(curl -sS "$BASE/hq/app.html")
printf '%s' "$HTML" > /tmp/hq-money-app.html
grep -F -q 'id="schTime"' /tmp/hq-money-app.html && pass "patch schedule time input" || fail "patch schedule time input" "schTime missing"
grep -F -q "prompt('받은금액" /tmp/hq-money-app.html && fail "patch partial modal" "prompt still present" || pass "patch partial pay is modal"
grep -F -q "window.prompt('방문일시" /tmp/hq-money-app.html && fail "patch schedule prompt" "visit prompt still present" || pass "patch schedule has no visit prompt"
grep -F -q 'const payBlock = money ?' /tmp/hq-money-app.html && pass "patch payroll block hidden unless money role" || fail "patch payroll block" "payBlock not gated"

# 1 미수 뱃지
PHONE="010-$(printf '%04d' $RANDOM)-$(printf '%04d' $RANDOM)"
CUST=$(curl -sS -X POST "$BASE/hq/customers" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"type\":\"shop\",\"display_name\":\"돈테스트\",\"primary_phone\":\"$PHONE\",\"address\":\"서울\"}")
CID=$(echo "$CUST" | j 'print(d["customer_id"])')
EQ=$(curl -sS -X POST "$BASE/hq/equipment" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"customer_id\":\"$CID\",\"name\":\"펌프A\",\"location_note\":\"베이\"}")
EID=$(echo "$EQ" | j 'print(d["equipment_id"])')
TKT=$(curl -sS -X POST "$BASE/hq/tickets" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"customer_id\":\"$CID\",\"equipment_id\":\"$EID\",\"symptom\":\"정산테스트\",\"region_id\":\"reg-seoul-gangnam\"}")
TID=$(echo "$TKT" | j 'print(d["ticket_id"])')
curl -sS -X POST "$BASE/hq/tickets/$TID/finance" -H "$AUTH" -H 'content-type: application/json' \
  -d '{"settlement_status":"미수","settlement_paid":0}' >/dev/null
UNPAID=$(curl -sS "$BASE/hq/settlements?tab=unpaid" -H "$AUTH")
echo "$UNPAID" | j "rows=d.get('rows',[]); assert any(r.get('ticket_id')=='$TID' and r.get('settlement_status')=='미수' for r in rows)"
pass "1 unpaid badge 미수"

# 2 카드완납 → 미수에서 빠지고 출장수금
curl -sS -X POST "$BASE/hq/tickets/$TID/finance" -H "$AUTH" -H 'content-type: application/json' \
  -d '{"settlement_status":"카드완납","settlement_paid":10000,"settlement_method":"카드"}' >/dev/null
UNPAID2=$(curl -sS "$BASE/hq/settlements?tab=unpaid" -H "$AUTH")
echo "$UNPAID2" | j "rows=d.get('rows',[]); assert not any(r.get('ticket_id')=='$TID' for r in rows)"
COL=$(curl -sS "$BASE/hq/settlements?tab=collected&period=all" -H "$AUTH")
echo "$COL" | j "rows=d.get('rows',[]); assert any(r.get('ticket_id')=='$TID' and r.get('settlement_status')=='카드완납' for r in rows)"
pass "2 card paid leaves unpaid"

# 3 경비 승인 → 대기 감소
STAFF=$(curl -sS "$BASE/hq/users" -H "$AUTH" | j 'print(next(u["user_id"] for u in d if u.get("employment_status")=="active"))')
rm -f /tmp/bigwash-hq-dash-*.json
EXP=$(curl -sS -X POST "$BASE/hq/expenses" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"user_id\":\"$STAFF\",\"amount\":5500,\"category\":\"식대\",\"memo\":\"money\",\"receipt_note\":\"영수증\"}")
EID_EXP=$(echo "$EXP" | j 'print(d["expense_id"])')
rm -f /tmp/bigwash-hq-dash-*.json
MID=$(curl -sS "$BASE/hq/dashboard" -H "$AUTH" | j 'print(d.get("expense_pending",0))')
curl -sS -X POST "$BASE/hq/expenses/$EID_EXP/decide" -H "$AUTH" -H 'content-type: application/json' \
  -d '{"status":"approved"}' >/dev/null
rm -f /tmp/bigwash-hq-dash-*.json
AFTER=$(curl -sS "$BASE/hq/dashboard" -H "$AUTH" | j 'print(d.get("expense_pending",0))')
python3 - <<PY
assert int("$MID") > int("$AFTER"), ("$MID","$AFTER")
PY
pass "3 expense approve drops pending ($MID -> $AFTER)"

# 4 운영비 → 월 보고
YM=$(date +%Y-%m)
BEFORE_OPS=$(curl -sS "$BASE/hq/reports?period=monthly" -H "$AUTH" | j 'print(d["summary"]["ops_sum"])')
curl -sS -X POST "$BASE/hq/opex" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"year_month\":\"$YM\",\"category\":\"임대\",\"amount\":120000,\"memo\":\"money rent\"}" >/dev/null
AFTER_OPS=$(curl -sS "$BASE/hq/reports?period=monthly" -H "$AUTH" | j 'print(d["summary"]["ops_sum"])')
python3 - <<PY
assert int(float("$AFTER_OPS")) >= int(float("$BEFORE_OPS")) + 120000
PY
pass "4 opex in monthly ops_sum"

# 5 급여총액
curl -sS -X POST "$BASE/hq/payroll" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"user_id\":\"$STAFF\",\"year_month\":\"$YM\",\"base_pay\":3000000,\"allowances\":200000,\"deductions\":100000,\"note\":\"money\"}" >/dev/null
PAY=$(curl -sS "$BASE/hq/payroll?year_month=$YM" -H "$AUTH")
echo "$PAY" | j "assert any(p.get('user_id')=='$STAFF' and int(p.get('total') or 0)==3100000 for p in d)"
REP=$(curl -sS "$BASE/hq/reports?period=monthly" -H "$AUTH")
echo "$REP" | j "assert int(d['summary']['payroll_total'] or 0) >= 3100000 and '급여총액' in (d.get('csv') or '')"
pass "5 payroll total in monthly report"

# 6 용병 급여 없음
CTR=$(curl -sS -X POST "$BASE/hq/contractors" -H "$AUTH" -H 'content-type: application/json' -d '{"name":"용병돈"}')
echo "$CTR" | j "assert 'payroll_id' not in d and 'base_pay' not in d"
CODE=$(curl -sS -o /dev/null -w "%{http_code}" "$BASE/hq/contractors/$(echo "$CTR" | j 'print(d["contractor_id"])')/payroll" -H "$AUTH" || true)
test "$CODE" = "404" && pass "6 contractor has no payroll route" || fail "6 contractor payroll" "http $CODE"

# 7 일/주/월 + CSV
for p in daily weekly monthly; do
  curl -sS "$BASE/hq/reports?period=$p" -H "$AUTH" | j "assert 'summary' in d and len(d.get('csv') or '')>0"
done
pass "7 daily weekly monthly csv"

# 8 tech 급여 403
CL=$(curl -sS -X POST "$BASE/hq/users" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"login\":\"techmoney_$RANDOM\",\"name\":\"기사돈\",\"password\":\"c123\",\"role\":\"technician\"}")
CLOGIN=$(echo "$CL" | j 'print(d["login"])')
CTOK=$(curl -sS -X POST "$BASE/hq/login" -H 'content-type: application/json' -d "{\"login\":\"$CLOGIN\",\"password\":\"c123\"}" | j 'print(d["token"])')
CODE8=$(curl -sS -o /tmp/hq-money-403.json -w "%{http_code}" -X POST "$BASE/hq/payroll" -H "Authorization: Bearer $CTOK" -H 'content-type: application/json' \
  -d "{\"user_id\":\"$STAFF\",\"year_month\":\"$YM\",\"base_pay\":1,\"allowances\":0,\"deductions\":0}")
test "$CODE8" = "403" && pass "8 tech payroll 403" || fail "8 tech payroll" "http $CODE8"

# 용병 배정이 스케줄 응답 assignees에 보임
DAY=$(date +%F)
CNAME="용병일정$RANDOM"
curl -sS -X POST "$BASE/hq/contractors" -H "$AUTH" -H 'content-type: application/json' -d "{\"name\":\"$CNAME\"}" >/dev/null
curl -sS -X POST "$BASE/hq/tickets/$TID/assignees" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"assignees\":[{\"kind\":\"staff\",\"user_id\":\"$STAFF\",\"is_primary\":\"true\"},{\"kind\":\"contractor\",\"contractor_name\":\"$CNAME\",\"day_pay_amount\":150000,\"is_primary\":\"false\"}]}" >/dev/null
curl -sS -X POST "$BASE/hq/tickets/$TID/schedule" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"scheduled_at\":\"${DAY}T10:00\"}" >/dev/null
SCH=$(curl -sS "$BASE/hq/schedule?date=$DAY" -H "$AUTH")
echo "$SCH" | j "rows=d.get('tickets',[]); assert any(t.get('ticket_id')=='$TID' and any((a.get('contractor_name') or '')=='$CNAME' for a in (t.get('assignees') or [])) for t in rows)"
pass "contractor assignee visible on schedule"

# 기사 상품 목록에 원가 숫자 없음
PRODS=$(curl -sS "$BASE/hq/products" -H "Authorization: Bearer $CTOK")
echo "$PRODS" | j "assert all((p.get('cost_price') in ('', None)) for p in d)"
pass "tech product list hides cost"

echo "---- $PASS passed, $FAIL failed ----"
test "$FAIL" = "0"
