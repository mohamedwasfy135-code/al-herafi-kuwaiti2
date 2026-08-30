import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/services_data.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/pages/auth_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _picker = ImagePicker();

  String? _uid;
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _craftsmanData;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _selectedGovernorate;
  String? _selectedJob;
  bool _isAvailable = true;

  final _bankNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _ibanCtrl = TextEditingController();
  final _wamdPhoneCtrl = TextEditingController();

  int _totalRequests = 0;
  int _completedRequests = 0;

  @override
  void initState() {
    super.initState();
    _uid = AuthService.currentUser?.id;
    if (_uid != null) {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final userDoc = await FirestoreService.getUser(_uid!);
      if (userDoc == null) {
        setState(() => _loading = false);
        _error = 'user_account_not_found'.tr();
        return;
      }
      _userData = userDoc;
      _nameCtrl.text = _userData?['name'] ?? '';
      _phoneCtrl.text = _userData?['phone'] ?? '';
      _selectedGovernorate = _userData?['governorate'];

      if (_userData?['role'] == kRoleCraftsman) {
        // Load craftsman data from the user doc (role-specific fields)
        // or fetch separately if stored in a different collection/table
        try {
          final craftRes = await ApiService.get('/api/craftsmen/$_uid');
          if (craftRes.success && craftRes.data != null) {
            _craftsmanData = craftRes.data!['craftsman'] as Map<String, dynamic>? ?? craftRes.data!;
            _isAvailable = _craftsmanData?['isAvailable'] ?? true;
            _selectedJob = _craftsmanData?['job'];
            _bankNameCtrl.text = _craftsmanData?['bankName'] ?? '';
            _accountNumberCtrl.text = _craftsmanData?['accountNumber'] ?? '';
            _ibanCtrl.text = _craftsmanData?['iban'] ?? '';
            _wamdPhoneCtrl.text = _craftsmanData?['wamdPhone'] ?? '';
          }
        } catch (_) {
          // Craftsman data might be embedded in user doc
          _isAvailable = _userData?['isAvailable'] ?? true;
          _selectedJob = _userData?['job'];
          _bankNameCtrl.text = _userData?['bankName'] ?? '';
          _accountNumberCtrl.text = _userData?['accountNumber'] ?? '';
          _ibanCtrl.text = _userData?['iban'] ?? '';
          _wamdPhoneCtrl.text = _userData?['wamdPhone'] ?? '';
        }
      }

      await _loadStats();

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '${'data_load_failed'.tr()}: $e';
      });
    }
  }

  Future<void> _loadStats() async {
    if (_userData?['role'] == kRoleCraftsman) {
      _totalRequests = _craftsmanData?['totalJobs'] ?? 0;
      _completedRequests = _craftsmanData?['completedJobs'] ?? 0;
    } else {
      final requests = await FirestoreService.getRequests(clientId: _uid);
      _totalRequests = requests.length;
      _completedRequests =
          requests.where((d) => d['status'] == kStatusDone).length;
    }
  }

  Future<void> _saveChanges() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showSnack('enter_name_required'.tr(), color: Colors.red);
      return;
    }

    setState(() => _saving = true);

    try {
      final updates = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'governorate': _selectedGovernorate,
      };
      final userUpdated = await FirestoreService.updateUser(_uid!, updates);

      if (_userData?['role'] == kRoleCraftsman && _craftsmanData != null) {
        await ApiService.put('/api/craftsmen/$_uid', body: {
          'job': _selectedJob,
          'isAvailable': _isAvailable,
          'bankName': _bankNameCtrl.text.trim(),
          'accountNumber': _accountNumberCtrl.text.trim(),
          'iban': _ibanCtrl.text.trim(),
          'wamdPhone': _wamdPhoneCtrl.text.trim(),
        });
      }

      // Refresh user data from API
      await AuthService.refreshUser();

      setState(() {
        _userData?['name'] = updates['name'];
        _userData?['phone'] = updates['phone'];
        _userData?['governorate'] = updates['governorate'];
      });
      _showSnack('changes_saved_success'.tr(), color: Colors.green);
    } catch (e) {
      _showSnack('${'save_failed'.tr()}: $e', color: Colors.red);
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final picked = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;

      setState(() => _saving = true);

      // Upload avatar via API
      final uploadRes = await ApiService.uploadFile(
        '/api/upload',
        filePath: picked.path,
        fieldName: 'avatar',
        fields: {
          'userId': _uid ?? '',
          'folder': 'avatars',
        },
      );

      if (uploadRes.success && uploadRes.data != null) {
        final downloadUrl = uploadRes.data!['url'] as String? ?? '';

        await FirestoreService.updateUser(_uid!, {'photoURL': downloadUrl});

        setState(() => _userData?['photoURL'] = downloadUrl);
        _showSnack('avatar_updated_success'.tr(), color: Colors.green);
      } else {
        _showSnack('${'avatar_upload_failed'.tr()}', color: Colors.red);
      }
    } catch (e) {
      _showSnack('${'avatar_upload_failed'.tr()}: $e', color: Colors.red);
    } finally {
      setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const AuthPage()),
          (route) => false);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('delete_account_confirm_title'.tr()),
        content: Text('delete_account_confirm_body'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('delete'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _saving = true);
      // Delete account via API
      final res = await ApiService.delete('/api/users/$_uid');
      if (res.success) {
        await AuthService.signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const AuthPage()),
              (route) => false);
        }
      } else {
        setState(() => _saving = false);
        _showSnack('${'account_delete_failed'.tr()}: ${res.errorMessage}', color: Colors.red);
      }
    } catch (e) {
      setState(() => _saving = false);
      _showSnack('${'account_delete_failed'.tr()}: $e', color: Colors.red);
    }
  }

  void _showSnack(String message, {Color color = Colors.blue}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _bankNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _ibanCtrl.dispose();
    _wamdPhoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF0071E3))),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
              'assets/images/ocean_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1D1D1F), Color(0xFF003366), Color(0xFF00509E)],
                  ),
                ),
              ),
            ),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.25)),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadProfile,
                      icon: const Icon(Icons.refresh),
                      label: Text('retry'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0071E3),
                        foregroundColor: const Color(0xFF1D1D1F),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final isCraftsman = _userData?['role'] == kRoleCraftsman;
    final photoURL = _userData?['photoURL'] as String?;
    final email = AuthService.currentUser?.email ?? '';

    return Scaffold(
      body: Stack(
        children: [
          // صورة الخلفية
          Positioned.fill(
            child: Image.asset(
              'assets/images/ocean_bg.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1D1D1F), Color(0xFF003366), Color(0xFF00509E)],
                  ),
                ),
              ),
            ),
          ),
          // طبقة داكنة شفافة
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.25)),
          ),
          // تأثير زجاجي خفيف
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(color: Colors.black.withOpacity(0.05)),
            ),
          ),
          // المحتوى
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  background: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _pickAndUploadAvatar,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 55,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              child: CircleAvatar(
                                radius: 52,
                                backgroundImage: photoURL != null
                                    ? CachedNetworkImageProvider(photoURL)
                                    : null,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                child: photoURL == null
                                    ? const Icon(Icons.person, size: 55, color: Colors.white)
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _userData?['name'] ?? 'user'.tr(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: TextStyle(color: Colors.white.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isDesktop)
                SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 24, 12, 40),
                              child: _buildLeftColumn(isCraftsman),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 24, 24, 40),
                              child: _buildRightColumn(isCraftsman),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLeftColumn(isCraftsman),
                        _buildRightColumn(isCraftsman),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(bool isCraftsman) {
    return Column(
      children: [
        _buildSectionCard(
          title: 'personal_info_title'.tr(),
          icon: Icons.manage_accounts,
          children: [
            _glassField(_nameCtrl, 'full_name'.tr(), Icons.person_outline),
            const SizedBox(height: 14),
            _glassField(_phoneCtrl, 'phone_number'.tr(), Icons.phone_android_outlined, isPhone: true),
            const SizedBox(height: 14),
            _glassDropdown(
              value: _selectedGovernorate,
              hint: 'governorate_label'.tr(),
              items: kGovernorates,
              onChanged: (val) => setState(() => _selectedGovernorate = val),
            ),
            if (isCraftsman) ...[
              const SizedBox(height: 14),
              _glassDropdown(
                value: _selectedJob,
                hint: 'specialty_label'.tr(),
                items: kServices.where((s) => s.type == ServiceType.worker).map((s) => s.name).toList(),
                onChanged: (val) => setState(() => _selectedJob = val),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('available_for_requests'.tr(), style: const TextStyle(color: Colors.white)),
                value: _isAvailable,
                onChanged: (val) => setState(() => _isAvailable = val),
                activeColor: const Color(0xFF0071E3),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveChanges,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1D1D1F)))
                    : const Icon(Icons.save_rounded, color: Color(0xFF1D1D1F)),
                label: Text('save_changes'.tr(), style: const TextStyle(color: Color(0xFF1D1D1F))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0071E3),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        if (isCraftsman) ...[
          const SizedBox(height: 20),
          _buildSectionCard(
            title: 'bank_info_title'.tr(),
            icon: Icons.account_balance,
            children: [
              _glassField(_bankNameCtrl, 'bank_name'.tr(), Icons.business),
              const SizedBox(height: 14),
              _glassField(_accountNumberCtrl, 'account_number'.tr(), Icons.credit_card, isPhone: true),
              const SizedBox(height: 14),
              _glassField(_ibanCtrl, 'IBAN', Icons.qr_code),
              const SizedBox(height: 14),
              _glassField(_wamdPhoneCtrl, 'wamd_phone_optional'.tr(), Icons.phone_android, isPhone: true),
            ],
          ),
        ],
        const SizedBox(height: 20),
        _buildStatsCard(isCraftsman),
      ],
    );
  }

  Widget _buildRightColumn(bool isCraftsman) {
    return Column(
      children: [
        _buildSettingsCard(),
        const SizedBox(height: 20),
        Center(
          child: Text(
            '${'app_name'.tr()} - ${'version_label'.tr()} $kAppVersion',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: const Color(0xFF0071E3), size: 24),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(bool isCraftsman) {
    if (_totalRequests == 0 && _completedRequests == 0) {
      return const SizedBox.shrink();
    }
    return _buildSectionCard(
      title: isCraftsman ? 'craftsman_stats'.tr() : 'your_requests_stats'.tr(),
      icon: Icons.bar_chart_rounded,
      children: [
        Row(
          children: [
            Expanded(
              child: _statTile(
                'total_stats_label'.tr(),
                _totalRequests.toString(),
                Colors.blue,
                Icons.list_alt_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statTile(
                'completed_stats_label'.tr(),
                _completedRequests.toString(),
                Colors.green,
                Icons.check_circle_outline_rounded,
              ),
            ),
            if (isCraftsman) ...[
              const SizedBox(width: 12),
              Expanded(
                child: _statTile(
                  'rating_label'.tr(),
                  '${_craftsmanData?['rating'] ?? '0'} ⭐',
                  Colors.orange,
                  Icons.star_rounded,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _statTile(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color.withOpacity(0.9), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return _buildSectionCard(
      title: 'settings_label'.tr(),
      icon: Icons.settings,
      children: [
        _settingsTile(
          icon: Icons.language,
          title: 'change_language'.tr(),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => context.setLocale(const Locale('ar')),
                child: const Text('عربي', style: TextStyle(color: Color(0xFF0071E3))),
              ),
              TextButton(
                onPressed: () => context.setLocale(const Locale('en')),
                child: const Text('English', style: TextStyle(color: Color(0xFF0071E3))),
              ),
            ],
          ),
        ),
        Divider(color: Colors.white.withOpacity(0.2)),
        _settingsTile(
          icon: Icons.logout,
          title: 'logout_btn'.tr(),
          color: Colors.red,
          onTap: _logout,
        ),
        Divider(color: Colors.white.withOpacity(0.2)),
        _settingsTile(
          icon: Icons.delete_forever,
          title: 'delete_account_btn'.tr(),
          color: Colors.red,
          onTap: _deleteAccount,
        ),
      ],
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    Color? color,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFF0071E3)),
      title: Text(title,
          style: TextStyle(fontWeight: FontWeight.w500, color: color ?? Colors.white)),
      trailing: trailing ?? Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white.withOpacity(0.6)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _glassField(TextEditingController ctrl, String label, IconData icon,
      {bool isPhone = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white, size: 20),
        filled: true,
        fillColor: Colors.white.withOpacity(0.15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.5), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF0071E3), width: 1.8),
        ),
      ),
    );
  }

  Widget _glassDropdown({String? value, required String hint, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          dropdownColor: const Color(0xFF003366),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white, fontSize: 13)))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
