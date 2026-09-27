#!/usr/bin/env bash
# Run bigwash-as AFJ HTTP server (AFL-DB backed).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AFJ_ROOT="${FREELANG_AFJ_ROOT:-/home/kim/kim/platform/freelang-afj}"

export BIGWASH_AS_ROOT="$ROOT"
export PORT="${PORT:-3000}"
export AFLDB_URL="${AFLDB_URL:-http://127.0.0.1:40610}"

if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi

if [[ -z "${AFLDB_READ_KEY:-}" || -z "${AFLDB_WRITE_KEY:-}" ]]; then
  if command -v pm2 >/dev/null 2>&1; then
    export AFLDB_ADMIN_KEY="${AFLDB_ADMIN_KEY:-$(pm2 env 0 2>/dev/null | awk -F': ' '/AFLDB_ADMIN_KEY/{print $2; exit}')}"
    export AFLDB_WRITE_KEY="${AFLDB_WRITE_KEY:-$(pm2 env 0 2>/dev/null | awk -F': ' '/AFLDB_WRITE_KEY/{print $2; exit}')}"
    export AFLDB_READ_KEY="${AFLDB_READ_KEY:-$(pm2 env 0 2>/dev/null | awk -F': ' '/AFLDB_READ_KEY/{print $2; exit}')}"
  fi
fi

if [[ -z "${AFLDB_READ_KEY:-}" || -z "${AFLDB_WRITE_KEY:-}" ]]; then
  echo "[bigwash-as] ERROR: AFLDB_READ_KEY and AFLDB_WRITE_KEY are required" >&2
  exit 1
fi

cd "$AFJ_ROOT"
# 1차 HQ 본체
exec node bootstrap.js run "$ROOT/src/hq-server.fl"
