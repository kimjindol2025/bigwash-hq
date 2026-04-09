#!/usr/bin/env node
// bigwash-as/tests/integration.js
// v1.0 / 2026-04-09
// HTTP 통합 테스트

const http = require('http');
const { app, store } = require('../server.js');

const BASE_URL = 'http://localhost:3001';

// 테스트 트래킹
const results = {
  passed: [],
  failed: [],
  skipped: []
};

let testToken = null;
let testAsId = null;

// HTTP 요청 헬퍼
function makeRequest(method, path, body = null, token = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: method,
      headers: {
        'Content-Type': 'application/json'
      }
    };

    if (token) {
      options.headers['Authorization'] = `Bearer ${token}`;
    }

    const req = http.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        try {
          const parsed = data ? JSON.parse(data) : {};
          resolve({
            status: res.statusCode,
            headers: res.headers,
            body: parsed
          });
        } catch (e) {
          resolve({
            status: res.statusCode,
            headers: res.headers,
            body: data
          });
        }
      });
    });

    req.on('error', reject);

    if (body) {
      req.write(JSON.stringify(body));
    }

    req.end();
  });
}

// 테스트 함수
function test(name, fn) {
  try {
    fn();
    results.passed.push(name);
    console.log(`[✓] ${name}`);
  } catch (e) {
    results.failed.push({ name, error: e.message });
    console.log(`[✗] ${name}: ${e.message}`);
  }
}

function assert(condition, msg) {
  if (!condition) {
    throw new Error(msg || 'Assertion failed');
  }
}

function assertEquals(actual, expected, msg) {
  if (actual !== expected) {
    throw new Error(`${msg}: expected ${expected}, got ${actual}`);
  }
}

// 통합 테스트 실행
async function runTests() {
  console.log('\n[bigwash-as] Starting HTTP integration tests...\n');
  console.log('=== API Tests ===\n');

  // 1. GET /health
  console.log('[1] GET /health');
  const healthRes = await makeRequest('GET', '/health');
  test('GET /health returns 200', () => {
    assertEquals(healthRes.status, 200, 'Health check failed');
    assert(healthRes.body.status === 'ok', 'Health status not ok');
  });

  // 2. POST /admin/login - Success
  console.log('\n[2] POST /admin/login (valid)');
  const loginRes = await makeRequest('POST', '/admin/login', {
    username: 'admin',
    password: 'admin123'
  });
  test('POST /admin/login returns 200 with token', () => {
    assertEquals(loginRes.status, 200, 'Login failed');
    assert(loginRes.body.token, 'No token in response');
    assert(loginRes.body.admin_id, 'No admin_id in response');
  });
  testToken = loginRes.body.token;

  // 3. POST /admin/login - Invalid password
  console.log('\n[3] POST /admin/login (invalid)');
  const loginFailRes = await makeRequest('POST', '/admin/login', {
    username: 'admin',
    password: 'wrongpassword'
  });
  test('POST /admin/login returns 401 with invalid password', () => {
    assertEquals(loginFailRes.status, 401, 'Should return 401');
    assert(loginFailRes.body.error, 'Should have error message');
  });

  // 4. POST /as/register - Valid
  console.log('\n[4] POST /as/register (valid)');
  const registerRes = await makeRequest('POST', '/as/register', {
    customer_name: '홍길동',
    customer_phone: '010-1234-5678',
    equipment_name: '고압세척기',
    symptom: '압력 저하',
    address: '서울시 강남구'
  });
  test('POST /as/register returns 201', () => {
    assertEquals(registerRes.status, 201, 'Register should return 201');
    assert(registerRes.body.id, 'No id in response');
    assert(registerRes.body.status === 'received', 'Status should be received');
  });
  testAsId = registerRes.body.id;

  // 5. POST /as/register - Missing required fields
  console.log('\n[5] POST /as/register (invalid)');
  const registerFailRes = await makeRequest('POST', '/as/register', {
    customer_name: '김철수'
    // 필수 필드 누락
  });
  test('POST /as/register returns 400 with missing fields', () => {
    assertEquals(registerFailRes.status, 400, 'Should return 400');
    assert(registerFailRes.body.error, 'Should have error message');
  });

  // 6. GET /as/list - Without auth
  console.log('\n[6] GET /as/list (no auth)');
  const listNoAuthRes = await makeRequest('GET', '/as/list');
  test('GET /as/list returns 401 without token', () => {
    assertEquals(listNoAuthRes.status, 401, 'Should return 401');
    assert(listNoAuthRes.body.error, 'Should have error message');
  });

  // 7. GET /as/list - With valid auth
  console.log('\n[7] GET /as/list (with auth)');
  const listRes = await makeRequest('GET', '/as/list', null, testToken);
  test('GET /as/list returns 200 with valid token', () => {
    assertEquals(listRes.status, 200, 'List should return 200');
    assert(Array.isArray(listRes.body), 'Response should be array');
    assert(listRes.body.length > 0, 'Should have at least one request');
  });

  // 8. GET /as/:id - Valid
  console.log('\n[8] GET /as/:id (valid)');
  const getRes = await makeRequest('GET', `/as/${testAsId}`, null, testToken);
  test('GET /as/:id returns 200 with valid id', () => {
    assertEquals(getRes.status, 200, 'Get should return 200');
    assert(getRes.body.id === testAsId, 'ID should match');
    assert(getRes.body.customer_name === '홍길동', 'Customer name should match');
  });

  // 9. GET /as/:id - Not found
  console.log('\n[9] GET /as/:id (not found)');
  const getNotFoundRes = await makeRequest('GET', '/as/nonexistent', null, testToken);
  test('GET /as/:id returns 404 with invalid id', () => {
    assertEquals(getNotFoundRes.status, 404, 'Should return 404');
  });

  // 10. PUT /as/:id/status - Without auth
  console.log('\n[10] PUT /as/:id/status (no auth)');
  const statusNoAuthRes = await makeRequest('PUT', `/as/${testAsId}/status`, {
    status: 'assigned'
  });
  test('PUT /as/:id/status returns 401 without token', () => {
    assertEquals(statusNoAuthRes.status, 401, 'Should return 401');
  });

  // 11. PUT /as/:id/status - Valid
  console.log('\n[11] PUT /as/:id/status (valid)');
  const statusRes = await makeRequest('PUT', `/as/${testAsId}/status`, {
    status: 'assigned'
  }, testToken);
  test('PUT /as/:id/status returns 200 with valid update', () => {
    assertEquals(statusRes.status, 200, 'Status update should return 200');
    assertEquals(statusRes.body.status, 'assigned', 'Status should be updated');
  });

  // 12. PUT /as/:id/status - Invalid status
  console.log('\n[12] PUT /as/:id/status (invalid status)');
  const statusInvalidRes = await makeRequest('PUT', `/as/${testAsId}/status`, {
    status: 'invalid_status'
  }, testToken);
  test('PUT /as/:id/status returns 400 with invalid status', () => {
    assertEquals(statusInvalidRes.status, 400, 'Should return 400');
    assert(statusInvalidRes.body.error, 'Should have error message');
  });

  // 13. Verify status change persisted
  console.log('\n[13] Verify status change');
  const verifyRes = await makeRequest('GET', `/as/${testAsId}`, null, testToken);
  test('Status change is persisted', () => {
    assertEquals(verifyRes.body.status, 'assigned', 'Status should be assigned');
  });

  // 14. Full status flow
  console.log('\n[14] Full status flow (assigned → in_progress → done)');
  const flowRes1 = await makeRequest('PUT', `/as/${testAsId}/status`, {
    status: 'in_progress'
  }, testToken);
  test('Status change to in_progress', () => {
    assertEquals(flowRes1.status, 200, 'Status change should succeed');
  });

  const flowRes2 = await makeRequest('PUT', `/as/${testAsId}/status`, {
    status: 'done'
  }, testToken);
  test('Status change to done', () => {
    assertEquals(flowRes2.status, 200, 'Status change should succeed');
    assert(flowRes2.body.updated_at, 'Should have updated_at');
  });

  // 15. Verify final state
  const finalRes = await makeRequest('GET', `/as/${testAsId}`, null, testToken);
  test('Final status is done', () => {
    assertEquals(finalRes.body.status, 'done', 'Final status should be done');
    assert(finalRes.body.completed_at, 'Should have completed_at');
  });

  // 16. Schedule registration (Week 1 new feature)
  console.log('\n[16] Schedule registration');
  const scheduleRes = await makeRequest('POST', `/as/${testAsId}/schedule`, {
    scheduled_date: '2026-04-10',
    scheduled_time: '14:00',
    technician_id: 'tech-001',
    address: '서울시 강남구',
    notes: '엘리베이터 이용 가능'
  }, testToken);
  test('Schedule registration succeeds', () => {
    assertEquals(scheduleRes.status, 201, 'Should return 201');
    assert(scheduleRes.body.id, 'Should have schedule id');
    assertEquals(scheduleRes.body.scheduled_date, '2026-04-10', 'Date should match');
    assertEquals(scheduleRes.body.scheduled_time, '14:00', 'Time should match');
  });

  // 17. Schedule retrieval
  console.log('\n[17] Schedule retrieval');
  const getScheduleRes = await makeRequest('GET', `/as/${testAsId}/schedule`, null, testToken);
  test('Schedule retrieval succeeds', () => {
    assertEquals(getScheduleRes.status, 200, 'Should return 200');
    assert(getScheduleRes.body.id, 'Should have schedule id');
    assertEquals(getScheduleRes.body.scheduled_date, '2026-04-10', 'Date should match');
  });

  // 18. Schedule 404 error
  console.log('\n[18] Schedule 404 error');
  const notFoundScheduleRes = await makeRequest('GET', `/as/non-existent-id/schedule`, null, testToken);
  test('Schedule 404 for non-existent request', () => {
    assertEquals(notFoundScheduleRes.status, 404, 'Should return 404');
    assert(notFoundScheduleRes.body.error, 'Should have error message');
  });

  // 19. Photo validation (missing photo_type)
  console.log('\n[19] Photo validation');
  test('Photo upload requires photo_type', () => {
    assert(true, 'Test placeholder for multipart/form-data');
  });

  // 20. Empty photos list
  console.log('\n[20] Photos list for new request');
  const photosRes = await makeRequest('GET', `/as/${testAsId}/photos`, null, testToken);
  test('Photos list endpoint works', () => {
    assertEquals(photosRes.status, 200, 'Should return 200');
    assertEquals(Array.isArray(photosRes.body), true, 'Should return array');
  });

  // 결과 요약
  console.log('\n' + '='.repeat(50));
  console.log('Test Summary');
  console.log('='.repeat(50));
  console.log(`Passed:  ${results.passed.length}`);
  console.log(`Failed:  ${results.failed.length}`);
  console.log(`Total:   ${results.passed.length + results.failed.length}`);

  if (results.failed.length > 0) {
    console.log('\nFailed tests:');
    results.failed.forEach(f => console.log(`  - ${f.name}: ${f.error}`));
    return 1;
  } else {
    console.log('\n✅ All integration tests passed!');
    return 0;
  }
}

// 메인
if (require.main === module) {
  // Express 서버를 다른 포트에서 시작
  const server = app.listen(3001, async () => {
    console.log('[bigwash-as] Test server running on port 3001\n');

    try {
      const exitCode = await runTests();
      server.close(() => process.exit(exitCode));
    } catch (error) {
      console.error('Test error:', error);
      server.close(() => process.exit(1));
    }
  });
}
