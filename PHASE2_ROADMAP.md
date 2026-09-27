> **LEGACY — 고객접수 제품. 본사 정본 아님.**

# 빅워시 AS v2.0 Phase 2 로드맵

**시작**: 2026-04-09
**목표**: 완전한 AS 파이프라인 구현
**배포 준비도**: v1.0 기준 (90%) → v2.0 목표 (100%)

---

## 📊 Phase 2 6대 기능 추가

### 1️⃣ 스케줄 등록 (Schedule Management)

**API**:
```
POST /as/:id/schedule
{
  "scheduled_date": "2026-04-10",
  "scheduled_time": "14:00",
  "technician_id": "tech-001",
  "address": "서울시 강남구",
  "notes": "엘리베이터 이용 가능"
}
```

**DB 스키마 추가**:
```sql
ALTER TABLE as_requests ADD COLUMN (
  scheduled_date DATE,
  scheduled_time VARCHAR(5),
  technician_id VARCHAR(50),
  visit_address TEXT,
  visit_notes TEXT
);
```

**UI 추가**:
- 대시보드: "스케줄 등록" 버튼
- 모달: 날짜/시간/기사선택 입력

**예상 소요**: 3일

---

### 2️⃣ 현장사진 업로드 (Before Photo)

**API**:
```
POST /as/:id/photo/before
{
  "image": <binary>,
  "taken_at": "2026-04-10T14:00:00Z"
}
```

**저장소**:
- 로컬: `./uploads/photos/before/`
- 또는 S3: `s3://bigwash-as/photos/before/`

**DB 스키마**:
```sql
CREATE TABLE as_photos (
  id VARCHAR(50) PRIMARY KEY,
  as_request_id VARCHAR(50),
  photo_type VARCHAR(50), -- 'before' / 'after'
  file_path TEXT,
  uploaded_at TIMESTAMP,
  FOREIGN KEY (as_request_id) REFERENCES as_requests(id)
);
```

**UI 추가**:
- 현장 출발 시: "현장사진 촬영" 버튼
- 앨범에서 선택 또는 카메라로 촬영

**예상 소요**: 4일

---

### 3️⃣ 서비스 상세기록 (Service Log)

**API**:
```
PUT /as/:id/service-log
{
  "work_description": "냉각수 교체, 필터 청소",
  "parts_used": [
    {"name": "냉각수", "quantity": 2, "price": 15000},
    {"name": "필터", "quantity": 1, "price": 8000}
  ],
  "labor_time": 1.5, -- 시간
  "notes": "추가 이상 없음"
}
```

**DB 스키마**:
```sql
CREATE TABLE as_service_logs (
  id VARCHAR(50) PRIMARY KEY,
  as_request_id VARCHAR(50),
  work_description TEXT,
  labor_time DECIMAL(5,2),
  notes TEXT,
  recorded_at TIMESTAMP,
  FOREIGN KEY (as_request_id) REFERENCES as_requests(id)
);

CREATE TABLE as_parts_used (
  id VARCHAR(50) PRIMARY KEY,
  service_log_id VARCHAR(50),
  part_name VARCHAR(100),
  quantity INT,
  unit_price DECIMAL(10,2),
  FOREIGN KEY (service_log_id) REFERENCES as_service_logs(id)
);
```

**UI 추가**:
- 상태: in_progress → 작업일지 탭
- 텍스트: 작업 내용 입력
- 테이블: 사용 부품 리스트 추가/삭제

**예상 소요**: 4일

---

### 4️⃣ 완료사진 업로드 (After Photo)

**API**:
```
POST /as/:id/photo/after
{
  "image": <binary>,
  "taken_at": "2026-04-10T16:00:00Z"
}
```

**DB**: as_photos 테이블의 photo_type = 'after'

**UI 추가**:
- 상태: done → "완료사진 저장" 버튼
- 갤러리 뷰: before/after 비교

**예상 소요**: 2일

---

### 5️⃣ 비용 정산 (Billing)

**API**:
```
POST /as/:id/billing
{
  "parts_cost": 23000,
  "labor_cost": 30000,
  "service_fee": 10000,
  "total": 63000,
  "payment_method": "card", -- card / cash / transfer
  "payment_status": "pending", -- pending / completed
  "notes": "할부 2개월"
}
```

**DB 스키마**:
```sql
CREATE TABLE as_billing (
  id VARCHAR(50) PRIMARY KEY,
  as_request_id VARCHAR(50),
  parts_cost DECIMAL(10,2),
  labor_cost DECIMAL(10,2),
  service_fee DECIMAL(10,2),
  total_amount DECIMAL(10,2),
  payment_method VARCHAR(50),
  payment_status VARCHAR(50),
  paid_at TIMESTAMP,
  notes TEXT,
  created_at TIMESTAMP,
  FOREIGN KEY (as_request_id) REFERENCES as_requests(id)
);
```

**UI 추가**:
- 완료 후: 청구서 자동 생성
- 결제 수단 선택
- 결제 확인 버튼

**예상 소요**: 4일

---

### 6️⃣ 고객 확인 대시보드 (Customer Portal)

**API**:
```
GET /customer/requests?phone=010-xxxx-xxxx
[
  {
    "id": "as-123",
    "status": "done",
    "created_at": "2026-04-09",
    "scheduled_date": "2026-04-10",
    "photos": {
      "before": "/uploads/photos/before/...",
      "after": "/uploads/photos/after/..."
    },
    "billing": {
      "total": 63000,
      "payment_status": "completed"
    }
  }
]
```

**페이지**: `public/customer.html`

**UI**:
- 전화번호로 조회
- 나의 AS 요청 목록
- 각 요청별 상세보기
- 현장사진 갤러리
- 청구서 보기
- 평가/댓글

**예상 소요**: 5일

---

## 📈 Phase 2 일정 (4주)

| Week | 기능 | 라인 수 | 테스트 | 상태 |
|------|------|--------|--------|------|
| 1 | 스케줄 + 현장사진 | AFJ | phase2-smoke | ✅ |
| 2 | 서비스일지 + 완료사진 | AFJ | phase2-smoke | ✅ |
| 3 | 비용정산 | AFJ | phase2-smoke | ✅ |
| 4 | 고객대시보드 + 통합 | AFJ | phase2-smoke | ✅ |
| **합계** | **6대 기능** | AFL-DB | `npm run test:phase2` | ✅ |

---

## 🎯 기술 스택

### 파일 업로드
- **로컬**: multer (express 미들웨어)
- **클라우드**: AWS S3 또는 Google Cloud Storage

### 데이터베이스
- **현재**: 인메모리 → **PostgreSQL로 전환**
- 테이블: customers, as_requests, as_photos, as_service_logs, as_billing

### UI 개선
- **관리자**: 대시보드 탭 분리 (스케줄/사진/일지/정산)
- **고객**: 별도 포털 (조회만 가능)

---

## 📊 Phase 2 후 상태

```
v1.0 (90%)
  ↓
+ 스케줄 관리
+ 사진 업로드 (before/after)
+ 서비스 일지
+ 비용 정산
+ 고객 포털
  ↓
v2.0 (100%) → 프로덕션 배포 준비
```

---

## 💾 DB 마이그레이션 계획

### v1.0 (메모리)
```json
{
  "asRequests": {
    "as-123": {
      "id": "as-123",
      "customer_name": "김철수",
      "status": "done",
      "created_at": "2026-04-09"
    }
  }
}
```

### v2.0 (PostgreSQL)
```sql
-- 고객 테이블
CREATE TABLE customers (
  id SERIAL PRIMARY KEY,
  phone VARCHAR(20) UNIQUE,
  name VARCHAR(100),
  address TEXT,
  created_at TIMESTAMP
);

-- AS 요청 테이블
CREATE TABLE as_requests (
  id VARCHAR(50) PRIMARY KEY,
  customer_id INT,
  equipment_name VARCHAR(100),
  symptom TEXT,
  status VARCHAR(50),

  -- 스케줄
  scheduled_date DATE,
  scheduled_time VARCHAR(5),
  technician_id VARCHAR(50),

  -- 서비스
  service_log_id VARCHAR(50),

  -- 결제
  billing_id VARCHAR(50),

  created_at TIMESTAMP,
  updated_at TIMESTAMP,
  FOREIGN KEY (customer_id) REFERENCES customers(id)
);

-- 사진 테이블
CREATE TABLE as_photos (
  id VARCHAR(50) PRIMARY KEY,
  as_request_id VARCHAR(50),
  photo_type VARCHAR(50), -- before / after
  file_path TEXT,
  uploaded_at TIMESTAMP,
  FOREIGN KEY (as_request_id) REFERENCES as_requests(id)
);

-- 서비스 일지 테이블
CREATE TABLE as_service_logs (
  id VARCHAR(50) PRIMARY KEY,
  as_request_id VARCHAR(50),
  work_description TEXT,
  labor_time DECIMAL(5,2),
  notes TEXT,
  recorded_at TIMESTAMP,
  FOREIGN KEY (as_request_id) REFERENCES as_requests(id)
);

-- 부품 사용 테이블
CREATE TABLE as_parts_used (
  id VARCHAR(50) PRIMARY KEY,
  service_log_id VARCHAR(50),
  part_name VARCHAR(100),
  quantity INT,
  unit_price DECIMAL(10,2),
  FOREIGN KEY (service_log_id) REFERENCES as_service_logs(id)
);

-- 결제 테이블
CREATE TABLE as_billing (
  id VARCHAR(50) PRIMARY KEY,
  as_request_id VARCHAR(50),
  parts_cost DECIMAL(10,2),
  labor_cost DECIMAL(10,2),
  service_fee DECIMAL(10,2),
  total_amount DECIMAL(10,2),
  payment_method VARCHAR(50),
  payment_status VARCHAR(50),
  paid_at TIMESTAMP,
  created_at TIMESTAMP,
  FOREIGN KEY (as_request_id) REFERENCES as_requests(id)
);
```

---

## ✅ Phase 2 완료 체크리스트

- [x] 스케줄 API + UI (Week 1) — AFJ + AFL-DB `bigwash_schedules`
- [x] 사진 업로드 (Week 1-2) — base64 → `uploads/photos` + `bigwash_photos`
- [x] 서비스 일지 (Week 2) — `bigwash_service_logs` / `bigwash_parts`
- [x] 비용 정산 (Week 3) — `bigwash_billing`
- [x] 고객 대시보드 (Week 4) — `/customer.html` + `/customer/requests`
- [x] 공개 접수 — `/register.html`
- [x] 영속 저장소 — AFL-DB V2 (PostgreSQL 대신)
- [x] Phase2 자동 스모크 — `tests/phase2-smoke.sh` (`npm run test:phase2`)
- [x] 배포 헬퍼 — `scripts/deploy.sh` (AFJ/AFL-DB)
- [ ] 대시보드 탭 분리·알림 실연동·PM2 정식 등록 — [`PLAN.md`](PLAN.md) 남은 일

---

**예상 완료**: 2026-05-09 (30일)
**목표**: v2.0 프로덕션 배포 (100% 준비도)
