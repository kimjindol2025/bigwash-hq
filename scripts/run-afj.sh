#!/usr/bin/env bash
# 옛 진입. 포트 선택은 scripts/run-hq.sh
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec bash "$ROOT/scripts/run-hq.sh"
