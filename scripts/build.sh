#!/bin/bash
# bigwash-as/scripts/build.sh
# v1.0 / 2026-04-09

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "[bigwash-as] Building project..."

# 1. 의존성 설치
echo "[1/3] Installing dependencies..."
npm install

# 2. FreeLang v9로 컴파일
echo "[2/3] Compiling FreeLang v9..."
mkdir -p dist

# server.fl 컴파일 (fl-compiler 사용)
fl-compiler build core/server.fl -o dist/server-combined.js

# 3. 테스트
echo "[3/3] Running tests..."
npm test

echo "[bigwash-as] ✅ Build successful!"
echo ""
echo "Next steps:"
echo "  1. npm run migrate  # DB 마이그레이션"
echo "  2. npm start        # 서버 시작"
