#!/usr/bin/env bash
# 본사 HQ. 기본 30000. HQ_PORT가 있으면 그 포트만. 없으면 30000–30099 빈 포트.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AFJ_ROOT="${FREELANG_AFJ_ROOT:-/home/kim/kim/platform/freelang-afj}"

export BIGWASH_AS_ROOT="$ROOT"
export AFLDB_URL="${AFLDB_URL:-http://127.0.0.1:40610}"

cli_hq_port="${HQ_PORT:-}"
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$ROOT/.env"
  set +a
fi
if [[ -n "$cli_hq_port" ]]; then
  HQ_PORT="$cli_hq_port"
fi
unset PORT

if [[ -z "${AFLDB_READ_KEY:-}" || -z "${AFLDB_WRITE_KEY:-}" ]]; then
  if command -v pm2 >/dev/null 2>&1; then
    export AFLDB_ADMIN_KEY="${AFLDB_ADMIN_KEY:-$(pm2 env 0 2>/dev/null | awk -F': ' '/AFLDB_ADMIN_KEY/{print $2; exit}')}"
    export AFLDB_WRITE_KEY="${AFLDB_WRITE_KEY:-$(pm2 env 0 2>/dev/null | awk -F': ' '/AFLDB_WRITE_KEY/{print $2; exit}')}"
    export AFLDB_READ_KEY="${AFLDB_READ_KEY:-$(pm2 env 0 2>/dev/null | awk -F': ' '/AFLDB_READ_KEY/{print $2; exit}')}"
  fi
fi

if [[ -z "${AFLDB_READ_KEY:-}" || -z "${AFLDB_WRITE_KEY:-}" ]]; then
  echo "[bigwash-hq] ERROR: AFLDB_READ_KEY and AFLDB_WRITE_KEY are required" >&2
  exit 1
fi

port_free() {
  python3 -c 'import socket,sys
p=int(sys.argv[1])
s=socket.socket()
try:
    s.bind(("0.0.0.0", p))
except OSError:
    sys.exit(1)
s.close()' "$1"
}

if [[ -n "${HQ_PORT:-}" ]]; then
  if ! port_free "$HQ_PORT"; then
    echo "[bigwash-hq] bind failed :${HQ_PORT} in use" >&2
    exit 1
  fi
  chosen="$HQ_PORT"
else
  chosen=""
  busy=""
  for p in $(seq 30000 30099); do
    if port_free "$p"; then
      chosen="$p"
      break
    fi
    busy="${busy} ${p}"
  done
  if [[ -z "$chosen" ]]; then
    echo "[bigwash-hq] no free port in 30000-30099. in use:${busy}" >&2
    exit 1
  fi
fi

export HQ_PORT="$chosen"
export PORT="$chosen"

cd "$AFJ_ROOT"
exec node bootstrap.js run "$ROOT/src/hq-server.fl"
