const { Pool } = require('pg');
require('dotenv').config({ path: '.env.local' });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function run() {
  const client = await pool.connect();
  try {
    // حذف الجداول الجديدة إذا وجدت (مع الترتيب الصحيح)
    await client.query(`DROP TABLE IF EXISTS refund_requests CASCADE;`);
    await client.query(`DROP TABLE IF EXISTS craftsman_documents CASCADE;`);
    await client.query(`DROP TABLE IF EXISTS payment_transactions CASCADE;`);
    await client.query(`DROP TABLE IF EXISTS bid_offers CASCADE;`);
    await client.query(`DROP TABLE IF EXISTS request_assignments CASCADE;`);

    // إنشاء جدول request_assignments باستخدام TEXT للمفاتيح الخارجية
    await client.query(`
      CREATE TABLE request_assignments (
        id SERIAL PRIMARY KEY,
        request_id INTEGER NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
        craftsman_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        status VARCHAR(20) DEFAULT 'pending',
        expires_at TIMESTAMP DEFAULT NOW() + INTERVAL '30 minutes',
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);
    console.log('✅ Created request_assignments');

    await client.query(`
      CREATE TABLE bid_offers (
        id SERIAL PRIMARY KEY,
        request_id INTEGER NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
        craftsman_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        amount DECIMAL(10, 2) NOT NULL,
        notes TEXT,
        status VARCHAR(20) DEFAULT 'pending',
        modified_count INT DEFAULT 0,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);
    console.log('✅ Created bid_offers');

    await client.query(`
      CREATE TABLE payment_transactions (
        id SERIAL PRIMARY KEY,
        request_id INTEGER NOT NULL REFERENCES requests(id) ON DELETE CASCADE,
        amount DECIMAL(10, 2) NOT NULL,
        type VARCHAR(20) NOT NULL,
        myfatoorah_invoice_id VARCHAR(100),
        myfatoorah_payment_id VARCHAR(100),
        status VARCHAR(20) DEFAULT 'pending',
        payment_url TEXT,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);
    console.log('✅ Created payment_transactions');

    await client.query(`
      CREATE TABLE refund_requests (
        id SERIAL PRIMARY KEY,
        payment_transaction_id INTEGER REFERENCES payment_transactions(id),
        request_id INTEGER NOT NULL REFERENCES requests(id),
        amount DECIMAL(10, 2) NOT NULL,
        reason TEXT,
        status VARCHAR(20) DEFAULT 'pending',
        admin_notes TEXT,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);
    console.log('✅ Created refund_requests');

    await client.query(`
      CREATE TABLE craftsman_documents (
        id SERIAL PRIMARY KEY,
        craftsman_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
        civil_id_url TEXT,
        bank_account_photo_url TEXT,
        bank_name VARCHAR(100),
        bank_iban VARCHAR(50),
        status VARCHAR(20) DEFAULT 'pending',
        reviewed_by TEXT REFERENCES users(id),
        reviewed_at TIMESTAMP,
        created_at TIMESTAMP DEFAULT NOW(),
        updated_at TIMESTAMP DEFAULT NOW()
      )
    `);
    console.log('✅ Created craftsman_documents');

    console.log('🎉 جميع الجداول الجديدة تم إنشاؤها بنجاح!');
  } catch (err) {
    console.error('❌ خطأ:', err.message);
  } finally {
    client.release();
    await pool.end();
  }
}

run();
