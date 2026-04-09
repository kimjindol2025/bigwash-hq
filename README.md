# 빅워시 AS 접수 자동화

FreeLang v9 기반 빅워시 AS 접수 및 관리 시스템

## 🏗 Project Structure

```
bigwash-as/
├── schema/
│   └── as.sql                 # DB 스키마 (customers, as_requests, notifications, admins)
├── src/
│   ├── db.fl                  # PostgreSQL 래퍼 (query, execute, insert, update, delete)
│   ├── auth.fl                # JWT 관리자 인증
│   ├── as.fl                  # AS 접수 핸들러 (register, list, get, update-status)
│   ├── notify.fl              # SMS/카카오 알림 발송
│   └── router.fl              # HTTP 라우팅
├── core/
│   └── server.fl              # HTTP 서버 메인 루프
├── scripts/
│   ├── build.sh               # 빌드 스크립트
│   ├── migrate.js             # DB 마이그레이션
│   └── deploy.sh              # 프로덕션 배포
├── tests/
│   └── run.js                 # 테스트 러너
├── package.json               # npm 설정
└── README.md                  # 이 파일
```

## 📋 API Endpoints

### Public
- `GET /health` - 서버 상태 확인
- `POST /as/register` - AS 접수

### Admin (JWT 인증 필요)
- `GET /as/list` - 모든 AS 요청 조회
- `GET /as/:id` - 개별 AS 요청 조회
- `PUT /as/:id/status` - AS 상태 변경
- `POST /admin/login` - 관리자 로그인

## 🚀 Quick Start

### 1. 환경 설정
```bash
# .env 파일 생성
cp .env.example .env

# 필수 환경 변수
DATABASE_URL=postgresql://localhost/bigwash_as
JWT_SECRET=your-secret-key
SMS_API_KEY=your-sms-api-key
ADMIN_PHONE=031-1688-7759
```

### 2. 빌드
```bash
bash scripts/build.sh
```

### 3. 테스트
```bash
npm test
```

### 4. 데이터베이스 마이그레이션
```bash
npm run migrate
```

### 5. 서버 시작
```bash
npm start
```

## 📡 API 사용 예

### AS 접수
```bash
curl -X POST http://localhost:3000/as/register \
  -H "Content-Type: application/json" \
  -d '{
    "customer_name": "홍길동",
    "customer_phone": "010-1234-5678",
    "equipment_name": "고압세척기",
    "symptom": "압력 저하",
    "address": "서울시 강남구"
  }'
```

### 관리자 로그인
```bash
curl -X POST http://localhost:3000/admin/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "admin123"
  }'
```

### AS 목록 조회 (인증 필요)
```bash
curl -X GET http://localhost:3000/as/list \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### AS 상태 변경
```bash
curl -X PUT http://localhost:3000/as/ID/status \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "in_progress"
  }'
```

## 🔄 AS 상태 흐름

```
received (접수됨)
    ↓
assigned (담당자 배정)
    ↓
in_progress (출동 중)
    ↓
done (완료)
```

## 📨 자동 알림

### 고객 알림
- **접수**: "접수되었습니다"
- **배정**: "담당자가 배정되었습니다"
- **출동**: "담당자가 출동 중입니다"
- **완료**: "AS가 완료되었습니다"

### 관리자 알림
- **신규 접수**: 즉시 SMS 알림

## 🛠 개발

### 파일 추가
1. `src/` 디렉토리에 FreeLang v9 모듈 추가
2. `core/server.fl`에 require 추가
3. `scripts/build.sh` 실행

### 테스트 추가
1. `tests/run.js`에 test() 호출 추가

### 배포
```bash
bash scripts/deploy.sh
```

## 📊 모니터링

```bash
# 서버 상태 확인
pm2 status bigwash-as

# 로그 보기
pm2 logs bigwash-as

# 메모리/CPU
pm2 monit
```

## 📝 License

MIT
