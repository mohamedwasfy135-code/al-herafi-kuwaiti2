import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import 'widgets/explore_tab.dart';
import 'widgets/requests_tab.dart';
import '../../chat/pages/chat_list_page.dart';
import '../../profile/pages/profile_page.dart';
import '../../shared/ai/ai_assistant_page.dart';
import '../../notifications/pages/notifications_center_page.dart';
import '../../auth/pages/auth_page.dart';

class ClientMainPage extends StatefulWidget {
  const ClientMainPage({super.key});
  @override
  State<ClientMainPage> createState() => _ClientMainPageState();
}

class _ClientMainPageState extends State<ClientMainPage> {
  final _uid = AuthService.currentUser?.id ?? '';
  int _currentTab = 0;
  String _userName = 'User';
  bool _loadingName = true;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final data = await FirestoreService.getUser(_uid);
      if (data != null && mounted) {
        setState(() => _userName = data['name'] ?? 'User');
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingName = false);
  }

  Future<void> _signOut() async {
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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('app_name'.tr(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            Text(_loadingName ? '...' : 'hello'.tr(args: [_userName]),
                style: const TextStyle(fontSize: 13)),
          ],
        ),
        backgroundColor: Colors.black.withOpacity(0.3),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NotificationsCenterPage(uid: _uid)),
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
            onPressed: _signOut,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset('assets/images/ocean_bg.jpg', fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF1D1D1F), Color(0xFF003366), Color(0xFF00509E)],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.25))),
          IndexedStack(
            index: _currentTab,
            children: [
              const ExploreTab(),
              RequestsTab(uid: _uid),
              const ChatListPage(),
              const ProfilePage(),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(15),
            topRight: Radius.circular(15),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentTab,
            onTap: (i) => setState(() => _currentTab = i),
            selectedItemColor: const Color(0xFF0071E3),
            unselectedItemColor: Colors.white60,
            backgroundColor: Colors.black.withOpacity(0.6),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.explore),
                activeIcon: Icon(Icons.explore),
                label: 'استكشاف',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long),
                label: 'طلباتي',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.chat_outlined),
                activeIcon: Icon(Icons.chat),
                label: 'محادثات',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'حسابي',
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const AiAssistantPage())),
              icon: const Icon(Icons.auto_awesome, color: Color(0xFF1D1D1F)),
              label: Text('ai_assistant'.tr(),
                  style: const TextStyle(color: Color(0xFF1D1D1F), fontWeight: FontWeight.bold)),
              backgroundColor: const Color(0xFF0071E3),
              elevation: 8,
            )
          : null,
      floatingActionButtonLocation: _currentTab == 0
          ? FloatingActionButtonLocation.centerFloat
          : null,
    );
  }
}
