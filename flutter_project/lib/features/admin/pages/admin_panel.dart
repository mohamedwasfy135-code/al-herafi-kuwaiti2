import 'dart:async';
import 'widgets/admin_verification_tab.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'widgets/admin_analytics_page.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auto_assign_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/responsive.dart';
import '../../auth/pages/auth_page.dart';
import 'widgets/admin_requests_tab.dart';
import 'widgets/admin_invoices_tab.dart';
import 'widgets/admin_craftsmen_tab.dart';
import 'widgets/admin_users_tab.dart';
import 'widgets/admin_products_tab.dart';
import 'widgets/admin_subscriptions_tab.dart';
import 'widgets/admin_payouts_tab.dart';
import 'widgets/admin_earnings_tab.dart';
import 'widgets/admin_api_key_tab.dart';
import 'widgets/admin_treasury_tab.dart';

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});
  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  int _tab = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Stats data from API
  int _pendingCount = 0;
  int _activeCount = 0;
  int _doneCount = 0;
  int _problemCount = 0;
  bool _statsLoading = true;

  List<_TabInfo> get _tabs => [
    _TabInfo(Icons.inbox_rounded, 'tab_active'.tr(), 0),
    _TabInfo(Icons.warning_rounded, 'tab_problems'.tr(), 1),
    _TabInfo(Icons.list_alt_rounded, 'tab_all'.tr(), 2),
    _TabInfo(Icons.receipt_long_rounded, 'tab_invoices'.tr(), 3),
    _TabInfo(Icons.construction_rounded, 'tab_craftsmen'.tr(), 4),
    _TabInfo(Icons.people_rounded, 'tab_users'.tr(), 5),
    _TabInfo(Icons.inventory_2_rounded, 'tab_products'.tr(), 6),
    _TabInfo(Icons.insights_rounded, 'tab_analytics'.tr(), 7),
    _TabInfo(Icons.vpn_key_rounded, 'tab_openrouter'.tr(), 8),
    _TabInfo(Icons.card_membership_rounded, 'tab_subscriptions'.tr(), 9),
    _TabInfo(Icons.trending_up_rounded, 'tab_earnings'.tr(), 10),
    _TabInfo(Icons.account_balance_wallet_rounded, 'tab_payouts'.tr(), 11),
    _TabInfo(Icons.account_balance_rounded, 'tab_treasury'.tr(), 12),
    _TabInfo(Icons.verified_user_rounded, 'التحقق من الحسابات', 13),
  ];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final requests = await FirestoreService.getRequests();
      if (mounted) {
        setState(() {
          _pendingCount = requests.where((d) => d['status'] == kStatusPending || d['status'] == kStatusNotified).length;
          _activeCount = requests.where((d) => d['status'] == kStatusAccepted || d['status'] == kStatusInProgress).length;
          _doneCount = requests.where((d) => d['status'] == kStatusDone).length;
          _problemCount = requests.where((d) => d['status'] == kStatusNoCraftsman || d['status'] == kStatusNeedsAdmin).length;
          _statsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  /// Polling stream for admin stats
  Stream<Map<String, int>> _statsStream() async* {
    while (true) {
      try {
        final requests = await FirestoreService.getRequests();
        yield {
          'pending': requests.where((d) => d['status'] == kStatusPending || d['status'] == kStatusNotified).length,
          'active': requests.where((d) => d['status'] == kStatusAccepted || d['status'] == kStatusInProgress).length,
          'done': requests.where((d) => d['status'] == kStatusDone).length,
          'problem': requests.where((d) => d['status'] == kStatusNoCraftsman || d['status'] == kStatusNeedsAdmin).length,
        };
      } catch (e) {
        yield {'pending': _pendingCount, 'active': _activeCount, 'done': _doneCount, 'problem': _problemCount};
      }
      await Future.delayed(const Duration(seconds: 15));
    }
  }

  Widget _buildCurrentTab() {
    Widget tab;
    switch (_tab) {
      case 0: tab = AdminRequestsTab(filter: 'active'); break;
      case 1: tab = AdminRequestsTab(filter: 'problem'); break;
      case 2: tab = AdminRequestsTab(filter: 'all'); break;
      case 3: tab = const AdminInvoicesTab(); break;
      case 4: tab = const AdminCraftsmenTab(); break;
      case 5: tab = const AdminUsersTab(); break;
      case 6: tab = const AdminProductsTab(); break;
      case 7: tab = const AdminAnalyticsPage(); break;
      case 8: tab = const AdminApiKeyTab(); break;
      case 9: tab = const AdminSubscriptionsTab(); break;
      case 10: tab = const AdminEarningsTab(); break;
      case 11: tab = const AdminPayoutsTab(); break;
      case 12: tab = const AdminTreasuryTab(); break;
      case 13: tab = const AdminVerificationTab(); break;
      default: tab = const SizedBox.shrink();
    }
    try {
      return tab;
    } catch (e) {
      return Center(
        child: Text('خطأ: $e', style: const TextStyle(color: Colors.red)),
      );
    }
  }

  Widget _buildStatsHeader() {
    return StreamBuilder<Map<String, int>>(
      stream: _statsStream(),
      builder: (_, snap) {
        if (snap.hasError) {
          return Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(children: [
              Icon(Icons.error_outline, color: Colors.red, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('خطأ في الإحصائيات', style: TextStyle(color: Colors.red.shade400, fontSize: 13))),
            ]),
          );
        }
        if (!snap.hasData) {
          return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
        }
        final stats = snap.data!;
        final pending = stats['pending'] ?? 0;
        final active = stats['active'] ?? 0;
        final done = stats['done'] ?? 0;
        final problem = stats['problem'] ?? 0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Row(
            children: [
              _statCard('admin_pending'.tr(), pending.toString(), Icons.inbox_rounded, Colors.orange),
              const SizedBox(width: 12),
              _statCard('admin_active'.tr(), active.toString(), Icons.play_circle_rounded, const Color(0xFF0071E3)),
              const SizedBox(width: 12),
              _statCard('admin_completed'.tr(), done.toString(), Icons.check_circle_rounded, Colors.green),
              const SizedBox(width: 12),
              _statCard('admin_problem'.tr(), problem.toString(), Icons.warning_rounded, Colors.red),
            ],
          ),
        );
      },
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
            ),
            child: Column(children: [
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 10),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8))),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    AutoAssignService.cancelAllTimers();
    final uid = AuthService.currentUser?.id;
    if (uid != null) await NotificationService.removeTokenFromServer(uid);
    await AuthService.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);
    final tabs = _tabs;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: Colors.transparent,
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
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(color: Colors.black.withOpacity(0.05)),
              ),
            ),
            Row(
              children: [
                ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: 260,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.2))),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
                            child: Text('admin_panel'.tr(),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                          const Divider(color: Colors.white10),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              children: tabs.map((t) {
                                final isSelected = _tab == t.index;
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF0071E3).withOpacity(0.15) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: ListTile(
                                    leading: Icon(t.icon,
                                        size: 16,
                                        color: isSelected ? const Color(0xFF0071E3) : Colors.white70),
                                    title: Text(t.title,
                                        style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            color: isSelected ? const Color(0xFF0071E3) : Colors.white)),
                                    selected: isSelected,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    onTap: () => setState(() => _tab = t.index),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const Divider(color: Colors.white10),
                          ListTile(
                            leading: Icon(Icons.language_rounded, size: 16, color: Colors.white70),
                            title: Text('change_language'.tr(), style: const TextStyle(fontSize: 14, color: Colors.white)),
                            onTap: () {
                              final newLocale = context.locale == const Locale('ar')
                                  ? const Locale('en')
                                  : const Locale('ar');
                              context.setLocale(newLocale);
                              setState(() {});
                            },
                          ),
                          ListTile(
                            leading: Icon(Icons.logout_rounded, size: 16, color: Colors.red),
                            title: Text('logout_btn'.tr(), style: const TextStyle(fontSize: 14, color: Colors.red)),
                            onTap: _signOut,
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _buildStatsHeader(),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: _buildCurrentTab(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // ✅ نسخة الجوال – مع درج داكن وواضح
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.transparent,
      drawer: _buildDrawer(tabs),
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
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(color: Colors.black.withOpacity(0.05)),
            ),
          ),
          Column(
            children: [
              ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    color: Colors.white.withOpacity(0.1),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white),
                            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                          ),
                          Expanded(
                            child: Text('admin_panel'.tr(),
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.language_rounded, color: Colors.white70, size: 22),
                            onPressed: () {
                              final newLocale = context.locale == const Locale('ar')
                                  ? const Locale('en')
                                  : const Locale('ar');
                              context.setLocale(newLocale);
                              setState(() {});
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.logout_rounded, color: Colors.red.shade300, size: 22),
                            onPressed: _signOut,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _buildStatsHeader(),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: _buildCurrentTab(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ درج داكن جداً وواضح
  Widget _buildDrawer(List<_TabInfo> tabs) {
    return Drawer(
      child: Container(
        color: const Color(0xFF0A1628), // خلفية داكنة جداً
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF0D1F3C),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.admin_panel_settings, color: Color(0xFF0071E3), size: 40),
                  const SizedBox(height: 12),
                  Text('admin_panel'.tr(),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('control_center'.tr(),
                      style: const TextStyle(fontSize: 14, color: Color(0xFFB0BEC5))),
                ],
              ),
            ),
            ...tabs.map((t) {
              final isSelected = _tab == t.index;
              return Container(
                color: isSelected ? const Color(0xFF0071E3).withOpacity(0.2) : Colors.transparent,
                child: ListTile(
                  leading: Icon(t.icon, size: 22, color: isSelected ? const Color(0xFF0071E3) : Colors.white),
                  title: Text(t.title,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? const Color(0xFF0071E3) : Colors.white)),
                  onTap: () {
                    setState(() => _tab = t.index);
                    Navigator.pop(context);
                  },
                ),
              );
            }),
            const Divider(color: Color(0xFF2C3E50), height: 1),
            ListTile(
              leading: const Icon(Icons.language_rounded, size: 22, color: Colors.white),
              title: Text('change_language'.tr(), style: const TextStyle(color: Colors.white, fontSize: 12)),
              onTap: () {
                final newLocale = context.locale == const Locale('ar')
                    ? const Locale('en')
                    : const Locale('ar');
                context.setLocale(newLocale);
                setState(() {});
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, size: 22, color: Colors.redAccent),
              title: Text('logout_btn'.tr(), style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              onTap: () {
                Navigator.pop(context);
                _signOut();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TabInfo {
  final IconData icon;
  final String title;
  final int index;
  const _TabInfo(this.icon, this.title, this.index);
}
