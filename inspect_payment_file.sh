#!/bin/bash
TARGET="src/app/api/payments/myfatoorah/callback/route.ts"

echo "=================================================="
echo "1) هل الملف موجود؟"
echo "=================================================="
if [ -f "$TARGET" ]; then
    echo "موجود: $TARGET"
    echo "عدد الأسطر: $(wc -l < "$TARGET")"
else
    echo "غير موجود في: $TARGET"
    echo "المسار الحالي: $(pwd)"
    find . -iname "route.ts" -path "*myfatoorah*" 2>/dev/null
    exit 1
fi

echo ""
echo "=================================================="
echo "2) نسخة sed"
echo "=================================================="
sed --version 2>/dev/null | head -1 || echo "BSD/macOS sed — استخدم: sed -i '' بدل sed -i"

echo ""
echo "=================================================="
echo "3) أسماء الأعمدة القديمة (snake_case)"
echo "=================================================="
grep -n -E "myfatoorah_invoice_id|myfatoorah_payment_id|request_id|craftsman_id|client_id" "$TARGET" || echo "لا توجد مطابقات"

echo ""
echo "=================================================="
echo "4) inspection_fee / visit_fee"
echo "=================================================="
grep -n -E "inspection_fee|visit_fee" "$TARGET" || echo "لا توجد مطابقات"

echo ""
echo "=================================================="
echo "5) WHERE invoiceId"
echo "=================================================="
grep -n "WHERE invoiceId" "$TARGET" || echo "لم يتم العثور على هذه الصيغة بالضبط"

echo ""
echo "=================================================="
echo "6) pool.query و trans.rows.length"
echo "=================================================="
grep -n "pool.query\|trans.rows.length" "$TARGET" || echo "لم يتم العثور"

echo ""
echo "=================================================="
echo "7) السياق الكامل حول الكلمات المفتاحية"
echo "=================================================="
grep -n -A2 -B2 -E "invoiceId|paymentId|requestId|craftsmanId|clientId|inspection_fee|visit_fee" "$TARGET" | head -100

echo ""
echo "انتهى الفحص. انسخ كل الناتج أعلاه وألصقه هنا."
