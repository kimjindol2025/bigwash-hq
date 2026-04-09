#!/usr/bin/env node
// bigwash-as/tests/run.js
// v1.0 / 2026-04-09
// Test runner

const fs = require('fs');
const path = require('path');

// 테스트 결과 추적
const results = {
  passed: [],
  failed: [],
  skipped: []
};

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

function assertEquals(actual, expected, msg) {
  if (actual !== expected) {
    throw new Error(`${msg}: expected ${expected}, got ${actual}`);
  }
}

function assert(condition, msg) {
  if (!condition) {
    throw new Error(msg || 'Assertion failed');
  }
}

console.log('\n[bigwash-as] Starting tests...\n');

// ==== 정적 검증 ====
console.log('=== Static Validation ===\n');

test('server.fl exists and is readable', () => {
  const serverPath = path.join(__dirname, '../core/server.fl');
  assert(fs.existsSync(serverPath), 'server.fl not found');
  const content = fs.readFileSync(serverPath, 'utf8');
  assert(content.includes('defmodule server'), 'server module not found');
});

test('db.fl module exists', () => {
  const dbPath = path.join(__dirname, '../src/db.fl');
  assert(fs.existsSync(dbPath), 'db.fl not found');
  const content = fs.readFileSync(dbPath, 'utf8');
  assert(content.includes('defmodule db'), 'db module not found');
  assert(content.includes('defn query'), 'query function not found');
  assert(content.includes('defn execute'), 'execute function not found');
  assert(content.includes('defn insert-one'), 'insert-one function not found');
  assert(content.includes('defn update-one'), 'update-one function not found');
  assert(content.includes('defn delete-one'), 'delete-one function not found');
});

test('auth.fl module exists', () => {
  const authPath = path.join(__dirname, '../src/auth.fl');
  assert(fs.existsSync(authPath), 'auth.fl not found');
  const content = fs.readFileSync(authPath, 'utf8');
  assert(content.includes('defmodule auth'), 'auth module not found');
  assert(content.includes('defn generate-token'), 'generate-token function not found');
  assert(content.includes('defn verify-token'), 'verify-token function not found');
  assert(content.includes('defn admin-login'), 'admin-login function not found');
});

test('as.fl handler module exists', () => {
  const asPath = path.join(__dirname, '../src/as.fl');
  assert(fs.existsSync(asPath), 'as.fl not found');
  const content = fs.readFileSync(asPath, 'utf8');
  assert(content.includes('defmodule as-handler'), 'as-handler module not found');
  assert(content.includes('defn register'), 'register function not found');
  assert(content.includes('defn list-requests'), 'list-requests function not found');
  assert(content.includes('defn get-request'), 'get-request function not found');
  assert(content.includes('defn update-status'), 'update-status function not found');
});

test('notify.fl module exists', () => {
  const notifyPath = path.join(__dirname, '../src/notify.fl');
  assert(fs.existsSync(notifyPath), 'notify.fl not found');
  const content = fs.readFileSync(notifyPath, 'utf8');
  assert(content.includes('defmodule notify'), 'notify module not found');
  assert(content.includes('defn send-received'), 'send-received function not found');
  assert(content.includes('defn send-status-change'), 'send-status-change function not found');
  assert(content.includes('defn send-admin-alert'), 'send-admin-alert function not found');
});

test('router.fl module exists', () => {
  const routerPath = path.join(__dirname, '../src/router.fl');
  assert(fs.existsSync(routerPath), 'router.fl not found');
  const content = fs.readFileSync(routerPath, 'utf8');
  assert(content.includes('defmodule router'), 'router module not found');
  assert(content.includes('defn route-request'), 'route-request function not found');
  assert(content.includes('/health'), '/health route not found');
  assert(content.includes('/as/register'), '/as/register route not found');
  assert(content.includes('/as/list'), '/as/list route not found');
  assert(content.includes('/admin/login'), '/admin/login route not found');
});

// ==== DB Schema 검증 ====
console.log('\n=== Database Schema ===\n');

test('schema/as.sql exists', () => {
  const schemaPath = path.join(__dirname, '../schema/as.sql');
  assert(fs.existsSync(schemaPath), 'schema/as.sql not found');
});

test('as.sql contains required tables', () => {
  const schemaPath = path.join(__dirname, '../schema/as.sql');
  const content = fs.readFileSync(schemaPath, 'utf8');
  assert(content.includes('CREATE TABLE') && content.includes('customers'), 'customers table not found');
  assert(content.includes('as_requests'), 'as_requests table not found');
  assert(content.includes('notifications'), 'notifications table not found');
  assert(content.includes('admins'), 'admins table not found');
});

// ==== 설정 파일 검증 ====
console.log('\n=== Configuration ===\n');

test('package.json exists and is valid', () => {
  const pkgPath = path.join(__dirname, '../package.json');
  assert(fs.existsSync(pkgPath), 'package.json not found');
  const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
  assertEquals(pkg.name, 'bigwash-as', 'package name mismatch');
  assert(pkg.scripts.build, 'build script not found');
  assert(pkg.scripts.start, 'start script not found');
  assert(pkg.scripts.test, 'test script not found');
});

test('deploy script exists', () => {
  const deployPath = path.join(__dirname, '../scripts/deploy.sh');
  assert(fs.existsSync(deployPath), 'deploy.sh not found');
});

test('login.html exists', () => {
  const loginPath = path.join(__dirname, '../public/login.html');
  assert(fs.existsSync(loginPath), 'public/login.html not found');
  const content = fs.readFileSync(loginPath, 'utf8');
  assert(content.includes('빅워시'), '빅워시 텍스트 not found');
  assert(content.includes('로그인'), '로그인 텍스트 not found');
});

test('dashboard.html exists', () => {
  const dashPath = path.join(__dirname, '../public/dashboard.html');
  assert(fs.existsSync(dashPath), 'public/dashboard.html not found');
  const content = fs.readFileSync(dashPath, 'utf8');
  assert(content.includes('대시보드'), '대시보드 텍스트 not found');
  assert(content.includes('상태 변경'), '상태 변경 텍스트 not found');
});

test('migrate script exists', () => {
  const migratePath = path.join(__dirname, '../scripts/migrate.js');
  assert(fs.existsSync(migratePath), 'migrate.js not found');
});

// ==== 결과 요약 ====
console.log('\n' + '='.repeat(50));
console.log('Test Summary');
console.log('='.repeat(50));
console.log(`Passed:  ${results.passed.length}`);
console.log(`Failed:  ${results.failed.length}`);
console.log(`Skipped: ${results.skipped.length}`);
console.log(`Total:   ${results.passed.length + results.failed.length}`);

if (results.failed.length > 0) {
  console.log('\nFailed tests:');
  results.failed.forEach(f => console.log(`  - ${f.name}: ${f.error}`));
  process.exit(1);
} else {
  console.log('\n✅ All tests passed!');
  process.exit(0);
}
