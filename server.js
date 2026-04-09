#!/usr/bin/env node
// bigwash-as/server.js
// v1.0 / 2026-04-09
// Express 기반 백엔드 (Node.js 버전, FL과 동기화)

const express = require('express');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'bigwash-secret-key-2026';
const TOKEN_EXPIRY = 86400; // 24시간

// 메모리 스토어 (테스트용)
const store = {
  customers: {},
  asRequests: {},
  notifications: [],
  admins: {
    admin: {
      id: '00000000-0000-0000-0000-000000000001',
      username: 'admin',
      password_hash: crypto.createHash('sha256')
        .update('admin123bigwash-salt')
        .digest('hex')
    }
  }
};

// 미들웨어
app.use(express.json());
app.use(express.static('public'));

// 헬퍼 함수
function generateId() {
  return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}

function generateToken(adminId, username) {
  return jwt.sign(
    { admin_id: adminId, username, iat: Date.now(), exp: Date.now() + TOKEN_EXPIRY * 1000 },
    JWT_SECRET
  );
}

function verifyToken(token) {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (e) {
    return null;
  }
}

function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(401).json({ error: 'Missing authorization header' });
  }

  const token = authHeader.replace('Bearer ', '');
  const verified = verifyToken(token);

  if (!verified) {
    return res.status(401).json({ error: 'Invalid token' });
  }

  req.admin = verified;
  next();
}

// ===== API 엔드포인트 =====

// GET /health
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// POST /admin/login
app.post('/admin/login', (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: 'username and password required' });
  }

  const admin = store.admins[username];
  if (!admin) {
    return res.status(401).json({ error: 'Invalid username' });
  }

  const salt = process.env.PASSWORD_SALT || 'bigwash-salt';
  const inputHash = crypto.createHash('sha256')
    .update(password + salt)
    .digest('hex');

  if (inputHash !== admin.password_hash) {
    return res.status(401).json({ error: 'Invalid password' });
  }

  const token = generateToken(admin.id, username);
  res.json({
    token,
    admin_id: admin.id,
    username: admin.username
  });
});

// POST /as/register
app.post('/as/register', (req, res) => {
  const { customer_name, customer_phone, equipment_name, symptom, address } = req.body;

  // 검증
  if (!customer_name || !customer_phone || !symptom) {
    return res.status(400).json({
      error: 'customer_name, customer_phone, and symptom are required'
    });
  }

  const asId = generateId();
  const request = {
    id: asId,
    customer_name,
    customer_phone,
    equipment_name: equipment_name || '',
    symptom,
    address: address || '',
    status: 'received',
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
    scheduled_at: null,
    completed_at: null,
    result: null
  };

  store.asRequests[asId] = request;

  // 알림 로그
  store.notifications.push({
    id: generateId(),
    as_request_id: asId,
    customer_phone,
    content: `[빅워시] 접수번호 #${asId.substring(0, 8)}\n${customer_name}님 AS 접수 완료\n증상: ${symptom}`,
    channel: 'sms',
    status: 'sent',
    sent_at: new Date().toISOString(),
    created_at: new Date().toISOString()
  });

  res.status(201).json({
    id: asId,
    receipt_no: asId.substring(0, 8),
    status: 'received'
  });
});

// GET /as/list
app.get('/as/list', requireAuth, (req, res) => {
  const requests = Object.values(store.asRequests)
    .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
    .slice(0, 100);

  res.json(requests);
});

// GET /as/:id
app.get('/as/:id', requireAuth, (req, res) => {
  const { id } = req.params;
  const request = store.asRequests[id];

  if (!request) {
    return res.status(404).json({ error: 'Not found' });
  }

  res.json(request);
});

// PUT /as/:id/status
app.put('/as/:id/status', requireAuth, (req, res) => {
  const { id } = req.params;
  const { status } = req.body;

  const validStatuses = ['received', 'assigned', 'in_progress', 'done'];
  if (!validStatuses.includes(status)) {
    return res.status(400).json({ error: 'Invalid status' });
  }

  const request = store.asRequests[id];
  if (!request) {
    return res.status(404).json({ error: 'Not found' });
  }

  request.status = status;
  request.updated_at = new Date().toISOString();

  if (status === 'done') {
    request.completed_at = new Date().toISOString();
  }

  // 알림 로그
  const statusLabels = {
    assigned: '담당자가 배정되었습니다',
    in_progress: '담당자가 출동 중입니다',
    done: 'AS가 완료되었습니다'
  };

  if (statusLabels[status]) {
    store.notifications.push({
      id: generateId(),
      as_request_id: id,
      customer_phone: request.customer_phone,
      content: `[빅워시] #${id.substring(0, 8)}\n${statusLabels[status]}`,
      channel: 'sms',
      status: 'sent',
      sent_at: new Date().toISOString(),
      created_at: new Date().toISOString()
    });
  }

  res.json({ status, updated_at: request.updated_at });
});

// 정적 파일 서빙
app.get('/admin/login.html', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'login.html'));
});

app.get('/admin/dashboard.html', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'dashboard.html'));
});

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'login.html'));
});

app.get('/admin', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'login.html'));
});

// 404
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// 서버 시작
const server = app.listen(PORT, () => {
  console.log(`[bigwash-as] Server running on port ${PORT}`);
  console.log(`[bigwash-as] ENV: ${process.env.NODE_ENV || 'development'}`);
  console.log('[bigwash-as] Ready to receive AS requests');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('[bigwash-as] SIGTERM received, shutting down...');
  server.close(() => process.exit(0));
});

process.on('SIGINT', () => {
  console.log('[bigwash-as] SIGINT received, shutting down...');
  server.close(() => process.exit(0));
});

module.exports = { app, store };
