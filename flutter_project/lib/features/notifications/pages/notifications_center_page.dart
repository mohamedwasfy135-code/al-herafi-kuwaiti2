import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/responsive.dart';
import '../../requests/pages/request_detail_page.dart';

class NotificationsCenterPage extends StatefulWidget {
  final String uid;
  const NotificationsCenterPage({super.key, required this.uid});

  @override
  State<NotificationsCenterPage> createState() => _NotificationsCenterPageState();
}

class _NotificationsCenterPageState extends State<NotificationsCenterPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadNotifications());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await FirestoreService.getNotifications(widget.uid);
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ✅ مسح جميع الإشعارات
  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('مسح جميع الإشعارات'),
        content: Text('هل تريد بالتأكيد مسح جميع الإشعارات؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('delete'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await NotificationService.clearAll(widget.uid);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('deleted_successfully'.tr()), backgroundColor: Colors.green),
      );
      _loadNotifications();
    }
  }

  Future<void> _deleteOldNotifications() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('delete_old_notifications'.tr()),
        content: Text('delete_old_notifications_confirm'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('delete'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // حذف الإشعارات الأقدم من 30 يوماً
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final oldNotifs = _notifications.where((n) {
      final sentAt = n['sentAt'] as String?;
      if (sentAt == null) return false;
      try {
        return DateTime.parse(sentAt).isBefore(cutoff);
      } catch (_) {
        return false;
      }
    }).toList();

    for (final notif in oldNotifs) {
      final id = notif['id']?.toString();
      if (id != null) {
        await ApiService.delete('/api/notifications/$id');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('deleted_successfully'.tr()), backgroundColor: Colors.green),
      );
      _loadNotifications();
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'new_request':
        return Icons.build;
      case 'price_proposed':
        return Icons.attach_money;
      case 'new_message':
        return Icons.chat;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = Responsive.isDesktop(context);

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
          Column(
            children: [
              // شريط علوي زجاجي
              ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    color: Colors.white.withOpacity(0.1),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              'notifications_center'.tr(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_sweep, color: Colors.white70),
                            tooltip: 'مسح جميع الإشعارات',
                            onPressed: _clearAll,
                          ),
                          IconButton(
                            icon: const Icon(Icons.auto_delete, color: Colors.white70),
                            tooltip: 'delete_old_notifications'.tr(),
                            onPressed: _deleteOldNotifications,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // قائمة الإشعارات
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isDesktop ? 800 : double.infinity),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)))
                        : _notifications.isEmpty
                            ? Center(
                                child: Text('no_notifications'.tr(),
                                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: _notifications.length,
                                itemBuilder: (_, i) {
                                  final d = _notifications[i];
                                  final title = d['title'] ?? '';
                                  final body = d['body'] ?? '';
                                  final type = d['type'] ?? 'general';
                                  final notifId = d['id']?.toString() ?? '';
                                  final requestId = d['data']?['requestId'] as String? ?? d['referenceId'] as String?;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                                            leading: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0071E3).withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(_iconForType(type), color: const Color(0xFF0071E3), size: 22),
                                            ),
                                            title: Text(
                                              title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: Colors.white,
                                              ),
                                            ),
                                            subtitle: Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Text(
                                                body,
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.7),
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white.withOpacity(0.5)),
                                            onTap: () async {
                                              await FirestoreService.markNotificationRead(notifId);
                                              if (requestId != null) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => RequestDetailPage(
                                                      requestId: requestId,
                                                      isClient: true,
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
