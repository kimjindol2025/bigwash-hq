#!/bin/bash
# bigwash-as/scripts/deploy.sh
# v1.0 / 2026-04-09
# 프로덕션 배포 스크립트

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# 환경 변수 로드
if [ -f ~/.env ]; then
  export $(cat ~/.env | xargs)
fi

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}[bigwash-as] Deployment started...${NC}"
echo ""

# 1. 기존 프로세스 종료
echo -e "${YELLOW}[1/6] Stopping existing processes...${NC}"
pm2 stop bigwash-as 2>/dev/null || true
sleep 1

# 2. 의존성 설치
echo -e "${YELLOW}[2/6] Installing dependencies...${NC}"
npm install

# 3. 빌드
echo -e "${YELLOW}[3/6] Building project...${NC}"
bash scripts/build.sh

# 4. 데이터베이스 마이그레이션
echo -e "${YELLOW}[4/6] Running database migration...${NC}"
npm run migrate

# 5. 서버 시작
echo -e "${YELLOW}[5/6] Starting server...${NC}"
pm2 start dist/server-combined.js --name bigwash-as --env production
pm2 save

# 6. 헬스 체크
echo -e "${YELLOW}[6/6] Health check...${NC}"
sleep 2

if curl -s http://localhost:3000/health | grep -q "ok"; then
  echo -e "${GREEN}✅ Server is healthy!${NC}"
else
  echo -e "${RED}✗ Server health check failed!${NC}"
  pm2 logs bigwash-as --lines 20
  exit 1
fi

echo ""
echo -e "${GREEN}✅ Deployment successful!${NC}"
echo ""
echo "Server status:"
pm2 status bigwash-as
echo ""
echo "Useful commands:"
echo "  pm2 logs bigwash-as          # View logs"
echo "  pm2 restart bigwash-as       # Restart server"
echo "  pm2 stop bigwash-as          # Stop server"
echo "  pm2 delete bigwash-as        # Remove from pm2"
