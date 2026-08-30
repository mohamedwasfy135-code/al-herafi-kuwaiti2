const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

async function main() {
  // تحقق أولاً
  const check = await pool.query("SELECT id FROM users WHERE phone = '96559999999' AND role = 'client'");
  if (check.rows.length > 0) {
    console.log('✅ العميل موجود:', check.rows[0].id);
    await pool.end();
    return;
  }

  // إنشاء العميل
  const insert = await pool.query(
    "INSERT INTO users (name, phone, password, role) VALUES ($1, $2, $3, $4) RETURNING id",
    ['عميل تجريبي', '96559999999', '123456', 'client']
  );
  console.log('✅ تم إنشاء العميل:', insert.rows[0].id);
  await pool.end();
}
main().catch(e => console.error(e));
