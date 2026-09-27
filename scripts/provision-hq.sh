#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AFJ_ROOT="${FREELANG_AFJ_ROOT:-/home/kim/kim/platform/freelang-afj}"
export AFLDB_URL="${AFLDB_URL:-http://127.0.0.1:40610}"
if [[ -z "${AFLDB_ADMIN_KEY:-}" || -z "${AFLDB_WRITE_KEY:-}" ]]; then
  export AFLDB_ADMIN_KEY="${AFLDB_ADMIN_KEY:-$(pm2 env 0 2>/dev/null | awk -F': ' '/AFLDB_ADMIN_KEY/{print $2; exit}')}"
  export AFLDB_WRITE_KEY="${AFLDB_WRITE_KEY:-$(pm2 env 0 2>/dev/null | awk -F': ' '/AFLDB_WRITE_KEY/{print $2; exit}')}"
  export AFLDB_READ_KEY="${AFLDB_READ_KEY:-$(pm2 env 0 2>/dev/null | awk -F': ' '/AFLDB_READ_KEY/{print $2; exit}')}"
fi
cd "$AFJ_ROOT"
exec node bootstrap.js run "$ROOT/db/provision-hq.fl"
