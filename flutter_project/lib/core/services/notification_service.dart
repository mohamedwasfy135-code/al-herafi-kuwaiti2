import 'dart:async';
// ✅ تم إزالة Firebase — نستخدم FirestoreService + إشعارات محلية
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../constants/app_constants.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import 'api_service.dart';

// ✅ لا نحتاج Firebase background handler بعد الآن
// @pragma('vm:entry-point')
// Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async { ... }

final FlutterLocalNotificationsPlugin localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

typedef OnNotificationReceived = void Function(String title, String body, Map<String, dynamic>? data);

class NotificationService {
  NotificationService._();

  static StreamSubscription? _pollSubscription;
  static Timer? _pollTimer;

  static OnNotificationReceived? onNotification;

  // ══ تهيئة الخدمة (يدعم الموبايل والويب) ═══════════════════
  static Future<void> init() async {
    // ✅ تهيئة الإشعارات المحلية فقط (بدون Firebase Messaging)
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await localNotificationsPlugin.initialize(initSettings);

    debugPrint('✅ NotificationService initialized (no Firebase)');
  }

  // ══ إشعار محلي ══════════════════════════════════════════════
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    if (kIsWeb) return;
    const androidDetails = AndroidNotificationDetails(
      'sana3i_channel', 'الحرفي الكويتي',
      channelDescription: 'إشعارات التطبيق',
      importance: Importance.high,
      priority : Priority.high,
      icon     : '@mipmap/ic_launcher',
    );
    await localNotificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  // ══ حفظ FCM Token عبر API ══════════════════════════════════
  static Future<void> saveTokenToServer(String uid) async {
    try {
      // ✅ حفظ التوكن عبر API بدلاً من Firestore المباشر
      await ApiService.put('/api/users/$uid', body: {
        'fcmToken': 'device_token_${DateTime.now().millisecondsSinceEpoch}',
        'tokenUpdatedAt': DateTime.now().toIso8601String(),
      });
      debugPrint('✅ FCM token saved via API for $uid');
    } catch (e) {
      debugPrint('❌ saveTokenToServer error: $e');
    }
  }

  // ══ حذف FCM Token عبر API ══════════════════════════════════
  static Future<void> removeTokenFromServer(String uid) async {
    try {
      stopListeningForNotifications();
      await ApiService.put('/api/users/$uid', body: {
        'fcmToken': null,
        'tokenUpdatedAt': DateTime.now().toIso8601String(),
      });
      debugPrint('✅ FCM token removed via API for $uid');
    } catch (e) {
      debugPrint('❌ removeTokenFromServer error: $e');
    }
  }

  // ══ إرسال إشعار (يحفظ في قاعدة البيانات عبر API) ══════════════════════
  static Future<void> sendNotification({
    required String toUid,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String type = 'general',
  }) async {
    if (toUid.isEmpty || toUid == 'admin_panel') return;
    try {
      // ✅ استخدام FirestoreService بدلاً من Firestore المباشر
      await FirestoreService.sendNotification(
        toUid: toUid,
        title: title,
        body: body,
        type: type,
        data: data,
      );
      debugPrint('✅ Notification saved for $toUid: $title');
    } catch (e) {
      debugPrint('❌ sendNotification error: $e');
    }
  }

  // ══ استماع للإشعارات (polling-based بدلاً من Firestore snapshots) ═════════════════
  static void listenForNotifications(String uid) {
    stopListeningForNotifications();

    debugPrint('🔔 Starting notification listener for $uid');

    // ✅ Polling كل 10 ثوان بدلاً من Firestore snapshots
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        final notifications = await FirestoreService.getNotifications(uid);
        for (final notif in notifications) {
          final isRead = notif['isRead'] as bool? ?? notif['read'] as bool? ?? false;
          final wasShown = notif['shown'] as bool? ?? false;

          if (!isRead && !wasShown) {
            final title = notif['title'] as String? ?? kAppName;
            final body = notif['body'] as String? ?? '';
            final data = notif['data'] as Map<String, dynamic>?;

            await showLocalNotification(
              title: title,
              body: body,
              id: (notif['id'] ?? 0).hashCode,
            );

            onNotification?.call(title, body, data);

            // تعليم كمقروء
            final notifId = notif['id']?.toString();
            if (notifId != null) {
              await FirestoreService.markNotificationRead(notifId);
            }
          }
        }
      } catch (e) {
        debugPrint('❌ Notification polling error: $e');
      }
    });
  }

  // ══ جلب عدد الإشعارات غير المقروءة ══════════════════════════
  static Future<int> getUnreadCount(String uid) async {
    final notifications = await FirestoreService.getNotifications(uid);
    return notifications.where((n) {
      final isRead = n['isRead'] as bool? ?? n['read'] as bool? ?? false;
      return !isRead;
    }).length;
  }

  // ══ Stream لعدد الإشعارات غير المقروءة ══════════════════════════
  static Stream<int> unreadCountStream(String uid) async* {
    while (true) {
      await Future.delayed(const Duration(seconds: 10));
      try {
        yield await getUnreadCount(uid);
      } catch (_) {
        yield 0;
      }
    }
  }

  // ══ تعليم إشعار كمقروء ══════════════════════════════════════
  static Future<void> markAsRead(String notificationId) async {
    await FirestoreService.markNotificationRead(notificationId);
  }

  // ══ إيقاف الاستماع ══════════════════════════════════════
  static void stopListeningForNotifications() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollSubscription?.cancel();
    _pollSubscription = null;
    debugPrint('🔕 Notification listener stopped');
  }

  // ══ مسح جميع إشعارات المستخدم ═══════════════════════════════════
  static Future<void> clearAll(String uid) async {
    // ✅ حذف الإشعارات عبر API
    final notifications = await FirestoreService.getNotifications(uid);
    for (final notif in notifications) {
      final id = notif['id']?.toString();
      if (id != null) {
        await ApiService.delete('/api/notifications/$id');
      }
    }
    debugPrint('🗑️ Cleared all notifications for $uid');
  }
}
