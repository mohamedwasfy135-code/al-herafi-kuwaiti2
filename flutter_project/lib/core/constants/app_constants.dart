
// ── مفاتيح API ────────────────────────────────────────────
const String kGoogleMapsApiKey = String.fromEnvironment(
  'GOOGLE_MAPS_KEY',
  defaultValue: '',
);
const String kAdminWhatsApp = String.fromEnvironment(
  'ADMIN_WHATSAPP',
  defaultValue: '+96599999999',
);

// ── معلومات التطبيق ───────────────────────────────────────
const String kAppName    = 'الحرفي الكويتي';
const String kAppVersion = '1.0.0';

// ── مسارات API / جداول قاعدة البيانات (PostgreSQL) ──────────
// تم التحديث: أسماء الجداول تتوافق مع مسارات API و Prisma models
const String kColUsers         = 'users';
const String kColCraftsmen     = 'craftsmen';
const String kColRequests      = 'requests';
const String kColGuestReq      = 'guest_requests';
const String kColNotifs        = 'notifications';
const String kColChats         = 'chats';
const String kColMessages      = 'messages';
const String kColInvoices      = 'invoices';
const String kColWorkPhotos    = 'work_photos';
const String kColProducts      = 'products';
const String kColOffers        = 'offers';
const String kColBusinesses    = 'businesses';
const String kColPriceOffers   = 'price_quotes';
const String kColEarnings      = 'earnings';
const String kColPayoutRequests = 'payout_requests';
const String kColExpenses       = 'expenses';
const String kColDeletedPayouts = 'deleted_payouts';
const String kColVerificationRequests = 'verification_requests';

// ── الأدوار ───────────────────────────────────────────────
const String kRoleClient    = 'client';
const String kRoleCraftsman = 'craftsman';
const String kRoleAdmin     = 'admin';
const String kRoleBusiness  = 'business';
const String kRoleOffice    = 'office';

// ── حالات الطلبات ─────────────────────────────────────────
const String kStatusPending     = 'pending';
const String kStatusNotified    = 'notified';
const String kStatusAccepted    = 'accepted';
const String kStatusInProgress  = 'in_progress';
const String kStatusDone        = 'done';
const String kStatusRejected    = 'rejected';
const String kStatusNoCraftsman = 'no_craftsman';
const String kStatusNeedsAdmin  = 'needs_admin';

// ── حالات التحقق من الوثائق ───────────────────────────────
const String kVerificationStatusPending  = 'pending';
const String kVerificationStatusApproved = 'approved';
const String kVerificationStatusRejected = 'rejected';
const String kVerificationStatusSubmitted = 'submitted';

// ── مسارات تخزين الوثائق ──────────────────────────────────
const String kStoragePathLicenses = 'licenses';
const String kStoragePathCivilIds = 'civil_ids';

// ── إعدادات الإسناد التلقائي ──────────────────────────────
const int    kAutoAssignTimeoutMinutes = 5;
const double kMaxDistanceKm            = 50.0;
const int    kMaxJobsForScore          = 200;

// ── إعدادات الاشتراكات والعمولة للمحلات والشركات ─────────
const double kSubscriptionPrice = 10.0;         // سعر الاشتراك الشهري
const double kDefaultCommissionRate = 0.005;    // نسبة العمولة الافتراضية 0.5%
const int    kSubscriptionDurationDays = 30;    // مدة الاشتراك بالأيام
