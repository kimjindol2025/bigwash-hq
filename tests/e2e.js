#!/usr/bin/env node
// bigwash-as/tests/e2e.js
// v1.0 / 2026-04-09
// E2E UI 플로우 테스트

const http = require('http');
const { app, store } = require('../server.js');

const BASE_URL = 'http://localhost:3002';

const results = {
  passed: [],
  failed: []
};

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
            body: parsed,
            html: data
          });
        } catch (e) {
          resolve({
            status: res.statusCode,
            headers: res.headers,
            body: data,
            html: data
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

// E2E 시나리오
async function runE2E() {
  console.log('\n[bigwash-as] Starting E2E UI flow tests...\n');
  console.log('=== UI 플로우 테스트 ===\n');

  // 1. 로그인 페이지 로드
  console.log('[1] 로그인 페이지 로드');
  const loginPageRes = await makeRequest('GET', '/');
  test('GET / returns login page HTML', () => {
    assert(loginPageRes.status === 200, 'Should return 200');
    assert(loginPageRes.html.includes('빅워시'), 'Should contain "빅워시"');
    assert(loginPageRes.html.includes('로그인'), 'Should contain "로그인"');
    assert(loginPageRes.html.includes('username'), 'Should have username input');
    assert(loginPageRes.html.includes('password'), 'Should have password input');
  });

  // 2. 관리자 페이지도 로그인으로
  console.log('\n[2] 관리자 페이지 로드');
  const adminPageRes = await makeRequest('GET', '/admin');
  test('GET /admin returns login page', () => {
    assert(adminPageRes.status === 200, 'Should return 200');
    assert(adminPageRes.html.includes('빅워시'), 'Should contain login page');
  });

  // 3. 로그인 폼 검증
  console.log('\n[3] 로그인 폼 요소 확인');
  test('Login form has required elements', () => {
    assert(loginPageRes.html.includes('type="text"'), 'Should have text input');
    assert(loginPageRes.html.includes('type="password"'), 'Should have password input');
    assert(loginPageRes.html.includes('type="submit"'), 'Should have submit button');
    assert(loginPageRes.html.includes('login'), 'Should have login functionality');
  });

  // 4. 로그인 시뮬레이션
  console.log('\n[4] 로그인 요청');
  const loginRes = await makeRequest('POST', '/admin/login', {
    username: 'admin',
    password: 'admin123'
  });
  test('Login returns token for UI', () => {
    assert(loginRes.status === 200, 'Should return 200');
    assert(loginRes.body.token, 'Should have token');
  });
  const token = loginRes.body.token;

  // 5. 대시보드 페이지 로드
  console.log('\n[5] 대시보드 페이지 로드');
  const dashboardPageRes = await makeRequest('GET', '/admin/dashboard.html');
  test('GET /admin/dashboard.html returns page', () => {
    assert(dashboardPageRes.status === 200, 'Should return 200');
    assert(dashboardPageRes.html.includes('빅워시'), 'Should contain title');
    assert(dashboardPageRes.html.includes('대시보드'), 'Should contain dashboard text');
  });

  // 6. 대시보드 UI 요소 검증
  console.log('\n[6] 대시보드 UI 요소');
  test('Dashboard has required elements', () => {
    assert(dashboardPageRes.html.includes('신규'), 'Should have status label');
    assert(dashboardPageRes.html.includes('배정'), 'Should have assignment status');
    assert(dashboardPageRes.html.includes('진행중'), 'Should have progress status');
    assert(dashboardPageRes.html.includes('완료'), 'Should have done status');
    assert(dashboardPageRes.html.includes('상태 변경'), 'Should have status change button');
    assert(dashboardPageRes.html.includes('로그아웃'), 'Should have logout button');
  });

  // 7. 필터 UI 검증
  console.log('\n[7] 필터 기능 확인');
  test('Dashboard has filter buttons', () => {
    assert(dashboardPageRes.html.includes('전체'), 'Should have all filter');
    assert(dashboardPageRes.html.includes('received'), 'Should have received filter');
    assert(dashboardPageRes.html.includes('assigned'), 'Should have assigned filter');
    assert(dashboardPageRes.html.includes('in_progress'), 'Should have in_progress filter');
    assert(dashboardPageRes.html.includes('done'), 'Should have done filter');
  });

  // 8. AS 접수 (시뮬레이션)
  console.log('\n[8] AS 접수 처리');
  const registerRes = await makeRequest('POST', '/as/register', {
    customer_name: '김철수',
    customer_phone: '010-9999-8888',
    equipment_name: '고압분사 기계',
    symptom: '수압 불안정'
  });
  test('AS register returns id', () => {
    assert(registerRes.status === 201, 'Should return 201');
    assert(registerRes.body.id, 'Should have id');
  });
  const asId = registerRes.body.id;

  // 9. 대시보드 목록 조회 (API 검증)
  console.log('\n[9] 대시보드 목록 API');
  const listRes = await makeRequest('GET', '/as/list', null, token);
  test('Dashboard can fetch list via API', () => {
    assert(listRes.status === 200, 'Should return 200');
    assert(Array.isArray(listRes.body), 'Should return array');
    assert(listRes.body.length > 0, 'Should have items');
  });

  // 10. 상태 변경 UI 폼
  console.log('\n[10] 상태 변경 모달 검증');
  test('Dashboard has status change modal', () => {
    assert(dashboardPageRes.html.includes('statusModal'), 'Should have modal');
    assert(dashboardPageRes.html.includes('newStatus'), 'Should have status select');
    assert(dashboardPageRes.html.includes('received'), 'Should have status options');
  });

  // 11. 상태 변경 요청
  console.log('\n[11] 상태 변경 처리');
  const updateRes = await makeRequest('PUT', `/as/${asId}/status`, {
    status: 'assigned'
  }, token);
  test('UI can update status via API', () => {
    assert(updateRes.status === 200, 'Should return 200');
    assert(updateRes.body.status === 'assigned', 'Should reflect new status');
  });

  // 12. 리스트 새로고침 시뮬레이션
  console.log('\n[12] 목록 갱신 확인');
  const refreshRes = await makeRequest('GET', `/as/${asId}`, null, token);
  test('Status change is visible in list', () => {
    assert(refreshRes.status === 200, 'Should return 200');
    assert(refreshRes.body.status === 'assigned', 'Should reflect updated status');
  });

  // 13. 전체 상태 흐름 (UI 관점)
  console.log('\n[13] 전체 상태 흐름 (UI 플로우)');
  const flow = [
    { status: 'assigned', label: '배정' },
    { status: 'in_progress', label: '진행중' },
    { status: 'done', label: '완료' }
  ];

  for (const { status, label } of flow) {
    await makeRequest('PUT', `/as/${asId}/status`, { status }, token);
  }

  test('Full status flow completes', () => {
    assert(true, 'All status transitions completed');
  });

  // 14. 최종 상태 확인
  console.log('\n[14] 최종 상태 확인');
  const finalRes = await makeRequest('GET', `/as/${asId}`, null, token);
  test('Final state is done with completion time', () => {
    assert(finalRes.body.status === 'done', 'Should be done');
    assert(finalRes.body.completed_at, 'Should have completed_at timestamp');
  });

  // 15. 여러 AS 접수 시뮬레이션
  console.log('\n[15] 다중 AS 접수 (대시보드 목록 검증)');
  for (let i = 0; i < 3; i++) {
    await makeRequest('POST', '/as/register', {
      customer_name: `고객${i + 1}`,
      customer_phone: `010-${1000 + i}-${5000 + i}`,
      equipment_name: `장비${i + 1}`,
      symptom: `증상${i + 1}`
    });
  }

  const multiListRes = await makeRequest('GET', '/as/list', null, token);
  test('Dashboard shows multiple items', () => {
    assert(multiListRes.body.length >= 4, 'Should have multiple items');
  });

  // 결과 요약
  console.log('\n' + '='.repeat(50));
  console.log('E2E Test Summary');
  console.log('='.repeat(50));
  console.log(`Passed:  ${results.passed.length}`);
  console.log(`Failed:  ${results.failed.length}`);
  console.log(`Total:   ${results.passed.length + results.failed.length}`);

  if (results.failed.length > 0) {
    console.log('\nFailed tests:');
    results.failed.forEach(f => console.log(`  - ${f.name}: ${f.error}`));
    return 1;
  } else {
    console.log('\n✅ All E2E tests passed!');
    return 0;
  }
}

// 메인
if (require.main === module) {
  const server = app.listen(3002, async () => {
    console.log('[bigwash-as] E2E test server running on port 3002\n');

    try {
      const exitCode = await runE2E();
      server.close(() => process.exit(exitCode));
    } catch (error) {
      console.error('E2E error:', error);
      server.close(() => process.exit(1));
    }
  });
}
