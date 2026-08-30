const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

async function main() {
  const clientRes = await pool.query("SELECT id FROM users WHERE phone = '96559999999' AND role = 'client'");
  const craftsmanRes = await pool.query("SELECT id FROM users WHERE phone = '96551234567' AND role = 'craftsman'");

  if (!clientRes.rows.length || !craftsmanRes.rows.length) {
    console.error('❌ العميل أو الحرفي مفقود');
    return;
  }

  const insert = await pool.query(
    `INSERT INTO requests (client_id, craftsman_id, service_type, description, price, status)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
    [clientRes.rows[0].id, craftsmanRes.rows[0].id, 'تصليح مكيفات', 'طلب تجريبي ناجح', 20, 'pending']
  );

  console.log('✅ طلب جديد:', insert.rows[0].id);
  await pool.end();
}
main().catch(e => console.error(e));
