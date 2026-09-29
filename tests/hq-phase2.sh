#!/usr/bin/env bash
# 2차: 보드 이름 필드, 사후함 세 목록
set -euo pipefail
BASE="${HQ_BASE:-${BASE_URL:-http://127.0.0.1:30000}}"
PASS=0; FAIL=0
pass(){ echo "PASS  $1"; PASS=$((PASS+1)); }
fail(){ echo "FAIL  $1 — $2"; FAIL=$((FAIL+1)); }
j(){ python3 -c 'import json,sys; d=json.load(sys.stdin); '"$1"; }

echo "[hq-phase2] $BASE"
TOK=$(curl -sS -X POST "$BASE/hq/login" -H 'content-type: application/json' -d '{"login":"admin","password":"admin123"}' | j 'print(d["token"])')
AUTH="Authorization: Bearer $TOK"
STAFF=$(curl -sS "$BASE/hq/users" -H "$AUTH" | j 'u=next(x for x in d if x.get("employment_status")=="active" and x.get("name")); print(u["user_id"]+"|"+u["name"])')
SID=${STAFF%%|*}; UNAME=${STAFF#*|}
PHONE="010-$(printf '%04d' $RANDOM)-$(printf '%04d' $RANDOM)"
CID=$(curl -sS -X POST "$BASE/hq/customers" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"type\":\"shop\",\"display_name\":\"보드고객\",\"primary_phone\":\"$PHONE\",\"address\":\"서울\"}" | j 'print(d["customer_id"])')
EID=$(curl -sS -X POST "$BASE/hq/equipment" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"customer_id\":\"$CID\",\"name\":\"보드장비\"}" | j 'print(d["equipment_id"])')
DAY=$(date +%F)
TID=$(curl -sS -X POST "$BASE/hq/tickets" -H "$AUTH" -H 'content-type: application/json' \
  -d "{\"customer_id\":\"$CID\",\"equipment_id\":\"$EID\",\"symptom\":\"이름표시\",\"region_id\":\"reg-seoul-gangnam\",\"scheduled_at\":\"${DAY}T11:00\",\"assignee_id\":\"$SID\"}" | j 'print(d["ticket_id"])')
ROWS=$(curl -sS "$BASE/hq/tickets" -H "$AUTH")
echo "$ROWS" | j "
hit=next(t for t in d if t.get('ticket_id')=='$TID')
assert hit.get('assignee_name')=='$UNAME'
assert '$SID' not in (hit.get('assignee_name') or '')
assert hit.get('customer_display_name')=='보드고객'
assert (hit.get('visit_at') or '').startswith('$DAY')
assert 'companion_count' in hit
"
pass "1 assignee_name is a person"
pass "2 customer_display_name"

FU_MS=$(python3 - <<PY
import time, urllib.request
req=urllib.request.Request("$BASE/hq/followups", headers={"Authorization":"Bearer $TOK"})
t0=time.time()
with urllib.request.urlopen(req, timeout=30) as r:
    body=r.read(); code=r.status
open("/tmp/hq-fu.json","wb").write(body)
print(int((time.time()-t0)*1000), code)
PY
)
FU_CODE=${FU_MS##* }; FU_MS=${FU_MS%% *}
test "$FU_CODE" = "200"
python3 - <<'PY'
import json
d=json.load(open("/tmp/hq-fu.json"))
assert isinstance(d.get("photo"), list)
assert isinstance(d.get("unpaid"), list)
assert isinstance(d.get("repeat"), list)
PY
pass "3 followup photo and unpaid arrays"
# N+1 제거 후 수 초 이내여야 함 (잠금 전 9–11초)
test "$FU_MS" -lt 5000 || { fail "3b followups latency" "${FU_MS}ms"; exit 1; }
pass "3b followups under 5s (${FU_MS}ms)"

DC=$(curl -sS -o /tmp/hq-dc.json -w "%{http_code}" "$BASE/hq/day-close?user_id=user-no-such-cross-tenant" -H "$AUTH")
test "$DC" = "404"
pass "4 day-close unknown user 404"
DC_OK=$(curl -sS -o /tmp/hq-dc-ok.json -w "%{http_code}" "$BASE/hq/day-close?user_id=$SID" -H "$AUTH")
test "$DC_OK" = "200"
python3 - <<PY
import json
d=json.load(open("/tmp/hq-dc-ok.json"))
assert d.get("user_id")=="$SID"
assert "label" in d
PY
pass "4b day-close same-company 200"

HTML=$(curl -sS "$BASE/hq/app.html")
printf '%s' "$HTML" > /tmp/hq-phase2-app.html
for s in 카드완납 계좌완납 현금완납 부분수금 미수 해당없음; do
  grep -F -q "$s" /tmp/hq-phase2-app.html || { fail "5 badge $s" "missing"; exit 1; }
done
pass "5 settlement badges remain"

echo "---- $PASS passed, $FAIL failed ----"
test "$FAIL" = "0"
