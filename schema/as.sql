-- bigwash-as/schema/as.sql
-- v1.0 / 2026-04-09
-- AS 접수 관리 시스템 DB 스키마

-- UUID 생성 확장
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 고객 테이블
CREATE TABLE IF NOT EXISTS customers (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name          VARCHAR(100) NOT NULL,
  phone         VARCHAR(20) NOT NULL UNIQUE,
  address       TEXT,
  memo          TEXT,
  created_at    TIMESTAMP DEFAULT NOW(),
  updated_at    TIMESTAMP DEFAULT NOW()
);

-- AS 요청 테이블
CREATE TABLE IF NOT EXISTS as_requests (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  customer_id     UUID REFERENCES customers(id),
  customer_name   VARCHAR(100) NOT NULL,
  customer_phone  VARCHAR(20) NOT NULL,
  equipment_name  VARCHAR(100),
  symptom         TEXT NOT NULL,
  status          VARCHAR(20) DEFAULT 'received',
  receipt_no      BIGSERIAL UNIQUE,
  scheduled_at    TIMESTAMP,
  completed_at    TIMESTAMP,
  result          TEXT,
  created_at      TIMESTAMP DEFAULT NOW(),
  updated_at      TIMESTAMP DEFAULT NOW()
);

-- 알림 발송 로그
CREATE TABLE IF NOT EXISTS notifications (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  as_request_id UUID REFERENCES as_requests(id),
  customer_phone VARCHAR(20) NOT NULL,
  content       TEXT NOT NULL,
  channel       VARCHAR(10) DEFAULT 'sms',
  sent_at       TIMESTAMP,
  status        VARCHAR(10) DEFAULT 'pending',
  created_at    TIMESTAMP DEFAULT NOW()
);

-- 관리자 테이블
CREATE TABLE IF NOT EXISTS admins (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  username      VARCHAR(50) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  phone         VARCHAR(20),
  created_at    TIMESTAMP DEFAULT NOW(),
  updated_at    TIMESTAMP DEFAULT NOW()
);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_as_requests_status ON as_requests(status);
CREATE INDEX IF NOT EXISTS idx_as_requests_created_at ON as_requests(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone);
CREATE INDEX IF NOT EXISTS idx_notifications_status ON notifications(status);

-- 상태값 제약
ALTER TABLE as_requests
ADD CONSTRAINT check_status CHECK (
  status IN ('received', 'assigned', 'in_progress', 'done')
);

-- 채널값 제약
ALTER TABLE notifications
ADD CONSTRAINT check_channel CHECK (
  channel IN ('sms', 'kakao', 'email')
);
