#!/usr/bin/env bash
# HQ-BUILDER-SPEC.md §19 수락테스트 10
set -euo pipefail
BASE="${BASE_URL:-http://127.0.0.1:3000}"
PASS=0; FAIL=0
pass(){ echo "PASS  $1"; PASS=$((PASS+1)); }
fail(){ echo "FAIL  $1 — $2"; FAIL=$((FAIL+1)); }
j(){ python3 -c 'import json,sys; d=json.load(sys.stdin); '"$1"; }

echo "[spec19] $BASE"
TOK=$(curl -sS -X POST "$BASE/hq/login" -H 'content-type: application/json' -d '{"login":"admin","password":"admin123"}' | j 'print(d["token"])')
AUTH="Authorization: Bearer $TOK"

UA=$(curl -sS -X POST "$BASE/hq/users" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"login\":\"s19a_$RANDOM\",\"name\":\"기사A19\",\"password\":\"x\",\"role\":\"technician\"}")
UB=$(curl -sS -X POST "$BASE/hq/users" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"login\":\"s19b_$RANDOM\",\"name\":\"기사B19\",\"password\":\"x\",\"role\":\"technician\"}")
IDA=$(echo "$UA" | j 'print(d["user_id"])')
IDB=$(echo "$UB" | j 'print(d["user_id"])')

# 1
PHONE="010-$(printf '%04d' $RANDOM)-$(printf '%04d' $RANDOM)"
CUST=$(curl -sS -X POST "$BASE/hq/customers" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"type\":\"franchise\",\"display_name\":\"스펙세차\",\"primary_phone\":\"$PHONE\",\"address\":\"서울\"}")
CID=$(echo "$CUST" | j 'print(d["customer_id"])')
EQ=$(curl -sS -X POST "$BASE/hq/equipment" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"customer_id\":\"$CID\",\"name\":\"펌프\",\"serial\":\"S19-$RANDOM\"}")
EID=$(echo "$EQ" | j 'print(d["equipment_id"])')
TKT=$(curl -sS -X POST "$BASE/hq/tickets" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"customer_id\":\"$CID\",\"equipment_id\":\"$EID\",\"symptom\":\"출장요청\",\"assignee_id\":\"$IDA\",\"region_id\":\"reg-seoul-gangnam\",\"ticket_type\":\"dispatch\"}")
TID=$(echo "$TKT" | j 'print(d["ticket_id"])')
[[ -n "$TID" ]] && pass "1 customer+eq+dispatch+assign A" || fail "1" "$TKT"

# finance region fee
FIN=$(curl -sS -X POST "$BASE/hq/tickets/$TID/finance" -H "$AUTH" -H 'content-type: application/json' \
  -d '{"region_id":"reg-seoul-gangnam"}')
echo "$FIN" | j 'assert d.get("travel_fee")==30000' && pass "4 region travel fee 30000" || fail "4" "$FIN"

# 2
echo "$(curl -sS "$BASE/hq/customers?phone=$PHONE" -H "$AUTH")" | j "assert any(x['customer_id']=='$CID' for x in d)"
pass "2 re-search"

# 3
curl -sS -X POST "$BASE/hq/tickets/$TID/assign" -H "$AUTH" -H 'content-type: application/json' -d "{\"assignee_id\":\"$IDB\"}" >/dev/null
echo "$(curl -sS "$BASE/hq/tickets/$TID" -H "$AUTH")" | j "assert d['ticket']['assignee_id']=='$IDB' and any(e.get('type')=='assign' for e in d['events'])"
pass "3 reassign A→B timeline"

# 5 product + document
PRD=$(curl -sS -X POST "$BASE/hq/products" -H "$AUTH" -H 'content-type: application/json' \
  -d '{"name":"필터","category":"부품","sale_price":8000,"sku":"F1"}')
PID=$(echo "$PRD" | j 'print(d["product_id"])')
DOC=$(curl -sS -X POST "$BASE/hq/documents" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"ticket_id\":\"$TID\",\"doc_type\":\"invoice\",\"labor_fee\":50000,\"bill_type\":\"paid\",\"lines\":[{\"name\":\"필터\",\"qty\":1,\"price\":8000}]}")
DID=$(echo "$DOC" | j 'print(d["doc_id"])')
DL=$(curl -sS "$BASE/hq/documents/$DID/download?format=text" -H "$AUTH")
echo "$DL" | j 'assert "거래명세서" in d.get("title","") or "견적" in d.get("title","") or d.get("content")'
pass "5 product + document download"

# 6 unpaid
curl -sS -X POST "$BASE/hq/tickets/$TID/finance" -H "$AUTH" -H 'content-type: application/json' \
  -d '{"settlement_status":"미수","settlement_paid":0}' >/dev/null
UN=$(curl -sS "$BASE/hq/unpaid" -H "$AUTH")
echo "$UN" | j "assert any(x.get('ticket_id')=='$TID' for x in d)"
DASH=$(curl -sS "$BASE/hq/dashboard" -H "$AUTH")
echo "$DASH" | j 'assert d.get("unpaid",0)>=1'
pass "6 unpaid badge/list"

# 7 repeat
curl -sS -X POST "$BASE/hq/tickets/$TID/transition" -H "$AUTH" -H 'content-type: application/json' -d '{"to":"en_route"}' >/dev/null || true
# may fail if status not assigned path - ensure assigned then transition
curl -sS -X POST "$BASE/hq/tickets/$TID/transition" -H "$AUTH" -H 'content-type: application/json' -d '{"to":"en_route"}' >/dev/null
curl -sS -X POST "$BASE/hq/tickets/$TID/transition" -H "$AUTH" -H 'content-type: application/json' -d '{"to":"repairing"}' >/dev/null
curl -sS -X POST "$BASE/hq/tickets/$TID/transition" -H "$AUTH" -H 'content-type: application/json' -d '{"to":"done"}' >/dev/null
export AFLDB_WRITE_KEY="${AFLDB_WRITE_KEY:-$(pm2 env 0 2>/dev/null | awk -F': ' '/AFLDB_WRITE_KEY/{print $2; exit}')}"
MS=$(( $(date +%s%3N) - 20*86400000 ))
curl -sS -X PATCH "http://127.0.0.1:40610/v2/tables/hq_ticket_meta/rows/$TID" \
  -H "content-type: application/json" -H "x-api-key: $AFLDB_WRITE_KEY" -d "{\"completed_ms\":$MS}" >/dev/null || true
TK2=$(curl -sS -X POST "$BASE/hq/tickets" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"customer_id\":\"$CID\",\"equipment_id\":\"$EID\",\"symptom\":\"재발\",\"region_id\":\"reg-seoul-gangnam\"}")
echo "$TK2" | j 'assert d.get("is_repeat")=="true"'
pass "7 repeat 20d"

# 8 payroll monthly excel
YM=$(date +%Y-%m)
PAY=$(curl -sS -X POST "$BASE/hq/payroll" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"user_id\":\"$IDA\",\"year_month\":\"$YM\",\"base_pay\":3000000,\"allowances\":200000,\"deductions\":50000}")
echo "$PAY" | j 'assert d.get("total")==3150000'
REP=$(curl -sS "$BASE/hq/reports?kind=monthly" -H "$AUTH")
echo "$REP" | j 'assert "급여총액" in d.get("csv","") and int(d["summary"]["payroll_total"])>=3150000'
PLIST=$(curl -sS "$BASE/hq/payroll?year_month=$YM" -H "$AUTH")
echo "$PLIST" | j "assert any(x.get('user_id')=='$IDA' and x.get('total')==3150000 for x in d)"
pass "8 payroll total 3150000 in ledger + monthly csv"

# 9 expense approve
EX=$(curl -sS -X POST "$BASE/hq/expenses" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"user_id\":\"$IDA\",\"amount\":12000,\"category\":\"유류\",\"memo\":\"출장\"}")
EID2=$(echo "$EX" | j 'print(d["expense_id"])')
curl -sS -X POST "$BASE/hq/expenses/$EID2/decide" -H "$AUTH" -H 'content-type: application/json' \
  -d '{"status":"approved"}' >/dev/null
echo "$(curl -sS "$BASE/hq/expenses" -H "$AUTH")" | j "assert any(x['expense_id']=='$EID2' and x['status']=='approved' for x in d)"
pass "9 expense approve"

# 10 resigned
curl -sS -X PUT "$BASE/hq/users/$IDB" -H "$AUTH" -H 'content-type: application/json' -d '{"employment_status":"resigned"}' >/dev/null
ASS=$(curl -sS "$BASE/hq/users?assignable=1" -H "$AUTH")
echo "$ASS" | j "assert all(x['user_id']!='$IDB' for x in d)"
echo "$(curl -sS "$BASE/hq/tickets/$TID" -H "$AUTH")" | j "assert d['ticket']['assignee_id']=='$IDB'"
pass "10 resigned exclude + past ticket kept"

echo ""; echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
