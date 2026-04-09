#!/usr/bin/env node
// bigwash-as/server.js
// v1.0 / 2026-04-09
// Express 기반 백엔드 (Node.js 버전, FL과 동기화)

const express = require('express');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const multer = require('multer');

const app = express();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'bigwash-secret-key-2026';
const TOKEN_EXPIRY = 86400; // 24시간

// 메모리 스토어 (테스트용)
const store = {
  customers: {},
  asRequests: {},
  schedules: {},
  photos: {},
  serviceLogs: {},
  partsList: {},
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

// 파일 업로드 설정
const uploadDir = path.join(__dirname, 'uploads', 'photos');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    const name = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}${ext}`;
    cb(null, name);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 } // 10MB
});

// 미들웨어
app.use(express.json());
app.use(express.static('public'));
app.use('/uploads', express.static('uploads'));

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

// POST /as/:id/schedule - 스케줄 등록
app.post('/as/:id/schedule', requireAuth, (req, res) => {
  const { id } = req.params;
  const { scheduled_date, scheduled_time, technician_id, address, notes } = req.body;

  const request = store.asRequests[id];
  if (!request) {
    return res.status(404).json({ error: 'Not found' });
  }

  // 검증
  if (!scheduled_date || !scheduled_time) {
    return res.status(400).json({ error: 'scheduled_date and scheduled_time are required' });
  }

  const scheduleId = `schedule-${id}`;
  const schedule = {
    id: scheduleId,
    as_request_id: id,
    scheduled_date,
    scheduled_time,
    technician_id: technician_id || 'unassigned',
    address: address || request.address || '',
    notes: notes || '',
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString()
  };

  store.schedules[scheduleId] = schedule;
  request.scheduled_date = scheduled_date;
  request.scheduled_time = scheduled_time;
  request.updated_at = new Date().toISOString();

  res.status(201).json({
    id: scheduleId,
    scheduled_date,
    scheduled_time,
    technician_id: schedule.technician_id
  });
});

// GET /as/:id/schedule - 스케줄 조회
app.get('/as/:id/schedule', requireAuth, (req, res) => {
  const { id } = req.params;
  const scheduleId = `schedule-${id}`;
  const schedule = store.schedules[scheduleId];

  if (!schedule) {
    return res.status(404).json({ error: 'Schedule not found' });
  }

  res.json(schedule);
});

// POST /as/:id/photo - 사진 업로드
app.post('/as/:id/photo', requireAuth, upload.single('photo'), (req, res) => {
  const { id } = req.params;
  const { photo_type } = req.body; // 'before' 또는 'after'

  const request = store.asRequests[id];
  if (!request) {
    return res.status(404).json({ error: 'Not found' });
  }

  if (!req.file) {
    return res.status(400).json({ error: 'No photo uploaded' });
  }

  if (!photo_type || !['before', 'after'].includes(photo_type)) {
    return res.status(400).json({ error: 'photo_type must be "before" or "after"' });
  }

  const photoId = `photo-${id}-${photo_type}-${Date.now()}`;
  const photo = {
    id: photoId,
    as_request_id: id,
    photo_type,
    file_path: `/uploads/photos/${req.file.filename}`,
    original_name: req.file.originalname,
    file_size: req.file.size,
    uploaded_at: new Date().toISOString()
  };

  store.photos[photoId] = photo;
  request.updated_at = new Date().toISOString();

  res.status(201).json({
    id: photoId,
    photo_type,
    file_path: photo.file_path,
    uploaded_at: photo.uploaded_at
  });
});

// GET /as/:id/photos - 사진 목록
app.get('/as/:id/photos', requireAuth, (req, res) => {
  const { id } = req.params;
  const photos = Object.values(store.photos)
    .filter(p => p.as_request_id === id)
    .sort((a, b) => new Date(b.uploaded_at) - new Date(a.uploaded_at));

  res.json(photos);
});

// PUT /as/:id/service-log - 서비스 일지 기록
app.put('/as/:id/service-log', requireAuth, (req, res) => {
  const { id } = req.params;
  const { work_description, parts_used, labor_time, notes } = req.body;

  const request = store.asRequests[id];
  if (!request) {
    return res.status(404).json({ error: 'Not found' });
  }

  // 검증
  if (!work_description) {
    return res.status(400).json({ error: 'work_description is required' });
  }

  const serviceLogId = `service-log-${id}-${Date.now()}`;
  const serviceLog = {
    id: serviceLogId,
    as_request_id: id,
    work_description,
    labor_time: labor_time || 0,
    notes: notes || '',
    recorded_at: new Date().toISOString()
  };

  store.serviceLogs[serviceLogId] = serviceLog;

  // 부품 기록
  if (parts_used && Array.isArray(parts_used)) {
    parts_used.forEach((part, idx) => {
      const partId = `part-${serviceLogId}-${idx}`;
      store.partsList[partId] = {
        id: partId,
        service_log_id: serviceLogId,
        part_name: part.name || '',
        quantity: part.quantity || 1,
        unit_price: part.price || 0,
        total_price: (part.quantity || 1) * (part.price || 0)
      };
    });
  }

  request.service_log_id = serviceLogId;
  request.updated_at = new Date().toISOString();

  res.json({
    id: serviceLogId,
    work_description,
    labor_time,
    parts_count: parts_used ? parts_used.length : 0,
    recorded_at: serviceLog.recorded_at
  });
});

// GET /as/:id/service-log - 서비스 일지 조회
app.get('/as/:id/service-log', requireAuth, (req, res) => {
  const { id } = req.params;
  const serviceLogs = Object.values(store.serviceLogs)
    .filter(log => log.as_request_id === id)
    .sort((a, b) => new Date(b.recorded_at) - new Date(a.recorded_at));

  if (serviceLogs.length === 0) {
    return res.json(null);
  }

  const latestLog = serviceLogs[0];
  const parts = Object.values(store.partsList)
    .filter(p => p.service_log_id === latestLog.id);

  res.json({
    ...latestLog,
    parts_used: parts
  });
});

// GET /as/:id/service-logs - 모든 서비스 일지 목록
app.get('/as/:id/service-logs', requireAuth, (req, res) => {
  const { id } = req.params;
  const serviceLogs = Object.values(store.serviceLogs)
    .filter(log => log.as_request_id === id)
    .sort((a, b) => new Date(b.recorded_at) - new Date(a.recorded_at))
    .map(log => {
      const parts = Object.values(store.partsList)
        .filter(p => p.service_log_id === log.id);
      return {
        ...log,
        parts_used: parts
      };
    });

  res.json(serviceLogs);
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
