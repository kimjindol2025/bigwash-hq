#!/usr/bin/env bash
# HQ를 먼저 띄우고, 그 포트를 HQ_API로 현장을 띄운다.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TECH_ROOT="${TECH_ROOT:-$(cd "$ROOT/../bigwash-tech" 2>/dev/null && pwd || true)}"

bash "$ROOT/scripts/run-hq.sh" > >(tee /tmp/bigwash-hq-boot.log) &
hq_pid=$!
hq_port=""
for _ in $(seq 1 40); do
  if [[ -f /tmp/bigwash-hq-boot.log ]]; then
    hq_port="$(sed -n 's/^\[bigwash-hq\] :\([0-9][0-9]*\)$/\1/p' /tmp/bigwash-hq-boot.log | head -1)"
  fi
  if [[ -n "$hq_port" ]]; then
    break
  fi
  if ! kill -0 "$hq_pid" 2>/dev/null; then
    echo "[bigwash-hq] exited before bind" >&2
    exit 1
  fi
  sleep 0.5
done
if [[ -z "$hq_port" ]]; then
  echo "[bigwash-hq] no bind line" >&2
  kill "$hq_pid" 2>/dev/null || true
  exit 1
fi
export HQ_API="http://127.0.0.1:${hq_port}"
echo "[bigwash-pair] hq=$HQ_API"
if [[ -z "$TECH_ROOT" || ! -f "$TECH_ROOT/scripts/run-tech.sh" ]]; then
  echo "[bigwash-pair] tech repo not found. HQ pid=$hq_pid" >&2
  wait "$hq_pid"
  exit 0
fi
bash "$TECH_ROOT/scripts/run-tech.sh" &
tech_pid=$!
trap 'kill "$hq_pid" "$tech_pid" 2>/dev/null || true' INT TERM
wait "$hq_pid" "$tech_pid"
