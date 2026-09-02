#!/bin/bash
set -e

# تأكد أن DATABASE_URL موجود في .env
if [ -f .env ]; then
  export $(grep -v '^#' .env | grep DATABASE_URL | xargs)
fi

if [ -z "$DATABASE_URL" ]; then
  echo "❌ DATABASE_URL غير موجود. عدّل السكربت وضع رابط قاعدة البيانات يدويًا."
  exit 1
fi

CLIENT_ID="cmtg1cadh00031la3xeiiqdwd"

echo "=========================================="
echo "1) آخر طلب لهذا العميل (Request)"
echo "=========================================="
psql "$DATABASE_URL" -c "
SELECT id, \"clientId\", status, \"visitFeePaid\", \"paymentStatus\", \"createdAt\", \"updatedAt\"
FROM \"Request\"
WHERE \"clientId\" = '${CLIENT_ID}'
ORDER BY \"createdAt\" DESC
LIMIT 5;
"

echo ""
echo "=========================================="
echo "2) آخر معاملات الدفع المرتبطة بهذا العميل"
echo "=========================================="
psql "$DATABASE_URL" -c "
SELECT pt.id, pt.\"requestId\", pt.\"invoiceId\", pt.\"paymentId\", pt.status, pt.\"createdAt\"
FROM \"PaymentTransaction\" pt
JOIN \"Request\" r ON r.id = pt.\"requestId\"
WHERE r.\"clientId\" = '${CLIENT_ID}'
ORDER BY pt.\"createdAt\" DESC
LIMIT 10;
"

echo ""
echo "=========================================="
echo "3) آخر 10 معاملات دفع في النظام كله (لمقارنة عامة)"
echo "=========================================="
psql "$DATABASE_URL" -c "
SELECT id, \"requestId\", \"invoiceId\", \"paymentId\", status, \"createdAt\"
FROM \"PaymentTransaction\"
ORDER BY \"createdAt\" DESC
LIMIT 10;
"
