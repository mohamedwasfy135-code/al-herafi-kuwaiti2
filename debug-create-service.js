const { Pool } = require('pg')
const pool = new Pool({ connectionString: process.env.DATABASE_URL })

async function run() {
  const craftsmanId = 'e26ae910-2bf3-4409-885b-a1521d81e2fc'
  const title = 'اختبار'
  const price = 10
  const categoryId = 1
  const isActive = true

  try {
    const res = await pool.query(
      `INSERT INTO services (craftsman_id, title, description, price, category_id, is_active)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [craftsmanId, title, null, price, categoryId, isActive]
    )
    console.log('✅ نجح الإنشاء:', res.rows[0])
  } catch (err) {
    console.error('❌ فشل الإنشاء:')
    console.error(err)
  }
  await pool.end()
}
run()
