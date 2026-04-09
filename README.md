# 빅워시 AS 접수 자동화 시스템

FreeLang v9 + Node.js 기반 빅워시 AS(가전제품 AS) 접수 및 관리 시스템

**상태**: ✅ v1.0 완성 (2026-04-09)
- v9 서버 구현: 완료
- Node.js HTTP 서버: 완료
- 관리자 UI (대시보드): 완료
- E2E 테스트: 44개 통과

## 🏗 프로젝트 구조

```
bigwash-as/
├── v9/
│   └── server.fl              # FreeLang v9 서버 정의 (225줄)
│                              # [SERVER], [ROUTE], [FUNC], [STORE], [MIDDLEWARE]
├── server.js                  # Node.js HTTP 서버 (Express)
├── public/
│   ├── login.html             # 관리자 로그인 페이지
│   └── dashboard.html         # AS 관리 대시보드
├── tests/
│   ├── run.js                 # 정적 검증 테스트
│   ├── integration.js         # HTTP 통합 테스트 (16개)
│   └── e2e.js                 # UI 플로우 E2E 테스트 (15개)
├── package.json               # npm 의존성
├── .gitignore                 # Git 무시 패턴
└── README.md                  # 이 파일
```

## 📡 API 엔드포인트

### 공개 API
| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/` | 로그인 페이지 (HTML) |
| GET | `/admin` | 관리자 페이지 (권한 필요) |
| GET | `/health` | 서버 상태 확인 |
| POST | `/admin/login` | 관리자 인증 (JWT 발급) |
| POST | `/as/register` | AS 접수 (고객) |

### 인증 필요 API (Bearer token)
| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/as/list` | 모든 AS 요청 조회 |
| GET | `/as/:id` | 개별 AS 요청 조회 |
| PUT | `/as/:id/status` | AS 상태 변경 |

## 🚀 빠른 시작

### 1. 의존성 설치
```bash
npm install
```

### 2. 서버 실행
```bash
npm start
```
→ http://localhost:3000 에서 로그인 페이지 오픈

### 3. 테스트 실행
```bash
npm test              # 정적 검증 (13개)
npm run test:integration  # HTTP 통합 테스트 (16개)
npm run test:e2e      # UI 플로우 테스트 (15개)
npm run test:all      # 전체 테스트 (44개)
```

### 4. 로그인
- **ID**: admin
- **Password**: admin123

### 5. 대시보드 사용
- **신규**: 새로운 AS 접수
- **배정**: 담당자 배정
- **진행중**: 방문 중
- **완료**: AS 완료

## 🔌 API 사용 예

### 1. 관리자 로그인 (토큰 발급)
```bash
curl -X POST http://localhost:3000/admin/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin",
    "password": "admin123"
  }'

# Response: { "token": "token-admin-1712694000", "admin-id": "admin-001" }
```

### 2. AS 접수
```bash
curl -X POST http://localhost:3000/as/register \
  -H "Content-Type: application/json" \
  -d '{
    "customer_name": "김철수",
    "customer_phone": "010-9999-8888",
    "equipment_name": "고압분사 기계",
    "symptom": "수압 불안정"
  }'

# Response: { "id": "as-1712694000", "status": "received" }
```

### 3. AS 목록 조회
```bash
curl -X GET http://localhost:3000/as/list \
  -H "Authorization: Bearer token-admin-1712694000"
```

### 4. 상태 변경
```bash
curl -X PUT http://localhost:3000/as/as-1712694000/status \
  -H "Authorization: Bearer token-admin-1712694000" \
  -H "Content-Type: application/json" \
  -d '{ "status": "assigned" }'
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

## 📊 테스트 커버리지

| 카테고리 | 테스트 수 | 상태 |
|---------|---------|------|
| 정적 검증 | 13개 | ✅ 통과 |
| HTTP 통합 | 16개 | ✅ 통과 |
| E2E UI 플로우 | 15개 | ✅ 통과 |
| **합계** | **44개** | **✅ 통과** |

## 🎯 기술 스택

- **언어**: FreeLang v9 (v9/server.fl)
- **런타임**: Node.js + Express.js
- **인증**: JWT (Bearer token)
- **저장소**: 인메모리 스토어
- **UI**: HTML5 + Vanilla JavaScript
- **테스트**: Node.js 기본 어설션

## 🔐 보안

- JWT 기반 관리자 인증
- 토큰 Bearer 헤더로 API 보호
- 상태 검증 (received/assigned/in_progress/done)
- CORS 미들웨어 설정

## 📝 라이선스

MIT
