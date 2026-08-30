#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# سكريبت إعداد مشروع الحرفي الكويتي
# يُشغَّل مرة واحدة بعد فك ضغط الملف
# ═══════════════════════════════════════════════════════════════

set -e

echo "🔧 بدء إعداد مشروع الحرفي الكويتي..."
echo ""

# 1. التحقق من ملف .env
if [ ! -f ".env" ]; then
    echo "⚠️ ملف .env غير موجود!"
    echo "يرجى إنشاء ملف .env من القالب الموجود وإضافة كلمة مرور Supabase"
    echo ""
fi

# 2. تثبيت الحزم
echo "📦 تحميل الحزم..."
flutter pub get

# 3. إنشاء ملفات المنصة إذا لم تكن موجودة
echo "📱 إنشاء ملفات المنصة..."
flutter create . --platforms=android,ios

# 4. إصلاح build.gradle لدعم desugaring (مطلوب لـ flutter_local_notifications)
echo "⚙️ التحقق من إعدادات android/app/build.gradle..."

GRADLE_FILE="android/app/build.gradle"

if [ -f "$GRADLE_FILE" ]; then
    # التحقق مما إذا كان desugaring مفعّلاً بالفعل
    if grep -q "coreLibraryDesugaringEnabled" "$GRADLE_FILE"; then
        echo "✅ coreLibraryDesugaring مفعّل بالفعل"
    else
        echo "⚠️ يرجى التأكد من وجود coreLibraryDesugaringEnabled true في compileOptions"
    fi
else
    echo "⚠️ ملف android/app/build.gradle غير موجود - تأكد من تشغيل flutter create . أولاً"
fi

# 5. التحقق من اتصال الخادم
echo ""
echo "🌐 للتحقق من اتصال الخادم:"
echo "  curl https://sana3i.space-z.ai/api/health"
echo ""
echo "إذا لم يعمل الخادم، تأكد من:"
echo "  1. الخادم مشغّل على sana3i.space-z.ai"
echo "  2. مسار /api/auth/register موجود ويرجع JSON"
echo "  3. ملف .env يحتوي على DATABASE_URL لـ PostgreSQL"
echo ""

# 6. تشغيل في وضع التطوير المحلي
echo "📱 للتشغيل على المحاكي مع الخادم المحلي:"
echo "  flutter run --dart-define=IS_DEV=true"
echo ""
echo "📱 للتشغيل مع خادم الإنتاج:"
echo "  flutter run"
echo ""

echo "✅ تم الإعداد بنجاح!"
