const { Pool } = require('pg')
const pool = new Pool({ connectionString: process.env.DATABASE_URL })

async function run() {
  const res = await pool.query('SELECT * FROM categories WHERE id = 1')
  if (res.rows.length === 0) {
    console.log('❌ الفئة رقم 1 غير موجودة')
  } else {
    console.log('✅ الفئة 1 موجودة:', res.rows[0])
  }
  await pool.end()
}
run()
