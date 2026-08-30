const { Pool } = require('pg');
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

async function main() {
  const res = await pool.query("SELECT id, name FROM users WHERE phone = '96559999999' AND role = 'client'");
  if (res.rows.length) {
    console.log('Client ID:', res.rows[0].id, 'Name:', res.rows[0].name);
  } else {
    console.log('Client not found');
  }
  await pool.end();
}
main().catch(e => console.error(e));
