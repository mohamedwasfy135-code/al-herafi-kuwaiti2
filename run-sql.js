require('dotenv').config({ path: '.env.local' });
const { Pool } = require('pg');
const fs = require('fs');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function run() {
  const sql = fs.readFileSync('setup.sql', 'utf8');
  try {
    await pool.query(sql);
    console.log('✅ تم تنفيذ SQL بنجاح');
  } catch (err) {
    console.error('❌ خطأ:', err.message);
  } finally {
    await pool.end();
  }
}
run();
