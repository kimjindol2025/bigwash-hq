#!/usr/bin/env bash
# HQ-BUILDER-SPEC §20 추가 수락 11–20 (+ 레거시 차단)
set -euo pipefail
BASE="${BASE_URL:-http://127.0.0.1:3000}"
PASS=0; FAIL=0
pass(){ echo "PASS  $1"; PASS=$((PASS+1)); }
fail(){ echo "FAIL  $1 — $2"; FAIL=$((FAIL+1)); }
j(){ python3 -c 'import json,sys; d=json.load(sys.stdin); '"$1"; }

echo "[spec20] $BASE"
TOK=$(curl -sS -X POST "$BASE/hq/login" -H 'content-type: application/json' -d '{"login":"admin","password":"admin123"}' | j 'print(d["token"])')
AUTH="Authorization: Bearer $TOK"

PHONE="010-$(printf '%04d' $RANDOM)-$(printf '%04d' $RANDOM)"
CUST=$(curl -sS -X POST "$BASE/hq/customers" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"type\":\"franchise\",\"display_name\":\"구매세차\",\"primary_phone\":\"$PHONE\",\"address\":\"서울\"}")
CID=$(echo "$CUST" | j 'print(d["customer_id"])')
curl -sS -X POST "$BASE/hq/customers/$CID/extra" -H "$AUTH" -H 'content-type: application/json' \
  -d '{"region_id":"reg-seoul-gangnam","grade":"VIP"}' >/dev/null

PRD=$(curl -sS -X POST "$BASE/hq/products" -H "$AUTH" -H 'content-type: application/json' \
  -d '{"name":"고압기세트","category":"장비","sale_price":1000000,"fulfill_type":"ship"}')
PID=$(echo "$PRD" | j 'print(d["product_id"])')
PRD2=$(curl -sS -X POST "$BASE/hq/products" -H "$AUTH" -H 'content-type: application/json' \
  -d '{"name":"설치키트","category":"장비","sale_price":500000,"fulfill_type":"install"}')
PID2=$(echo "$PRD2" | j 'print(d["product_id"])')

# 11 ship purchase free at +200d, paid at +400d
curl -sS -X POST "$BASE/hq/purchases" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"customer_id\":\"$CID\",\"product_id\":\"$PID\",\"fulfill_type\":\"ship\",\"confirm_date\":\"2025-01-01\"}" >/dev/null
H200=$(curl -sS "$BASE/hq/warranty-hint?customer_id=$CID&as_of=2025-07-20" -H "$AUTH")
H400=$(curl -sS "$BASE/hq/warranty-hint?customer_id=$CID&as_of=2026-03-01" -H "$AUTH")
echo "$H200" | j 'assert d["warranty"]=="free"'
echo "$H400" | j 'assert d["warranty"]=="paid"'
pass "11 purchase warranty 200d free / 400d paid"

# 12 install purchase — confirm_date is install date
EQ=$(curl -sS -X POST "$BASE/hq/equipment" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"customer_id\":\"$CID\",\"name\":\"설치형펌프\",\"location_note\":\"베이1\"}")
EID=$(echo "$EQ" | j 'print(d["equipment_id"])')
curl -sS -X POST "$BASE/hq/purchases" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"customer_id\":\"$CID\",\"product_id\":\"$PID2\",\"fulfill_type\":\"install\",\"confirm_date\":\"2025-06-01\",\"equipment_id\":\"$EID\"}" >/dev/null
HINS=$(curl -sS "$BASE/hq/warranty-hint?customer_id=$CID&equipment_id=$EID&as_of=2025-12-01" -H "$AUTH")
echo "$HINS" | j 'assert d["warranty"]=="free"'
pass "12 install confirm_date as origin"

# 13 N assign + contractor
UA=$(curl -sS -X POST "$BASE/hq/users" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"login\":\"n20_$RANDOM\",\"name\":\"정규N\",\"password\":\"x\",\"role\":\"technician\"}")
STAFF_ID=$(echo "$UA" | j 'print(d["user_id"])')
CTR=$(curl -sS -X POST "$BASE/hq/contractors" -H "$AUTH" -H 'content-type: application/json' -d '{"name":"용병김"}')
TKT=$(curl -sS -X POST "$BASE/hq/tickets" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"customer_id\":\"$CID\",\"equipment_id\":\"$EID\",\"symptom\":\"N배정\",\"region_id\":\"reg-seoul-gangnam\"}")
TID=$(echo "$TKT" | j 'print(d["ticket_id"])')
curl -sS -X POST "$BASE/hq/tickets/$TID/assignees" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"assignees\":[{\"kind\":\"staff\",\"user_id\":\"$STAFF_ID\",\"is_primary\":\"true\"},{\"kind\":\"contractor\",\"contractor_name\":\"용병김\",\"day_pay_amount\":150000,\"is_primary\":\"false\"}]}" >/dev/null
ASG=$(curl -sS "$BASE/hq/tickets/$TID/assignees" -H "$AUTH")
echo "$ASG" | j 'assert len(d)>=2 and any(x.get("kind")=="contractor" and x.get("day_pay_amount")==150000 for x in d)'
pass "13 staff+contractor assign with day pay"

# 14 cart parts + travel
curl -sS -X POST "$BASE/hq/tickets/$TID/cart" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"kind\":\"part\",\"product_id\":\"$PID\",\"qty\":1}" >/dev/null
curl -sS -X POST "$BASE/hq/tickets/$TID/cart" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"kind\":\"part\",\"name\":\"노즐\",\"qty\":1,\"price\":5000}" >/dev/null
curl -sS -X POST "$BASE/hq/tickets/$TID/finance" -H "$AUTH" -H 'content-type: application/json' \
  -d '{"region_id":"reg-seoul-gangnam"}' >/dev/null
CART=$(curl -sS -X POST "$BASE/hq/tickets/$TID/cart/sync-travel" -H "$AUTH" -H 'content-type: application/json' -d '{}')
echo "$CART" | j '
parts=[x for x in d if x["kind"]=="part"]; trav=[x for x in d if x["kind"]=="travel"]
assert len(parts)>=2 and len(trav)==1 and trav[0]["price"]==30000
'
# region change fee follows
curl -sS -X POST "$BASE/hq/tickets/$TID/finance" -H "$AUTH" -H 'content-type: application/json' \
  -d '{"region_id":"reg-gg-south"}' >/dev/null
CART2=$(curl -sS -X POST "$BASE/hq/tickets/$TID/cart/sync-travel" -H "$AUTH" -H 'content-type: application/json' -d '{}')
echo "$CART2" | j 'assert any(x["kind"]=="travel" and x["price"]==40000 for x in d)'
pass "14 cart parts+travel follows region"

# 15 pdf + image same content
DOC=$(curl -sS -X POST "$BASE/hq/documents" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"ticket_id\":\"$TID\",\"doc_type\":\"invoice\",\"labor_fee\":10000,\"lines\":[{\"name\":\"노즐\",\"qty\":1,\"price\":5000}]}")
DID=$(echo "$DOC" | j 'print(d["doc_id"])')
DL=$(curl -sS "$BASE/hq/documents/$DID/download?format=pdf" -H "$AUTH")
echo "$DL" | j 'assert d.get("pdf_base64") and d.get("image_png_base64") and d.get("content") and "입금계좌" in d["content"]'
# pdf magic in base64 of %PDF
echo "$DL" | j 'import base64; assert base64.b64decode(d["pdf_base64"][:16]).startswith(b"%PDF")'
echo "$DL" | j 'import base64; assert base64.b64decode(d["image_png_base64"][:16]).startswith(b"\x89PNG")'
pass "15 real PDF bytes + PNG bytes + content"

# 16 unpaid badge text
curl -sS -X POST "$BASE/hq/tickets/$TID/finance" -H "$AUTH" -H 'content-type: application/json' \
  -d '{"settlement_status":"미수"}' >/dev/null
UN=$(curl -sS "$BASE/hq/unpaid" -H "$AUTH")
echo "$UN" | j "assert any(x.get('ticket_id')=='$TID' and x.get('settlement_status')=='미수' for x in d)"
pass "16 unpaid status 미수"

# 17 legacy 404
c1=$(curl -sS -o /dev/null -w '%{http_code}' "$BASE/register.html")
c2=$(curl -sS -o /dev/null -w '%{http_code}' "$BASE/customer.html")
c3=$(curl -sS -o /dev/null -w '%{http_code}' -X POST "$BASE/as/register" -H 'content-type: application/json' -d '{}')
[[ "$c1" == "404" && "$c2" == "404" && "$c3" == "404" ]] && pass "17 legacy routes 404" || fail "17" "codes $c1 $c2 $c3"

# 18 README HQ (repo-relative)
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
grep -q '본사' "$ROOT/README.md" && grep -q '/hq/login.html' "$ROOT/README.md" \
  && pass "18 README HQ entry" || fail "18" "README"

# 19 region auto-copy — omit region_id on ticket create; must copy from customer extra
EX=$(curl -sS -X POST "$BASE/hq/customers/$CID/extra" -H "$AUTH" -H 'content-type: application/json' -d '{"region_id":"reg-incheon"}')
echo "$EX" | j 'assert d.get("region_id")=="reg-incheon"'
TKR=$(curl -sS -X POST "$BASE/hq/tickets" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"customer_id\":\"$CID\",\"equipment_id\":\"$EID\",\"symptom\":\"권역자동복사\"}")
TIDR=$(echo "$TKR" | j 'print(d["ticket_id"])')
FIN=$(curl -sS "$BASE/hq/tickets/$TIDR/finance" -H "$AUTH")
echo "$FIN" | j 'assert d.get("region_id")=="reg-incheon" and d.get("travel_fee")==35000'
pass "19 customer region auto-copy on ticket create"

# 20 resigned + contractor past kept
curl -sS -X PUT "$BASE/hq/users/$STAFF_ID" -H "$AUTH" -H 'content-type: application/json' -d '{"employment_status":"resigned"}' >/dev/null
ASS=$(curl -sS "$BASE/hq/users?assignable=1" -H "$AUTH")
echo "$ASS" | j "assert all(x['user_id']!='$STAFF_ID' for x in d)"
ASG2=$(curl -sS "$BASE/hq/tickets/$TID/assignees" -H "$AUTH")
echo "$ASG2" | j 'assert any(x.get("kind")=="contractor" for x in d)'
pass "20 resigned excluded + contractor history kept"

echo ""; echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
