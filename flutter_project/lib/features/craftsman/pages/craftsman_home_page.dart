import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/auto_assign_service.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/pages/auth_page.dart';
import '../../chat/pages/chat_list_page.dart';
import '../../profile/pages/profile_page.dart';
import '../../notifications/pages/notifications_center_page.dart';
import 'widgets/craftsman_requests_tab.dart';
import 'widgets/craftsman_earnings_tab.dart';

class CraftsmanHomePage extends StatefulWidget {
  const CraftsmanHomePage({super.key});

  @override
  State<CraftsmanHomePage> createState() => _CraftsmanHomePageState();
}

class _CraftsmanHomePageState extends State<CraftsmanHomePage> {
  final _uid = AuthService.currentUser?.id ?? '';
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    NotificationService.listenForNotifications(_uid);
    NotificationService.saveTokenToServer(_uid);
  }

  @override
  void dispose() {
    NotificationService.stopListeningForNotifications();
    super.dispose();
  }

  Future<void> _logout() async {
    AutoAssignService.cancelAllTimers();
    await NotificationService.removeTokenFromServer(_uid);
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
    return Scaffold(
      backgroundColor: const Color(0xFF1D1D1F),
      appBar: AppBar(
        title: Text(
          'my_requests_title'.tr(),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black.withOpacity(0.3),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationsCenterPage(uid: _uid),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () {
              final newLocale = context.locale == const Locale('ar')
                  ? const Locale('en')
                  : const Locale('ar');
              context.setLocale(newLocale);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTab,
        children: [
          CraftsmanRequestsTab(uid: _uid),
          const ChatListPage(),
          CraftsmanEarningsTab(uid: _uid),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        selectedItemColor: const Color(0xFF0071E3),
        unselectedItemColor: Colors.white60,
        backgroundColor: Colors.black.withOpacity(0.6),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.build),
            label: 'requests'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline),
            label: 'chats'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.monetization_on),
            label: 'earnings_tab'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            label: 'profile'.tr(),
          ),
        ],
      ),
    );
  }
}
