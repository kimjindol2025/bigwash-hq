#!/usr/bin/env node
// bigwash-as/scripts/migrate.js
// v1.0 / 2026-04-09
// Database migration

const { Client } = require('pg');
const fs = require('fs');
const path = require('path');

const dbUrl = process.env.DATABASE_URL || 'postgresql://localhost/bigwash_as';

async function migrate() {
  const client = new Client({ connectionString: dbUrl });

  try {
    await client.connect();
    console.log('[bigwash-as] Connected to database');

    // 1. Schema 로드
    const schemaPath = path.join(__dirname, '../schema/as.sql');
    const schema = fs.readFileSync(schemaPath, 'utf8');

    // 2. 쿼리 실행 (여러 명령 분리)
    const queries = schema.split(';').filter(q => q.trim());

    for (const query of queries) {
      if (query.trim()) {
        try {
          await client.query(query);
          console.log('[✓] ' + query.substring(0, 50).replace(/\n/g, ' ') + '...');
        } catch (e) {
          if (e.code !== '42P07') { // 테이블 이미 존재하는 경우 무시
            console.error('[✗] ' + query.substring(0, 50) + '...', e.message);
          }
        }
      }
    }

    // 3. 기본 관리자 계정 생성 (선택)
    try {
      const adminCheck = await client.query(
        'SELECT id FROM admins WHERE username = $1',
        ['admin']
      );

      if (adminCheck.rows.length === 0) {
        const crypto = require('crypto');
        const salt = process.env.PASSWORD_SALT || 'bigwash-salt';
        const password = process.env.ADMIN_PASSWORD || 'admin123';
        const hash = crypto.createHash('sha256')
          .update(password + salt)
          .digest('hex');

        await client.query(
          'INSERT INTO admins (username, password_hash) VALUES ($1, $2)',
          ['admin', hash]
        );
        console.log('[✓] Default admin created (username: admin)');
      }
    } catch (e) {
      console.log('[info] Admin setup skipped:', e.message);
    }

    console.log('\n[bigwash-as] ✅ Migration completed successfully!');

  } catch (e) {
    console.error('[bigwash-as] ✗ Migration failed:', e);
    process.exit(1);
  } finally {
    await client.end();
  }
}

migrate();
