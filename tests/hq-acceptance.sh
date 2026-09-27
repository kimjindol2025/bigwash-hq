#!/usr/bin/env bash
# ACCEPTANCE-TESTS.md 10시나리오
set -euo pipefail
BASE="${HQ_BASE:-${BASE_URL:-http://127.0.0.1:30000}}"
PASS=0
FAIL=0
pass() { echo "PASS  $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL  $1 — $2"; FAIL=$((FAIL+1)); }

json() { python3 -c 'import json,sys; d=json.load(sys.stdin); '"$1"; }

echo "[hq-acceptance] $BASE"

TOK=$(curl -sS -X POST "$BASE/hq/login" -H 'content-type: application/json' \
  -d '{"login":"admin","password":"admin123"}' | json 'print(d["token"])')
AUTH="Authorization: Bearer $TOK"

# --- 1. 직원 2명 등록, 1명 휴직 → 지정 목록 제외 ---
U1=$(curl -sS -X POST "$BASE/hq/users" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"login\":\"acc_a_$RANDOM\",\"name\":\"수락A\",\"password\":\"x\",\"role\":\"technician\"}")
U2=$(curl -sS -X POST "$BASE/hq/users" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"login\":\"acc_b_$RANDOM\",\"name\":\"수락B\",\"password\":\"x\",\"role\":\"technician\"}")
ID1=$(echo "$U1" | json 'print(d.get("user_id",""))')
ID2=$(echo "$U2" | json 'print(d.get("user_id",""))')
curl -sS -X PUT "$BASE/hq/users/$ID2" -H "$AUTH" -H 'content-type: application/json' \
  -d '{"employment_status":"leave"}' >/dev/null
ASSIGNABLE=$(curl -sS "$BASE/hq/users?assignable=1" -H "$AUTH")
echo "$ASSIGNABLE" | python3 -c "
import json,sys
rows=json.load(sys.stdin)
ids=[r['user_id'] for r in rows]
ok=('$ID1' in ids) and ('$ID2' not in ids)
sys.exit(0 if ok else 1)
" && pass "1 staff leave excluded from assignable" || fail "1" "leave user still assignable or A missing"

# --- 2. 검색없음 → 고객 → 장비 → AS → A지정 ---
PHONE="010-$(printf '%04d' $((RANDOM%10000)))-$(printf '%04d' $((RANDOM%10000)))"
EMPTY=$(curl -sS "$BASE/hq/customers?phone=$PHONE" -H "$AUTH")
echo "$EMPTY" | json 'import sys; assert d==[]'
CUST=$(curl -sS -X POST "$BASE/hq/customers" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"type\":\"franchise\",\"display_name\":\"수락세차\",\"primary_phone\":\"$PHONE\",\"address\":\"서울\"}")
CID=$(echo "$CUST" | json 'print(d["customer_id"])')
EQ=$(curl -sS -X POST "$BASE/hq/equipment" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"customer_id\":\"$CID\",\"name\":\"진공\",\"model\":\"V1\",\"serial\":\"S-$RANDOM\"}")
EID=$(echo "$EQ" | json 'print(d["equipment_id"])')
# no equipment reject
code=$(curl -sS -o /tmp/noeq.json -w '%{http_code}' -X POST "$BASE/hq/tickets" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"customer_id\":\"$CID\",\"equipment_id\":\"\",\"symptom\":\"x\"}")
[[ "$code" == "400" ]] || fail "2a" "equipment required expected 400 got $code"
TKT=$(curl -sS -X POST "$BASE/hq/tickets" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"customer_id\":\"$CID\",\"equipment_id\":\"$EID\",\"symptom\":\"누수\",\"urgency\":\"normal\",\"assignee_id\":\"$ID1\",\"bill_type\":\"warranty\"}")
TID=$(echo "$TKT" | json 'print(d["ticket_id"])')
ST=$(echo "$TKT" | json 'print(d["status"])')
[[ "$ST" == "assigned" && -n "$TID" ]] && pass "2 customer+equipment+ticket+assign A" || fail "2" "ticket=$TKT"

# --- 3. 같은 번호 재검색 ---
HUB=$(curl -sS "$BASE/hq/customers?phone=$PHONE" -H "$AUTH")
echo "$HUB" | python3 -c "
import json,sys
rows=json.load(sys.stdin)
assert any(r['customer_id']=='$CID' for r in rows)
" 
EQS=$(curl -sS "$BASE/hq/equipment?customer_id=$CID" -H "$AUTH")
echo "$EQS" | python3 -c "import json,sys; assert any(e['equipment_id']=='$EID' for e in json.load(sys.stdin))"
TKS=$(curl -sS "$BASE/hq/tickets" -H "$AUTH")
echo "$TKS" | python3 -c "import json,sys; assert any(t['ticket_id']=='$TID' for t in json.load(sys.stdin))"
pass "3 re-search customer equipment ticket"

# --- 4. 담당 A→B, 타임라인 ---
# need another active user - create C or use ID1 and create active B2
UB=$(curl -sS -X POST "$BASE/hq/users" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"login\":\"acc_c_$RANDOM\",\"name\":\"수락C\",\"password\":\"x\",\"role\":\"dispatcher\"}")
IDC=$(echo "$UB" | json 'print(d["user_id"])')
curl -sS -X POST "$BASE/hq/tickets/$TID/assign" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"assignee_id\":\"$IDC\"}" >/dev/null
DET=$(curl -sS "$BASE/hq/tickets/$TID" -H "$AUTH")
echo "$DET" | python3 -c "
import json,sys
d=json.load(sys.stdin)
assert d['ticket']['assignee_id']=='$IDC'
ev=d['events']
assert any(e.get('type')=='assign' for e in ev)
" && pass "4 reassign A→C + timeline" || fail "4" "assign/timeline"

# --- 5. 동일장비 재접수 → 재고장 (완료 후 20일 이내 시뮬레이션) ---
# complete first ticket path to done then followup not required for repeat - need completed_ms
curl -sS -X POST "$BASE/hq/tickets/$TID/transition" -H "$AUTH" -H 'content-type: application/json' -d '{"to":"en_route"}' >/dev/null
curl -sS -X POST "$BASE/hq/tickets/$TID/transition" -H "$AUTH" -H 'content-type: application/json' -d '{"to":"repairing"}' >/dev/null
curl -sS -X POST "$BASE/hq/tickets/$TID/transition" -H "$AUTH" -H 'content-type: application/json' -d '{"to":"done"}' >/dev/null
# backdate completed_ms to 20 days ago via AFL-DB patch
export AFLDB_WRITE_KEY="${AFLDB_WRITE_KEY:-$(pm2 env 0 2>/dev/null | awk -F': ' '/AFLDB_WRITE_KEY/{print $2; exit}')}"
MS=$(( $(date +%s%3N) - 20*86400000 ))
curl -sS -X PATCH "http://127.0.0.1:40610/v2/tables/hq_ticket_meta/rows/$TID" \
  -H "content-type: application/json" -H "x-api-key: $AFLDB_WRITE_KEY" \
  -d "{\"completed_ms\":$MS}" >/dev/null || true
TKT2=$(curl -sS -X POST "$BASE/hq/tickets" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"customer_id\":\"$CID\",\"equipment_id\":\"$EID\",\"symptom\":\"재발\",\"urgency\":\"normal\",\"bill_type\":\"paid\"}")
echo "$TKT2" | json 'assert d.get("is_repeat")=="true"' && pass "5 repeat within 30d" || fail "5" "$TKT2"

# --- 6. 사진없이 완료 → 사진미비 ---
# TKT2 is waiting_assign; assign and complete
TID2=$(echo "$TKT2" | json 'print(d["ticket_id"])')
curl -sS -X POST "$BASE/hq/tickets/$TID2/assign" -H "$AUTH" -H 'content-type: application/json' -d "{\"assignee_id\":\"$ID1\"}" >/dev/null
curl -sS -X POST "$BASE/hq/tickets/$TID2/transition" -H "$AUTH" -H 'content-type: application/json' -d '{"to":"en_route"}' >/dev/null
curl -sS -X POST "$BASE/hq/tickets/$TID2/transition" -H "$AUTH" -H 'content-type: application/json' -d '{"to":"done"}' >/dev/null
DET2=$(curl -sS "$BASE/hq/tickets/$TID2" -H "$AUTH")
echo "$DET2" | json 'assert d["ticket"]["status"]=="done" and d["ticket"].get("photo_incomplete")=="true"'
FU=$(curl -sS "$BASE/hq/followups" -H "$AUTH")
echo "$FU" | python3 -c "import json,sys; d=json.load(sys.stdin); rows=d['photo'] if isinstance(d, dict) else d; assert any(t['ticket_id']=='$TID2' for t in rows)"
pass "6 done without photo → incomplete list"

# --- 7. 사후확인 → 종결 ---
curl -sS -X POST "$BASE/hq/tickets/$TID2/transition" -H "$AUTH" -H 'content-type: application/json' -d '{"to":"followup"}' >/dev/null
curl -sS -X POST "$BASE/hq/tickets/$TID2/transition" -H "$AUTH" -H 'content-type: application/json' -d '{"to":"closed"}' >/dev/null
echo "$(curl -sS "$BASE/hq/tickets/$TID2" -H "$AUTH")" | json 'assert d["ticket"]["status"]=="closed"'
pass "7 followup → closed"

# --- 8. 전화 변경 → 옛번호 검색 ---
OLD=$PHONE
NEW="010-$(printf '%04d' $((RANDOM%10000)))-$(printf '%04d' $((RANDOM%10000)))"
curl -sS -X POST "$BASE/hq/customers/$CID/phone" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"primary_phone\":\"$NEW\"}" >/dev/null
FOUND_OLD=$(curl -sS "$BASE/hq/customers?phone=$OLD" -H "$AUTH")
FOUND_NEW=$(curl -sS "$BASE/hq/customers?phone=$NEW" -H "$AUTH")
echo "$FOUND_OLD" | python3 -c "import json,sys; assert any(r['customer_id']=='$CID' for r in json.load(sys.stdin))"
echo "$FOUND_NEW" | python3 -c "import json,sys; assert any(r['customer_id']=='$CID' for r in json.load(sys.stdin))"
pass "8 phone change old+new search"

# --- 9. 퇴사 직원 과거 티켓 유지 ---
curl -sS -X PUT "$BASE/hq/users/$IDC" -H "$AUTH" -H 'content-type: application/json' \
  -d '{"employment_status":"resigned"}' >/dev/null
DET9=$(curl -sS "$BASE/hq/tickets/$TID" -H "$AUTH")
echo "$DET9" | json 'assert d["ticket"]["assignee_id"]=="'"$IDC"'"'
pass "9 resigned staff past ticket intact"

# --- 10. company_id 격리 ---
export AFLDB_ADMIN_KEY="${AFLDB_ADMIN_KEY:-$(pm2 env 0 2>/dev/null | awk -F': ' '/AFLDB_ADMIN_KEY/{print $2; exit}')}"
export AFLDB_WRITE_KEY="${AFLDB_WRITE_KEY:-$(pm2 env 0 2>/dev/null | awk -F': ' '/AFLDB_WRITE_KEY/{print $2; exit}')}"
OTHER="company-other-isolation"
curl -sS -X POST http://127.0.0.1:40610/v2/tables/hq_customers/rows \
  -H "content-type: application/json" -H "x-api-key: $AFLDB_WRITE_KEY" \
  -d "{\"customer_id\":\"cust-other-iso\",\"company_id\":\"$OTHER\",\"type\":\"shop\",\"display_name\":\"타사\",\"primary_phone\":\"010-0000-0000\",\"extra_phone\":\"\",\"contact_name\":\"\",\"contact_phone\":\"\",\"address\":\"\",\"visit_note\":\"\",\"status\":\"active\",\"account_owner_user_id\":\"\",\"tags\":\"\",\"hours_note\":\"\",\"created_at\":\"2026-01-01T00:00:00Z\",\"updated_at\":\"2026-01-01T00:00:00Z\"}" >/dev/null || true
LIST=$(curl -sS "$BASE/hq/customers" -H "$AUTH")
echo "$LIST" | python3 -c "
import json,sys
rows=json.load(sys.stdin)
assert all(r.get('company_id')=='company-hq-001' for r in rows)
assert not any(r.get('customer_id')=='cust-other-iso' for r in rows)
" && pass "10 tenant isolation company_id" || fail "10" "leak"

echo ""
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
