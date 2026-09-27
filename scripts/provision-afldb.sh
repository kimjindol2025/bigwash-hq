#!/usr/bin/env bash
# Provision bigwash-as AFL-DB tables and seed admin.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AFJ_ROOT="${FREELANG_AFJ_ROOT:-/home/kim/kim/platform/freelang-afj}"

if [[ -z "${AFLDB_URL:-}" ]]; then
  export AFLDB_URL="http://127.0.0.1:40610"
fi

# Prefer process env; else pull role keys from local pm2 afl-db (dev host).
if [[ -z "${AFLDB_ADMIN_KEY:-}" || -z "${AFLDB_WRITE_KEY:-}" || -z "${AFLDB_READ_KEY:-}" ]]; then
  if command -v pm2 >/dev/null 2>&1; then
    export AFLDB_ADMIN_KEY="${AFLDB_ADMIN_KEY:-$(pm2 env 0 2>/dev/null | awk -F': ' '/AFLDB_ADMIN_KEY/{print $2; exit}')}"
    export AFLDB_WRITE_KEY="${AFLDB_WRITE_KEY:-$(pm2 env 0 2>/dev/null | awk -F': ' '/AFLDB_WRITE_KEY/{print $2; exit}')}"
    export AFLDB_READ_KEY="${AFLDB_READ_KEY:-$(pm2 env 0 2>/dev/null | awk -F': ' '/AFLDB_READ_KEY/{print $2; exit}')}"
  fi
fi

if [[ -z "${AFLDB_ADMIN_KEY:-}" || -z "${AFLDB_WRITE_KEY:-}" ]]; then
  echo "[bigwash-as] ERROR: AFLDB_ADMIN_KEY and AFLDB_WRITE_KEY are required" >&2
  exit 1
fi

cd "$AFJ_ROOT"
exec node bootstrap.js run "$ROOT/db/provision-bigwash-as-afldb.fl"
