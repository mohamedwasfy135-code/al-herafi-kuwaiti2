import 'dart:async';
// ✅ تم إزالة Firebase — نستخدم AuthService + FirestoreService
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:sana3i_kuwait/features/admin/pages/admin_panel.dart';
import 'package:sana3i_kuwait/features/client/pages/client_main_page.dart';
import 'package:sana3i_kuwait/features/craftsman/pages/craftsman_home_page.dart';
import 'package:sana3i_kuwait/features/business/pages/business_home_page.dart';
import 'package:sana3i_kuwait/features/home/pages/home_page.dart';
import 'package:sana3i_kuwait/features/auth/pages/auth_page.dart';
import 'package:sana3i_kuwait/features/auth/pages/document_upload_page.dart';
import 'package:sana3i_kuwait/core/constants/app_constants.dart';
import 'package:sana3i_kuwait/core/services/auth_service.dart';
import 'package:sana3i_kuwait/core/services/firestore_service.dart';

class RoleGatePage extends StatefulWidget {
  const RoleGatePage({super.key});
  @override
  State<RoleGatePage> createState() => _RoleGatePageState();
}

class _RoleGatePageState extends State<RoleGatePage> {
  Sana3iUser? _currentUser;
  Widget? _resolvedPage;
  StreamSubscription<Sana3iUser?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    // 1. نأخذ المستخدم الحالي فوراً (إن وُجد)
    _currentUser = AuthService.currentUser;
    // 2. نحسم الصفحة بناءً عليه
    _resolvePage();

    // 3. نستمع للتغييرات اللاحقة
    _authSubscription = AuthService.userChanges.listen((user) {
      if (user?.id != _currentUser?.id) {
        _currentUser = user;
        _resolvePage();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _resolvePage() async {
    final user = _currentUser;
    if (user == null) {
      setState(() => _resolvedPage = const HomePage());
      return;
    }

    // استخدم بيانات المستخدم المخزنة محلياً بعد تسجيل الدخول مباشرة
    final role = user.role;
    final verificationStatus = user.verificationStatus ?? '';
    setState(() => _resolvedPage = _getPageForRole(role, verificationStatus));

    // محاولة جلب بيانات إضافية من الخادم بصمت (اختياري)
    try {
      final userData = await FirestoreService.getUser(user.id);
      if (userData != null && mounted) {
        final updatedRole = userData['role'] as String? ?? role;
        final updatedVerification =
            userData['verificationStatus'] as String? ??
            userData['verification_status'] as String? ??
            verificationStatus;
        setState(() =>
            _resolvedPage = _getPageForRole(updatedRole, updatedVerification));
      }
    } catch (_) {
      // تجاهل أخطاء التحديث الصامتة
    }
  }

  Widget _getPageForRole(String role, String verificationStatus) {
    if ((role == kRoleCraftsman || role == kRoleBusiness) &&
        verificationStatus != 'approved') {
      return const DocumentUploadPage();
    }
    switch (role) {
      case kRoleAdmin:
        return const AdminPanel();
      case kRoleCraftsman:
        return const CraftsmanHomePage();
      case kRoleBusiness:
      case kRoleOffice:
        return BusinessHomePage(verificationStatus: verificationStatus);
      default:
        return ClientMainPage();
    }
  }

  // ــــــــــــــ شاشة خطأ تحميل البيانات ــــــــــــــ
  Widget _userDocErrorScreen() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              const Text(
                'تعذر تحميل بيانات المستخدم.\nتأكد من اتصالك بالإنترنت.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _resolvedPage = null);
                  _resolvePage();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0071E3),
                  foregroundColor: const Color(0xFF1D1D1F),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () async {
                  await AuthService.signOut();
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthPage()),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.white70),
                label: const Text('تسجيل الخروج',
                    style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvedPage == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1D1D1F),
        body: Center(child: SizedBox.shrink()),
      );
    }
    return _resolvedPage!;
  }
}