#!/bin/bash
# الحصول على معرف العميل (وإنشائه إذا لم يكن موجوداً)
CLIENT_ID=$(node -e "
  const { Pool } = require('pg');
  const p = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });
  (async () => {
    const check = await p.query(\"SELECT id FROM users WHERE phone='96559999999' AND role='client'\");
    if (check.rows.length) {
      console.log(check.rows[0].id);
    } else {
      const insert = await p.query(
        \"INSERT INTO users (name, phone, password, role) VALUES ('عميل تجريبي', '96559999999', '123456', 'client') RETURNING id\"
      );
      console.log(insert.rows[0].id);
    }
    await p.end();
  })();
")

if [ -z "$CLIENT_ID" ]; then
  echo "❌ لم يتم العثور على العميل أو إنشائه"
  exit 1
fi

echo "✅ معرف العميل: $CLIENT_ID"

# إنشاء طلب تجريبي
curl -X POST http://localhost:3000/api/requests/create \
  -H "Content-Type: application/json" \
  -d "{
    \"clientId\": \"$CLIENT_ID\",
    \"craftsmanId\": \"e26ae910-2bf3-4409-885b-a1521d81e2fc\",
    \"serviceType\": \"تصليح مكيفات\",
    \"description\": \"اختبار curl بعد إنشاء العميل\",
    \"price\": 20
  }"

