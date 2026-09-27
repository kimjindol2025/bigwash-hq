# 빅워시 AS 접수 자동화 시스템

**FreeLang AFJ (v11) + AFL-DB** 기반 빅워시 AS 접수·관리 시스템.

**작업 지시서:** [`PLAN.md`](PLAN.md) — 남은 일은 여기 기준으로 이어서 처리한다.  
상세 로드맵: [`PHASE2_ROADMAP.md`](PHASE2_ROADMAP.md)

이전 v9 정의(`v9/server.fl`)와 Node Express 본체(`server.js`)는 `legacy`/호환용으로 남겨 두었다. 현재 본체는 AFJ `.fl`이다.

## 스택

| 층 | 기술 |
|----|------|
| HTTP API | FreeLang AFJ (`src/server.fl`) |
| 영속 | AFL-DB V2 relational (`:40610`) |
| UI | `public/login.html`, `public/dashboard.html` |

## 구조

```
bigwash-as/
├── src/
│   ├── server.fl          # AFJ HTTP 서버 (본체)
│   └── db.fl              # AFL-DB 클라이언트 헬퍼
├── db/
│   ├── bigwash-as-afldb-schema.v1.json
│   └── provision-bigwash-as-afldb.fl
├── public/                # 관리자 UI
├── scripts/
│   ├── provision-afldb.sh
│   └── run-afj.sh
├── v9/server.fl           # 역사 자료 (v9)
├── server.js              # 레거시 Node 서버
└── legacy/                # 이전 초안 모듈
```

## API

### 핵심
| 메서드 | 경로 | 인증 | 설명 |
|--------|------|------|------|
| GET | `/health` | 없음 | 상태 |
| POST | `/admin/login` | 없음 | JWT 발급 |
| POST | `/as/register` | 없음 | AS 접수 |
| GET | `/as/list` | Bearer | 목록 |
| GET | `/as/:id` | Bearer | 단건 |
| PUT | `/as/:id/status` | Bearer | 상태 변경 |

### Phase 2
| 메서드 | 경로 | 인증 | 설명 |
|--------|------|------|------|
| POST/GET | `/as/:id/schedule` | Bearer | 방문 스케줄 |
| POST | `/as/:id/photo` | Bearer | 현장/완료 사진 (`photo_type` + `image_base64`) |
| GET | `/as/:id/photos` | Bearer | 사진 목록 |
| GET | `/as/:id/photos/:photoId/content` | Bearer | 사진 data URL |
| PUT/GET | `/as/:id/service-log` | Bearer | 서비스 일지 |
| GET | `/as/:id/service-logs` | Bearer | 일지 목록 |
| POST/GET | `/as/:id/billing` | Bearer | 비용 정산 |
| GET | `/customer/requests?phone=` | 없음 | 고객 조회 |
| GET | `/customer.html` | 없음 | 고객 포털 UI |

상태 흐름: `received` → `assigned` → `in_progress` → `done`

## 빠른 시작

### 1. AFL-DB 준비

PM2에서 `afl-db`가 online인지 확인한다.

```bash
pm2 list
curl -s http://127.0.0.1:40610/health
```

### 2. 환경 변수

```bash
cp .env.example .env
# AFLDB_*_KEY 와 JWT_SECRET 을 채운다.
# 로컬 개발에서는 scripts 가 pm2 env 0 의 키를 읽는다.
```

### 3. 테이블 프로비저닝 + 관리자 시드

```bash
npm run provision
# 또는: bash scripts/provision-afldb.sh
```

기본 관리자: `admin` / `admin123` (`ADMIN_PASSWORD`로 변경 가능)

### 4. 서버 실행

```bash
npm start
# → http://127.0.0.1:3000
```

### 5. 스모크

```bash
curl -s http://127.0.0.1:3000/health

curl -s -X POST http://127.0.0.1:3000/admin/login \
  -H 'content-type: application/json' \
  -d '{"username":"admin","password":"admin123"}'

curl -s -X POST http://127.0.0.1:3000/as/register \
  -H 'content-type: application/json' \
  -d '{"customer_name":"김철수","customer_phone":"010-9999-8888","equipment_name":"고압분사","symptom":"수압 불안정"}'
```

## AFL-DB 테이블

- `bigwash_admins`
- `bigwash_customers`
- `bigwash_as_requests`
- `bigwash_notifications`

스키마: `db/bigwash-as-afldb-schema.v1.json`

## 레거시

- `npm run start:legacy-node` — 기존 Express 인메모리 서버
- `v9/server.fl` — FreeLang v9 블록 문법 정의
- `legacy/*.fl` — 초기 초안 모듈

## 라이선스

MIT
