import 'dart:async';
import 'dart:ui' as ui;
// ✅ تم إزالة Firebase — نستخدم AuthService + ApiService
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/services_data.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/auto_assign_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/responsive.dart';
import '../../shared/widgets/role_gate_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();

  static Future<void> signOut() async {
    AutoAssignService.cancelAllTimers();
    final uid = AuthService.currentUser?.id;
    if (uid != null) {
      try { await NotificationService.removeTokenFromServer(uid); } catch (_) {}
    }
    await AuthService.signOut();
    const secureStorage = FlutterSecureStorage();
    await secureStorage.delete(key: 'sessionId');
  }
}

class _AuthPageState extends State<AuthPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _businessNameCtrl = TextEditingController();
  final _businessAddressCtrl = TextEditingController();

  String _message = '';
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscure = true;
  String _role = kRoleClient;
  String? _selectedJob, _selectedGov, _selectedCity, _businessType, _businessCategory;
  List<String> _cities = [];

  @override
  void dispose() {
    _emailCtrl.dispose(); _passwordCtrl.dispose(); _nameCtrl.dispose();
    _phoneCtrl.dispose(); _businessNameCtrl.dispose(); _businessAddressCtrl.dispose();
    super.dispose();
  }

  void _setMsg(String msg) => setState(() => _message = msg);

  // ==================== التسجيل ====================
  Future<void> _signUp() async {
    if (_nameCtrl.text.trim().isEmpty) { _setMsg('✏️ ${'write_your_name'.tr()}'); return; }
    final phone = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length < 8) { _setMsg('📱 ${'invalid_phone'.tr()}'); return; }
    if (_selectedGov == null) { _setMsg('🏙️ ${'choose_governorate'.tr()}'); return; }
    if (_role == kRoleCraftsman && _selectedJob == null) { _setMsg('🔧 ${'choose_specialty'.tr()}'); return; }
    if (_role == kRoleBusiness) {
      if (_businessNameCtrl.text.trim().isEmpty) { _setMsg('🏪 ${'choose_business_name'.tr()}'); return; }
      if (_businessCategory == null) { _setMsg('📂 ${'choose_business_category'.tr()}'); return; }
    }

    setState(() { _isLoading = true; _message = ''; });

    try {
      // ✅ استخدام AuthService بدلاً من FirebaseAuth
      final result = await AuthService.signUp(
        name: _nameCtrl.text.trim(),
        phone: phone,
        password: _passwordCtrl.text.trim(),
        email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        role: _role == kRoleAdmin ? kRoleClient : _role,
        governorate: _selectedGov,
        city: _selectedCity,
        businessName: _role == kRoleBusiness ? _businessNameCtrl.text.trim() : null,
        businessCategory: _businessCategory,
        businessAddress: _role == kRoleBusiness ? _businessAddressCtrl.text.trim() : null,
      );

      if (result.success) {
        // ✅ لا حاجة لإرسال تفعيل البريد في النظام الجديد
        if (mounted) {
          // الانتقال مباشرة لصفحة الدور
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const RoleGatePage()),
          );
        }
      } else {
        String msg = result.error ?? 'حدث خطأ';
        // تحويل رسائل الخطأ
        if (msg.contains('مسجل مسبقاً') || msg.contains('already')) {
          setState(() => _isSignUp = false);
          msg = '📧 ${'email_already_used'.tr()}\n${'login_instead'.tr()}';
        } else if (msg.contains('كلمة المرور') || msg.contains('weak')) {
          msg = '🔐 ${'weak_password'.tr()}';
        } else if (msg.contains('البريد') || msg.contains('email')) {
          msg = '📧 ${'invalid_email'.tr()}';
        } else {
          msg = '❌ $msg';
        }
        _setMsg(msg);
      }
    } catch (e) {
      _setMsg('❌ ${'unexpected_error'.tr()}: ${e.toString().substring(0, 80)}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==================== تسجيل الدخول ====================
  Future<void> _signIn() async {
    setState(() { _isLoading = true; _message = ''; });
    try {
      // ✅ استخدام AuthService بدلاً من FirebaseAuth
      final email = _emailCtrl.text.trim();
      final phone = email; // يمكن استخدام الهاتف أيضاً

      AuthResult result;

      // محاولة تسجيل الدخول بالهاتف أولاً (إذا كان أرقام)
      if (RegExp(r'^[0-9]+$').hasMatch(phone)) {
        result = await AuthService.signInWithPhone(
          phone: phone,
          password: _passwordCtrl.text.trim(),
        );
      } else {
        result = await AuthService.signInWithEmail(
          email: email,
          password: _passwordCtrl.text.trim(),
        );
      }

      if (result.success) {
        // حفظ FCM token للإشعارات
        final uid = AuthService.currentUser?.id;
        if (uid != null) {
          try { await NotificationService.saveTokenToServer(uid); } catch (_) {}
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const RoleGatePage()),
          );
        }
      } else {
        String msg = result.error ?? 'حدث خطأ';
        // تحويل رسائل الخطأ
        if (msg.contains('غير صحيحة') || msg.contains('incorrect')) {
          msg = '🔐 ${'invalid_credentials'.tr()}';
        } else if (msg.contains('غير موجود') || msg.contains('not found')) {
          msg = '📧 ${'email_not_registered'.tr()}';
        } else {
          msg = '❌ $msg';
        }
        _setMsg(msg);
      }
    } catch (e) {
      _setMsg('❌ Unexpected: ${e.toString().substring(0, 100)}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (_emailCtrl.text.trim().isEmpty) { _setMsg('📧 ${'enter_email_first'.tr()}'); return; }
    setState(() { _isLoading = true; _message = ''; });
    try {
      final result = await AuthService.sendPasswordResetEmail(
        email: _emailCtrl.text.trim(),
      );
      if (result.success) {
        _setMsg('✅ ${'reset_link_sent'.tr()}');
      } else {
        _setMsg('❌ ${result.error ?? 'حدث خطأ'}');
      }
    } catch (e) {
      _setMsg('❌ ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final bool isBusiness = _role == kRoleBusiness;

    return Scaffold(
      body: Stack(children: [
        Positioned.fill(child: Image.asset('assets/images/ocean_bg.jpg', fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => Container(
            decoration: const BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1D1D1F), Color(0xFF003366), Color(0xFF00509E)]),
            ),
          ),
        )),
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.25))),
        Column(children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF007A3D), Color(0xFFFFFFFF), Color(0xFFCE1126), Color(0xFF000000)], stops: [0.0, 0.35, 0.75, 1.0]),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
            ),
            child: SafeArea(bottom: false, child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
              Expanded(child: Text(_isSignUp ? 'signup_tab'.tr() : 'login_tab'.tr(),
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(1, 1))]))),
            ])),
          ),
          Expanded(
            child: SafeArea(top: false, child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 450 : double.infinity),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(height: 20),
                    Container(width: 44, height: 36, decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))]), child: const Icon(Icons.handyman, size: 22, color: Color(0xFF0D47A1))),
                    const SizedBox(height: 6),
                    Transform.flip(flipY: true, child: ShaderMask(shaderCallback: (bounds) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.white70, Colors.transparent]).createShader(bounds), child: Container(width: 44, height: 24, decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.handyman, size: 22, color: Color(0xFF0D47A1))))),
                    const SizedBox(height: 12),
                    ShaderMask(shaderCallback: (bounds) => const LinearGradient(colors: [Color(0xFF007A3D), Color(0xFFFFFFFF), Color(0xFFCE1126), Color(0xFF000000)], stops: [0.0, 0.4, 0.8, 1.0]).createShader(bounds), child: Text(kAppName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5))),
                    const SizedBox(height: 4),
                    Text('app_slogan'.tr(), style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.95), fontWeight: FontWeight.w400)),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 25, offset: const Offset(0, 12))]),
                      child: Column(children: [
                        _buildToggle(), const SizedBox(height: 20),
                        if (_isSignUp) ...[
                          _glassField(_nameCtrl, 'full_name'.tr(), Icons.person_outline), const SizedBox(height: 12),
                          _glassField(_phoneCtrl, 'phone_number'.tr(), Icons.phone_android_outlined, isPhone: true), const SizedBox(height: 12),
                          _govCityRow(), const SizedBox(height: 12),
                          _roleGrid(),
                          if (_role == kRoleCraftsman) ...[ const SizedBox(height: 12), _jobDropdown() ],
                          if (isBusiness) ...[
                            const SizedBox(height: 12), _businessCategoryDropdown(),
                            const SizedBox(height: 12), _glassField(_businessNameCtrl, 'business_name'.tr(), Icons.business_outlined),
                            const SizedBox(height: 12), _glassField(_businessAddressCtrl, 'business_address'.tr(), Icons.location_on_outlined),
                          ],
                          const SizedBox(height: 12),
                        ],
                        _glassField(_emailCtrl, 'email_label'.tr(), Icons.email_outlined, isEmail: true), const SizedBox(height: 12),
                        _glassField(_passwordCtrl, 'password_label'.tr(), Icons.lock_outlined, isPassword: true), const SizedBox(height: 8),
                        if (!_isSignUp) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _resetPassword, child: Text('forgot_password'.tr(), style: const TextStyle(color: Color(0xFF0071E3), fontSize: 12)))),
                        const SizedBox(height: 16),
                        _isLoading ? const CircularProgressIndicator(color: Color(0xFF0071E3)) : _glassButton(),
                        if (_message.isNotEmpty) _messageBox(),
                      ]),
                    ),
                    const SizedBox(height: 20),
                  ]),
                ),
              ),
            )),
          ),
        ]),
      ]),
    );
  }

  // ========== عناصر الواجهة ==========
  Widget _glassField(TextEditingController ctrl, String label, IconData icon, {bool isPassword = false, bool isEmail = false, bool isPhone = false}) {
    return TextField(
      controller: ctrl, obscureText: isPassword ? _obscure : false,
      keyboardType: isEmail ? TextInputType.emailAddress : isPhone ? TextInputType.phone : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: Colors.white, size: 20),
        suffixIcon: isPassword ? IconButton(icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white, size: 20), onPressed: () => setState(() => _obscure = !_obscure)) : null,
        filled: true, fillColor: Colors.white.withOpacity(0.25),
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withOpacity(0.7), width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0071E3), width: 2.0)),
      ),
    );
  }

  Widget _glassButton() {
    return SizedBox(width: double.infinity, height: 46,
      child: ElevatedButton(
        onPressed: _isSignUp ? _signUp : _signIn,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0071E3), foregroundColor: const Color(0xFF1D1D1F), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 5, shadowColor: const Color(0xFF0071E3).withOpacity(0.5), padding: const EdgeInsets.symmetric(vertical: 12)),
        child: Text(_isSignUp ? 'create_account_btn'.tr() : 'login_btn'.tr(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildToggle() {
    return Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(24)),
      child: Row(children: [
        _toggleTab('login_tab'.tr(), !_isSignUp, () => setState(() => _isSignUp = false)),
        _toggleTab('signup_tab'.tr(), _isSignUp, () => setState(() => _isSignUp = true)),
      ]),
    );
  }

  Widget _toggleTab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? Colors.white.withOpacity(0.45) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? const Color(0xFF0D47A1) : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _govCityRow() {
    return Row(children: [
      Expanded(child: _glassDropdown(value: _selectedGov, hint: 'governorate_label'.tr(), items: kGovernorates, onChanged: (g) => setState(() { _selectedGov = g; _selectedCity = null; _cities = kCitiesByGovernorate[g] ?? []; }))),
      const SizedBox(width: 10),
      Expanded(child: _glassDropdown(value: _selectedCity, hint: 'city_label'.tr(), items: _cities, onChanged: (c) => setState(() => _selectedCity = c))),
    ]);
  }

  Widget _glassDropdown({String? value, required String hint, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.5))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value, hint: Text(hint, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          isExpanded: true, icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          dropdownColor: const Color(0xFF003366),
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white, fontSize: 13)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _roleGrid() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('account_type'.tr(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      const SizedBox(height: 6),
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 4.2, children: [
        _roleChip(kRoleClient, 'client_role', Icons.person_outline),
        _roleChip(kRoleCraftsman, 'craftsman_role', Icons.construction_outlined),
        _roleChip(kRoleBusiness, 'shop_role', Icons.store_outlined),
        _roleChip(kRoleBusiness, 'company_role', Icons.business_outlined),
      ]),
    ]);
  }

  Widget _roleChip(String role, String labelKey, IconData icon) {
    final bool isBusinessRole = (role == kRoleBusiness);
    final bool selected = isBusinessRole
        ? (labelKey == 'shop_role' && _businessCategory != null && kShopCategories.contains(_businessCategory)) ||
          (labelKey == 'company_role' && _businessCategory != null && kCompanyCategories.contains(_businessCategory))
        : (_role == role);

    return GestureDetector(
      onTap: () {
        setState(() {
          _role = role;
          if (isBusinessRole) {
            _businessCategory = labelKey == 'shop_role'
                ? kShopCategories.first
                : kCompanyCategories.first;
          } else {
            _businessCategory = null;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.4) : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF0071E3) : Colors.white.withOpacity(0.4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                labelKey.tr(),
                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _jobDropdown() => _glassDropdown(value: _selectedJob, hint: 'specialty_label'.tr(), items: kServices.where((s) => s.type == ServiceType.worker).map((s) => s.name).toList(), onChanged: (v) => setState(() => _selectedJob = v));
  Widget _businessCategoryDropdown() {
    final items = (_role == kRoleBusiness && _businessCategory != null && kShopCategories.contains(_businessCategory)) ? kShopCategories : kCompanyCategories;
    return _glassDropdown(value: _businessCategory, hint: 'business_category_label'.tr(), items: items, onChanged: (v) => setState(() => _businessCategory = v));
  }

  Widget _messageBox() {
    final isSuccess = _message.contains('✅');
    return Padding(padding: const EdgeInsets.only(top: 12), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.35), borderRadius: BorderRadius.circular(10), border: Border.all(color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.7), width: 1.5)), child: Text(_message, style: TextStyle(color: isSuccess ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)));
  }
}
