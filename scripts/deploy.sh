#!/usr/bin/env bash
# bigwash-as AFJ + AFL-DB deploy helper (local/pm2)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[bigwash-as] deploy (AFJ)"

if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi

echo "[1/4] provision AFL-DB tables"
bash scripts/provision-afldb.sh

echo "[2/4] ensure upload dir"
mkdir -p uploads/photos

echo "[3/4] smoke (server must already be up, or start briefly)"
if curl -fsS -m 2 "${AFLDB_URL:-http://127.0.0.1:40610}/health" >/dev/null; then
  echo "  afl-db health ok"
else
  echo "  WARN: afl-db health check failed — continue anyway"
fi

if curl -fsS -m 2 "http://127.0.0.1:${HQ_PORT:-30000}/health" >/dev/null; then
  bash tests/phase2-smoke.sh
else
  echo "  server not up on :${HQ_PORT:-30000} — start with: npm start"
  echo "  then: npm run test:phase2"
fi

echo "[4/4] pm2 (optional)"
if command -v pm2 >/dev/null 2>&1; then
  if pm2 describe bigwash-as >/dev/null 2>&1; then
    pm2 restart bigwash-as
  else
    echo "  tip: pm2 start scripts/run-afj.sh --name bigwash-as"
  fi
fi

echo "[bigwash-as] deploy steps done"
