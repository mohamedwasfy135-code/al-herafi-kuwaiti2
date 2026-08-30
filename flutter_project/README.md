# الحرفي الكويتي — تطبيق Flutter

## إعداد المشروع

### 1. تثبيت الحزم
```bash
flutter pub get
```

### 2. إعداد ملف البيئة (.env)
- انسخ `.env.example` إلى `.env`
- أضف كلمة مرور Supabase مكان `[YOUR-PASSWORD]`

### 3. تشغيل التطبيق
```bash
# على المحاكي مع خادم الإنتاج
flutter run

# على المحاكي مع خادم محلي
flutter run --dart-define=IS_DEV=true

# على جهاز حقيقي — غيّر IP في api_service.dart أولاً
flutter run
```

## تغيير عنوان الخادم

### للإنتاج (افتراضي)
`https://sana3i.space-z.ai`

### للتطوير المحلي (محاكي Android)
`http://10.0.2.2:3000`

### للتطوير المحلي (جهاز حقيقي)
غيّر `192.168.1.X` إلى IP جهازك في `lib/core/services/api_service.dart`

## التحقق من الخادم
```bash
curl https://sana3i.space-z.ai/api/health
# يجب أن يرجع: {"status":"ok"}
```

## ملاحظات مهمة
- Firebase محذوف بالكامل — لا يوجد google-services.json
- قاعدة البيانات: PostgreSQL على Supabase
- Backend: Next.js + Prisma
- التواصل: HTTP API + Socket.IO
