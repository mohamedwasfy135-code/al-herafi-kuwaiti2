import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/pages/auth_page.dart';
import '../../chat/pages/chat_list_page.dart';
import '../../profile/pages/profile_page.dart';
import '../../requests/pages/request_detail_page.dart';
import '../../shared/ai/ai_assistant_page.dart';
import 'widgets/home_tab.dart';
import 'widgets/requests_tab.dart';

class ClientMainPage extends StatefulWidget {
  const ClientMainPage({super.key});
  @override
  State<ClientMainPage> createState() => _ClientMainPageState();
}

class _ClientMainPageState extends State<ClientMainPage> with WidgetsBindingObserver {
  final _uid = AuthService.currentUser?.id ?? '';
  int _currentTab = 0;
  String _userName = 'عميل';
  String? _requestsError;
  String _aiGuidance = 'welcome_guidance'.tr();
  bool _aiLoading = false;

  List<Map<String, dynamic>> _requests = [];
  StreamSubscription<List<Map<String, dynamic>>>? _requestsSub;
  bool _requestsLoading = true;
  DateTime? _lastUpdateFromStream;

  Timer? _pollingTimer;
  static const _pollInterval = Duration(seconds: 10);
  static const _streamTimeout = Duration(seconds: 15);
  bool _pollingActive = false;
  bool _appInForeground = true;

  static const List<Color> _iconColors = [
    Color(0xFF1976D2), Color(0xFF0D47A1), Color(0xFF0288D1), Color(0xFF1565C0),
    Color(0xFF42A5F5), Color(0xFF1E88E5), Color(0xFF546E7A), Color(0xFF00838F),
    Color(0xFF00695C), Color(0xFF283593), Color(0xFF4527A0),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserName();
    _loadAiGuidance();
    _startRequestsListener();
    _startPollingIfNeeded();
    _startNotificationListener();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = (state == AppLifecycleState.resumed);
    if (_appInForeground) {
      _startRequestsListener();
      _startPollingIfNeeded();
    } else {
      _stopPolling();
    }
  }

  /// Polling stream for client requests
  Stream<List<Map<String, dynamic>>> _requestsStream() async* {
    while (true) {
      try {
        final requests = await FirestoreService.getRequests(clientId: _uid);
        yield requests;
      } catch (e) {
        // Continue polling even on error
      }
      await Future.delayed(_pollInterval);
    }
  }

  void _startRequestsListener() {
    _requestsSub?.cancel();
    setState(() {
      _requestsLoading = _requests.isEmpty;
      _requestsError = null;
    });
    _requestsSub = _requestsStream().listen(
      (requests) {
        if (!mounted) return;
        _lastUpdateFromStream = DateTime.now();
        setState(() {
          _requests = requests;
          _requestsLoading = false;
          _requestsError = null;
        });
        if (_pollingActive) _stopPolling();
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _requestsError = error.toString();
            _requestsLoading = false;
          });
          _startPollingIfNeeded();
        }
      },
      cancelOnError: false,
    );
  }

  void _startPollingIfNeeded() {
    if (!_appInForeground || _pollingActive) return;
    final stale = _lastUpdateFromStream == null ||
        DateTime.now().difference(_lastUpdateFromStream!) > _streamTimeout;
    if (stale) {
      _startPolling();
    } else {
      Future.delayed(_streamTimeout, () {
        if (!mounted || _pollingActive) return;
        final stillStale = _lastUpdateFromStream == null ||
            DateTime.now().difference(_lastUpdateFromStream!) > _streamTimeout;
        if (stillStale) _startPolling();
      });
    }
  }

  void _startPolling() {
    if (_pollingActive) return;
    _pollingActive = true;
    _pollApi();
    _pollingTimer = Timer.periodic(_pollInterval, (_) {
      if (!_appInForeground) {
        _stopPolling();
        return;
      }
      _pollApi();
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingActive = false;
  }

  Future<void> _pollApi() async {
    try {
      final requests = await FirestoreService.getRequests(clientId: _uid);
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _requestsLoading = false;
        _requestsError = null;
      });
    } catch (e) {}
  }

  void _startNotificationListener() {
    NotificationService.listenForNotifications(_uid);
    NotificationService.onNotification = (title, body, data) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$title: $body'),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'view'.tr(),
            onPressed: () {
              if (data != null && data['requestId'] != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) =>
                    RequestDetailPage(requestId: data['requestId']!, isClient: true)));
              }
            },
          ),
        ),
      );
    };
  }

  Future<void> _loadUserName() async {
    try {
      final data = await FirestoreService.getUser(_uid);
      if (data != null && mounted) {
        setState(() => _userName = data['name'] ?? 'user'.tr());
      }
    } catch (e) {}
  }

  Future<void> _loadAiGuidance() async {
    setState(() => _aiLoading = true);
    try {
      final requests = await FirestoreService.getRequests(clientId: _uid);
      if (requests.isEmpty) {
        _aiGuidance = 'welcome_guidance'.tr();
      } else {
        final d = requests.first;
        final status = d['status'] as String? ?? '';
        final service = d['service'] as String? ?? 'service'.tr();
        final craftsman = d['assignedCraftsmanName'] as String?;
        switch (status) {
          case kStatusPending:
            _aiGuidance = 'ai_pending'.tr(args: [service]);
            break;
          case kStatusNotified:
            _aiGuidance = 'ai_notified'.tr(args: [service]);
            break;
          case kStatusAccepted:
            _aiGuidance = 'ai_accepted'.tr(args: [craftsman ?? '', service]);
            break;
          case 'price_proposed':
            _aiGuidance = 'ai_price_proposed'.tr();
            break;
          case 'payment_confirmed':
            _aiGuidance = 'ai_payment_confirmed'.tr();
            break;
          case kStatusInProgress:
            _aiGuidance = 'ai_in_progress'.tr();
            break;
          case kStatusDone:
            _aiGuidance = 'ai_done'.tr();
            break;
          default:
            _aiGuidance = 'ai_default'.tr(args: [service, status]);
        }
      }
    } catch (e) {
      _aiGuidance = 'ai_error'.tr();
    }
    if (mounted) setState(() => _aiLoading = false);
  }

  Future<void> _signOut() async {
    await AuthPage.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthPage()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _requestsSub?.cancel();
    _stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('app_name'.tr(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          Text('hello'.tr(args: [_userName]),
              style: const TextStyle(fontSize: 13, color: Colors.white70)),
        ]),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
          ),
        ),
        actions: [
          // ---- زر تبديل اللغة (بسيط جداً) ----
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: 'language'.tr(),
            onPressed: () {
              final currentLocale = context.locale;
              final newLocale = currentLocale == const Locale('ar')
                  ? const Locale('en')
                  : const Locale('ar');
              context.setLocale(newLocale);
            },
          ),
          // ------------------------------------
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
        ],
      ),
      body: IndexedStack(index: _currentTab, children: [
        HomeTab(
          aiGuidance: _aiGuidance,
          aiLoading: _aiLoading,
          onAiRefresh: _loadAiGuidance,
          iconColors: _iconColors,
        ),
        RequestsTab(
          uid: _uid,
          requestsError: _requestsError,
          requestsLoading: _requestsLoading,
          requests: _requests,
          onRetry: () {
            setState(() => _requestsError = null);
            _startRequestsListener();
          },
        ),
        const ChatListPage(),
        const ProfilePage(),
      ]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        selectedItemColor: const Color(0xFF1565C0),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _currentTab = i),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home_rounded), label: 'home'.tr()),
          BottomNavigationBarItem(icon: const Icon(Icons.list_alt_rounded), label: 'requests'.tr()),
          BottomNavigationBarItem(icon: const Icon(Icons.chat_bubble_rounded), label: 'chats'.tr()),
          BottomNavigationBarItem(icon: const Icon(Icons.person_rounded), label: 'profile'.tr()),
        ],
      ),
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const AiAssistantPage())),
              icon: const Icon(Icons.auto_awesome),
              label: Text('ai_assistant'.tr()),
              backgroundColor: const Color(0xFF1A73E8),
              foregroundColor: Colors.white,
              elevation: 12,
            )
          : null,
      floatingActionButtonLocation: _currentTab == 0
          ? FloatingActionButtonLocation.centerFloat
          : null,
    );
  }
}
