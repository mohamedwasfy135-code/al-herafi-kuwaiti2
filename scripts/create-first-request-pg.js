const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function main() {
  const clientPhone = '96559999999';
  const craftsmanPhone = '96551234567';

  // جلب العميل
  const clientRes = await pool.query('SELECT id FROM users WHERE phone = $1 AND role = $2', [clientPhone, 'client']);
  if (clientRes.rows.length === 0) {
    console.error('❌ العميل غير موجود');
    return;
  }
  const clientId = clientRes.rows[0].id;

  // جلب الحرفي
  const craftsmanRes = await pool.query('SELECT id FROM users WHERE phone = $1 AND role = $2', [craftsmanPhone, 'craftsman']);
  if (craftsmanRes.rows.length === 0) {
    console.error('❌ الحرفي غير موجود');
    return;
  }
  const craftsmanId = craftsmanRes.rows[0].id;

  // إنشاء الطلب
  const insertRes = await pool.query(
    `INSERT INTO requests (client_id, craftsman_id, service_type, details, price, status)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [clientId, craftsmanId, 'تصليح مكيفات', 'طلب تجريبي من السكربت', 20, 'pending']
  );

  console.log('✅ تم إنشاء الطلب بنجاح:', insertRes.rows[0].id);
  await pool.end();
}

main().catch(e => console.error(e));
