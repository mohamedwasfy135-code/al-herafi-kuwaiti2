import 'dart:ui' as ui;
import 'package:app_links/app_links.dart';
// ✅ تم إزالة Firebase — نستخدم Next.js API مع PostgreSQL/Prisma
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_theme.dart';
import 'core/services/auth_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/api_service.dart';
import 'core/providers/cart_provider.dart';
import 'features/shared/widgets/role_gate_page.dart';
import 'features/client/pages/client_main_page.dart';
import 'features/requests/pages/request_detail_page.dart';

// لم نعد ننشئ الكائن هنا لتجنب الانهيار على الويب
late AppLinks _appLinks;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ApiConfig.setCustomUrl('https://ah-herafy2.vercel.app');
  await EasyLocalization.ensureInitialized();

  // ✅ تهيئة خدمة المصادقة بدلاً من Firebase
  await AuthService.initialize();
  debugPrint('AuthService initialized');

  // ✅ تهيئة إشعارات محلية (بدون Firebase Messaging)
  if (!kIsWeb) {
    _appLinks = AppLinks();
    await NotificationService.init();
  }

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ar'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ar'),
      startLocale: const Locale('ar'),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => CartProvider()),
        ],
        child: const KwCraftApp(),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════
// التطبيق الرئيسي – Apple Design System
// ═══════════════════════════════════════════════════════════════════

class KwCraftApp extends StatelessWidget {
  const KwCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      title: 'app_name'.tr(),

      // ─── ثيم Apple.com – فاتح ونظيف ──────────────────────────────
      theme: AppTheme.lightTheme.copyWith(
        textTheme: Typography.blackCupertino.copyWith(
          displayLarge: const TextStyle(fontFamily: 'Cairo'),
          displayMedium: const TextStyle(fontFamily: 'Cairo'),
          displaySmall: const TextStyle(fontFamily: 'Cairo'),
          headlineLarge: const TextStyle(fontFamily: 'Cairo'),
          headlineMedium: const TextStyle(fontFamily: 'Cairo'),
          headlineSmall: const TextStyle(fontFamily: 'Cairo'),
          titleLarge: const TextStyle(fontFamily: 'Cairo'),
          titleMedium: const TextStyle(fontFamily: 'Cairo'),
          titleSmall: const TextStyle(fontFamily: 'Cairo'),
          bodyLarge: const TextStyle(fontFamily: 'Cairo'),
          bodyMedium: const TextStyle(fontFamily: 'Cairo'),
          bodySmall: const TextStyle(fontFamily: 'Cairo'),
          labelLarge: const TextStyle(fontFamily: 'Cairo'),
          labelMedium: const TextStyle(fontFamily: 'Cairo'),
          labelSmall: const TextStyle(fontFamily: 'Cairo'),
        ),
      ),

      builder: (context, child) {
        // ─── Error Widget مخصص ───────────────────────────────────────
        ErrorWidget.builder = (FlutterErrorDetails details) {
          if (kDebugMode) {
            return Material(
              color: AppTheme.bg,
              child: Container(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error, size: 48, color: AppTheme.danger),
                      const SizedBox(height: 16),
                      Text(
                        'خطأ (debug): ${details.exception}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textP,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        details.toString(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textS,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return Material(
            color: AppTheme.bg,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppTheme.warning),
                    const SizedBox(height: 16),
                    const Text(
                      'حدث خطأ غير متوقع',
                      style: TextStyle(
                        fontSize: AppTheme.fSubtitle,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textP,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'يرجى إعادة تشغيل التطبيق أو المحاولة لاحقاً',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textS,
                        fontSize: AppTheme.fBody,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        };

        // ─── اتجاه النص RTL/LTR ──────────────────────────────────────
        final isRtl = context.locale == const Locale('ar');
        return Directionality(
          textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
          child: child!,
        );
      },

      home: const AppRoot(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// جذر التطبيق – Deep Links + Payment Callback
// ═══════════════════════════════════════════════════════════════════

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});
  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  /// الاستماع للـ Deep Links بشكل آمن للويب والهواتف
  void _initDeepLinks() {
    if (kIsWeb) {
      final currentUri = Uri.base;
      debugPrint('Web URL: $currentUri');

      final orderId = currentUri.queryParameters['orderPaid'];
      if (orderId != null && orderId.isNotEmpty) {
        debugPrint('Web: Payment returned for order $orderId');
        _handlePaymentCallback(orderId);
      }
    } else {
      // معالجة الهواتف فقط (Android/iOS)
      _appLinks.uriLinkStream.listen((Uri uri) {
        debugPrint('Deep link received: $uri');

        if (uri.host == 'payment-callback') {
          final orderId = uri.queryParameters['orderId'];
          if (orderId != null && orderId.isNotEmpty) {
            _handlePaymentCallback(orderId);
          }
        }
      });

      _appLinks.getInitialLink().then((Uri? uri) {
        if (uri != null && uri.host == 'payment-callback') {
          final orderId = uri.queryParameters['orderId'];
          if (orderId != null && orderId.isNotEmpty) {
            _handlePaymentCallback(orderId);
          }
        }
      });
    }
  }

  Future<void> _handlePaymentCallback(String orderId) async {
    // ✅ استخدام API بدلاً من Firestore
    final res = await ApiService.get('/api/requests/$orderId');
    if (res.success && res.data != null) {
      final status = res.data?['request']?['status'] as String? ?? '';
      final paymentStatus = res.data?['request']?['paymentStatus'] as String? ?? '';

      if (status == 'paid' || paymentStatus == 'paid') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('تم تأكيد الدفع بنجاح!'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.rSmall),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => const RoleGatePage();
}
