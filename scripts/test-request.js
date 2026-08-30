const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

async function main() {
  // المعرفات التي حصلت عليها
  const clientId = '30738c1f-018a-4f2f-b81a-824cee625979';
  const craftsmanId = 'a7486d04-63ce-4cfe-a3eb-5a006f25c9f4';

  const insertRes = await pool.query(
    `INSERT INTO requests (client_id, craftsman_id, service_type, description, estimated_price, status)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING id`,
    [clientId, craftsmanId, 'تصليح مكيفات', 'طلب تجريبي ناجح', 20, 'pending']
  );
  console.log('🎉 تم إنشاء الطلب بنجاح، معرف الطلب:', insertRes.rows[0].id);
  await pool.end();
}
main().catch(e => console.error(e));
