import 'dart:async';
// ✅ تم إزالة Firebase — نستخدم FirestoreService + Socket.IO
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

import 'auth_service.dart';
import 'firestore_service.dart';
import 'notification_service.dart';
import 'api_service.dart';
import 'socket_service.dart';
import 'package:flutter/foundation.dart';

class ChatService {
  ChatService._();

  // ═══════════════════════════════════════════════════════════
  // الدوال الأصلية (محوّلة من Firebase إلى API)
  // ═══════════════════════════════════════════════════════════

  /// إنشاء أو جلب محادثة بين مستخدمين
  static Future<String> getOrCreateChat(String otherUserId) async {
    return await FirestoreService.getOrCreateChat(otherUserId);
  }

  /// إرسال رسالة وتحديث المحادثة
  static Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    try {
      debugPrint('🚀 sendMessage called: chatId=$chatId');

      // ✅ إرسال الرسالة عبر API (حفظ في قاعدة البيانات)
      final success = await FirestoreService.sendMessage(
        chatId: chatId,
        content: text,
        messageType: 'text',
      );

      if (success) {
        debugPrint('✅ Message sent via API');

        // ✅ إرسال عبر Socket.IO للتواصل الفوري
        if (SocketService.isConnected) {
          SocketService.sendMessage(
            chatId: chatId,
            senderId: senderId,
            content: text,
          );
          debugPrint('✅ Message broadcast via Socket.IO');
        }
      } else {
        debugPrint('❌ Failed to send message via API');
      }

      // إرسال إشعار للطرف الآخر
      try {
        final chats = await FirestoreService.getChats();
        final chatData = chats.firstWhere(
          (c) => c['id'] == chatId || c['chatId'] == chatId,
          orElse: () => <String, dynamic>{},
        );

        if (chatData.isNotEmpty) {
          final otherUser = chatData['otherUser'] as Map<String, dynamic>?;
          final participants = chatData['participants'] as List<dynamic>?;
          final otherUserId = otherUser?['id'] as String? ??
              participants?.firstWhere(
                (id) => id != senderId,
                orElse: () => '',
              ) as String? ?? '';

          if (otherUserId.isNotEmpty) {
            await NotificationService.sendNotification(
              toUid: otherUserId,
              title: 'رسالة جديدة من $senderName',
              body: text,
              data: {
                'type': 'new_message',
                'chatId': chatId,
              },
            );
          }
        }
      } catch (e) {
        debugPrint('⚠️ Failed to send notification: $e');
      }
    } catch (e) {
      debugPrint('❌ sendMessage error: $e');
    }
  }

  /// جلب الرسائل داخل محادثة
  static Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    return await FirestoreService.getMessages(chatId);
  }

  /// جلب محادثات المستخدم الحالي
  static Future<List<Map<String, dynamic>>> getUserChats() async {
    return await FirestoreService.getChats();
  }

  /// تعليم جميع رسائل محادثة كمقروءة
  static Future<void> markChatRead(String chatId) async {
    // ✅ استخدام API لتحديث حالة القراءة
    await ApiService.put('/api/chats/$chatId', body: {
      'markRead': true,
    });

    // ✅ إرسال عبر Socket.IO
    if (SocketService.isConnected) {
      SocketService.markRead(chatId);
    }
  }

  /// جلب المجموع الكلي للرسائل غير المقروءة
  static Future<int> getTotalUnread() async {
    final chats = await FirestoreService.getChats();
    final uid = AuthService.currentUser?.id ?? '';
    int total = 0;
    for (final chat in chats) {
      total += (chat['unread_$uid'] ?? chat['unreadCount'] ?? 0) as int;
    }
    return total;
  }

  // ═══════════════════════════════════════════════════════════
  // الدوال الجديدة المضافة لتحسين التوافق مع المشروع
  // ═══════════════════════════════════════════════════════════

  /// إنشاء محادثة أو جلبها مع بيانات إضافية
  static Future<String> createOrGetChat({
    required String otherUserId,
    required String otherUserName,
    String? requestId,
  }) async {
    final myId = AuthService.currentUser?.id ?? '';
    if (myId.isEmpty) return '';

    // إنشاء أو جلب المحادثة عبر API
    final res = await ApiService.post('/api/chats', body: {
      'otherUserId': otherUserId,
      'otherUserName': otherUserName,
      if (requestId != null) 'requestId': requestId,
    });

    if (res.success && res.data != null) {
      // Server returns { data: { id: ... } } or { chatId: ... }
      final chatId = res.data!['chatId'] as String? ??
             res.data!['data']?['id'] as String? ??
             res.data!['id'] as String? ?? '';

      // ✅ الانضمام للمحادثة عبر Socket.IO
      if (chatId.isNotEmpty && SocketService.isConnected) {
        SocketService.joinChat(chatId, userId: myId);
      }

      return chatId;
    }

    // Fallback: استخدام الطريقة الأساسية
    return await getOrCreateChat(otherUserId);
  }

  // ═══════════════════════════════════════════════════════════
  // Stream alternatives — Socket.IO مع fallback إلى polling
  // ═══════════════════════════════════════════════════════════

  /// Stream للرسائل — Socket.IO مع polling كـ fallback
  static Stream<List<Map<String, dynamic>>> messagesStream(String chatId) async* {
    // إذا Socket.IO متصل، نستخدمه
    if (SocketService.isConnected) {
      SocketService.joinChat(chatId);

      await for (final message in SocketService.onNewMessage) {
        if (message['chatId'] == chatId) {
          // إعادة جلب الرسائل من API لضمان التزامن
          final messages = await getMessages(chatId);
          yield messages;
        }
      }
    } else {
      // Fallback: polling كل 3 ثوان
      while (true) {
        await Future.delayed(const Duration(seconds: 3));
        try {
          yield await getMessages(chatId);
        } catch (_) {
          yield [];
        }
      }
    }
  }

  /// Stream لمحادثات المستخدم — Socket.IO مع polling كـ fallback
  static Stream<List<Map<String, dynamic>>> userChatsStream() async* {
    if (SocketService.isConnected) {
      await for (final _ in SocketService.onChatUpdated) {
        try {
          yield await getUserChats();
        } catch (_) {
          yield [];
        }
      }
    } else {
      while (true) {
        await Future.delayed(const Duration(seconds: 5));
        try {
          yield await getUserChats();
        } catch (_) {
          yield [];
        }
      }
    }
  }

  /// Stream للرسائل غير المقروءة — Socket.IO مع polling كـ fallback
  static Stream<int> totalUnreadStream() async* {
    if (SocketService.isConnected) {
      // عند استلام رسالة جديدة أو تعليم كمقروء
      await for (final _ in SocketService.onNewMessage) {
        try {
          yield await getTotalUnread();
        } catch (_) {
          yield 0;
        }
      }
    } else {
      while (true) {
        await Future.delayed(const Duration(seconds: 5));
        try {
          yield await getTotalUnread();
        } catch (_) {
          yield 0;
        }
      }
    }
  }

  /// Stream لحالة الكتابة
  static Stream<Map<String, dynamic>> typingStream(String chatId) {
    return SocketService.onTyping.where((data) => data['chatId'] == chatId);
  }

  /// Stream لإيقاف الكتابة
  static Stream<Map<String, dynamic>> stopTypingStream(String chatId) {
    return SocketService.onStopTyping.where((data) => data['chatId'] == chatId);
  }

  /// إرسال حالة الكتابة
  static void emitTyping(String chatId) {
    if (SocketService.isConnected) {
      SocketService.emitTyping(chatId);
    }
  }

  /// إيقاف حالة الكتابة
  static void emitStopTyping(String chatId) {
    if (SocketService.isConnected) {
      SocketService.emitStopTyping(chatId);
    }
  }
}
