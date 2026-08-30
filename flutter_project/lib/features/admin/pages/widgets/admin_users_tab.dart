import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../shared/widgets/paginated_list.dart';

class AdminUsersTab extends StatelessWidget {
  const AdminUsersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return PaginatedApiList(
      fetcher: ({required int page, required int pageSize}) async {
        final res = await ApiService.get('/api/users');
        if (res.success && res.data != null) {
          final users = res.data!['users'] as List<dynamic>?;
          return users?.cast<Map<String, dynamic>>() ?? [];
        }
        return <Map<String, dynamic>>[];
      },
      pageSize: 20,
      emptyWidget: Center(
        child: Text('no_users'.tr(), style: const TextStyle(color: Colors.white70)),
      ),
      itemBuilder: (ctx, d, _) => _UserTile(data: d),
    );
  }
}

// ويدجت مستقل لكل مستخدم – يدير حالة المفتاح محليًا ويُحدِّث API
class _UserTile extends StatefulWidget {
  final Map<String, dynamic> data;
  const _UserTile({required this.data});

  @override
  State<_UserTile> createState() => _UserTileState();
}

class _UserTileState extends State<_UserTile> {
  Timer? _pollTimer;
  Map<String, dynamic> _currentData = {};
  bool _skipVerification = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _currentData = Map<String, dynamic>.from(widget.data);
    _skipVerification = _currentData['skipEmailVerification'] as bool? ?? false;
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) => _refreshData());
  }

  Future<void> _refreshData() async {
    final uid = _currentData['id'] as String?;
    if (uid == null) return;
    try {
      final user = await FirestoreService.getUser(uid);
      if (user != null && mounted) {
        setState(() {
          _currentData = user;
          _skipVerification = _currentData['skipEmailVerification'] as bool? ?? false;
        });
      }
    } catch (_) {}
  }

  Color _roleColor(String r) => switch (r) {
    kRoleCraftsman => Colors.orange,
    kRoleAdmin => Colors.red,
    kRoleBusiness => Colors.teal,
    kRoleOffice => Colors.purple,
    _ => Colors.blue,
  };

  IconData _roleIcon(String r) => switch (r) {
    kRoleCraftsman => Icons.construction,
    kRoleAdmin => Icons.admin_panel_settings,
    kRoleBusiness => Icons.store,
    kRoleOffice => Icons.engineering,
    _ => Icons.person,
  };

  String _roleLabel(String r) => switch (r) {
    kRoleCraftsman => 'craftsman_role'.tr(),
    kRoleAdmin     => 'admin_role'.tr(),
    kRoleBusiness  => 'business_role'.tr(),
    kRoleOffice    => 'office_role'.tr(),
    _              => 'client_role'.tr(),
  };

  Future<void> _toggleSkip() async {
    setState(() => _loading = true);
    try {
      final uid = _currentData['id'] as String?;
      if (uid == null) return;
      await FirestoreService.updateUser(uid, {
        'skipEmailVerification': !_skipVerification,
      });
      await _refreshData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التحديث: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = _currentData['role'] as String? ?? kRoleClient;
    final color = _roleColor(role);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withOpacity(0.2),
                child: Icon(_roleIcon(role), color: color),
              ),
              title: Text(
                _currentData['name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              subtitle: Text(
                '${_currentData['email'] ?? ''} | ${_currentData['phone'] ?? ''} | ${_roleLabel(role)}',
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
              trailing: _loading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Switch(
                      value: _skipVerification,
                      activeColor: Colors.greenAccent,
                      onChanged: (_) => _toggleSkip(),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
