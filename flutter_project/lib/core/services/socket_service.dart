// ═══════════════════════════════════════════════════════════════════
// خدمة Socket.IO — اتصال فوري بدلاً من polling
// الحرفي الكويتي — ترقية Real-time
// ═══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'api_service.dart';
import 'auth_service.dart';

/// خدمة Socket.IO المركزية — بديل polling للتواصل الفوري
class SocketService {
  SocketService._();

  static IO.Socket? _socket;
  static bool _isConnected = false;
  static String? _currentUserId;

  // ══ Stream Controllers ═══════════════════════════════════════
  static final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  static final _chatUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  static final _typingController = StreamController<Map<String, dynamic>>.broadcast();
  static final _stopTypingController = StreamController<Map<String, dynamic>>.broadcast();
  static final _incomingCallController = StreamController<Map<String, dynamic>>.broadcast();
  static final _callAnsweredController = StreamController<Map<String, dynamic>>.broadcast();
  static final _callRejectedController = StreamController<Map<String, dynamic>>.broadcast();
  static final _callEndedController = StreamController<Map<String, dynamic>>.broadcast();
  static final _callOfferController = StreamController<Map<String, dynamic>>.broadcast();
  static final _callAnswerSdpController = StreamController<Map<String, dynamic>>.broadcast();
  static final _iceCandidateController = StreamController<Map<String, dynamic>>.broadcast();
  static final _messagesReadController = StreamController<Map<String, dynamic>>.broadcast();
  static final _connectionController = StreamController<bool>.broadcast();

  // ══ Streams العامة ═══════════════════════════════════════════
  static Stream<Map<String, dynamic>> get onNewMessage => _messageController.stream;
  static Stream<Map<String, dynamic>> get onChatUpdated => _chatUpdatedController.stream;
  static Stream<Map<String, dynamic>> get onTyping => _typingController.stream;
  static Stream<Map<String, dynamic>> get onStopTyping => _stopTypingController.stream;
  static Stream<Map<String, dynamic>> get onIncomingCall => _incomingCallController.stream;
  static Stream<Map<String, dynamic>> get onCallAnswered => _callAnsweredController.stream;
  static Stream<Map<String, dynamic>> get onCallRejected => _callRejectedController.stream;
  static Stream<Map<String, dynamic>> get onCallEnded => _callEndedController.stream;
  static Stream<Map<String, dynamic>> get onCallOffer => _callOfferController.stream;
  static Stream<Map<String, dynamic>> get onCallAnswerSdp => _callAnswerSdpController.stream;
  static Stream<Map<String, dynamic>> get onIceCandidate => _iceCandidateController.stream;
  static Stream<Map<String, dynamic>> get onMessagesRead => _messagesReadController.stream;
  static Stream<bool> get onConnectionChanged => _connectionController.stream;

  static bool get isConnected => _isConnected;

  // ══ اتصال Socket ═══════════════════════════════════════════

  /// تهيئة الاتصال — تُستدعى بعد تسجيل الدخول
  static Future<void> connect() async {
    final userId = AuthService.currentUser?.id;
    if (userId == null) {
      debugPrint('[SOCKET] No user logged in, skipping connection');
      return;
    }

    if (_socket != null && _isConnected && _currentUserId == userId) {
      debugPrint('[SOCKET] Already connected as $userId');
      return;
    }

    _currentUserId = userId;
    final token = await ApiService.getToken();

    // بناء عنوان Socket.IO — استخدام الرابط القابل للتكوين
    final socketUrl = ApiConfig.socketUrl;
    
    debugPrint('[SOCKET] Connecting to $socketUrl...');

    try {
      _socket = IO.io(socketUrl, <String, dynamic>{
        'transports': ['websocket', 'polling'],
        'autoConnect': true,
        'reconnection': true,
        'reconnectionAttempts': 15,
        'reconnectionDelay': 1000,
        'reconnectionDelayMax': 5000,
        'timeout': 10000,
        'auth': token != null ? {'token': token} : null,
        'extraHeaders': token != null ? {'Authorization': 'Bearer $token'} : null,
      });

      _setupListeners();
    } catch (e) {
      debugPrint('[SOCKET] Connection error: $e');
    }
  }

  /// إعداد مستمعي الأحداث
  static void _setupListeners() {
    _socket?.on('connect', (_) {
      _isConnected = true;
      _connectionController.add(true);
      debugPrint('[SOCKET] Connected');

      // إرسال حالة الاتصال
      if (_currentUserId != null) {
        _socket?.emit('user-online', {'userId': _currentUserId});
      }
    });

    _socket?.on('disconnect', (_) {
      _isConnected = false;
      _connectionController.add(false);
      debugPrint('[SOCKET] Disconnected');
    });

    _socket?.on('connect_error', (error) {
      _isConnected = false;
      _connectionController.add(false);
      debugPrint('[SOCKET] Connection error: $error');
    });

    // ══ رسائل المحادثة ═══════════════════════════════════════
    _socket?.on('new-message', (data) {
      if (data is Map<String, dynamic>) {
        _messageController.add(data);
      }
    });

    _socket?.on('chat-updated', (data) {
      if (data is Map<String, dynamic>) {
        _chatUpdatedController.add(data);
      }
    });

    _socket?.on('messages-read', (data) {
      if (data is Map<String, dynamic>) {
        _messagesReadController.add(data);
      }
    });

    _socket?.on('message-read', (data) {
      if (data is Map<String, dynamic>) {
        _messagesReadController.add(data);
      }
    });

    // ══ حالة الكتابة ═══════════════════════════════════════════
    _socket?.on('user-typing', (data) {
      if (data is Map<String, dynamic>) {
        _typingController.add(data);
      }
    });

    _socket?.on('user-stop-typing', (data) {
      if (data is Map<String, dynamic>) {
        _stopTypingController.add(data);
      }
    });

    // ═ـ مكالمات WebRTC ═══════════════════════════════════════
    _socket?.on('incoming-call', (data) {
      if (data is Map<String, dynamic>) {
        _incomingCallController.add(data);
      }
    });

    _socket?.on('call-answered', (data) {
      if (data is Map<String, dynamic>) {
        _callAnsweredController.add(data);
      }
    });

    _socket?.on('call-rejected', (data) {
      if (data is Map<String, dynamic>) {
        _callRejectedController.add(data);
      }
    });

    _socket?.on('call-ended', (data) {
      if (data is Map<String, dynamic>) {
        _callEndedController.add(data);
      }
    });

    _socket?.on('call-failed', (data) {
      debugPrint('[SOCKET] Call failed: $data');
    });

    _socket?.on('call-offer', (data) {
      if (data is Map<String, dynamic>) {
        _callOfferController.add(data);
      }
    });

    _socket?.on('call-answer-sdp', (data) {
      if (data is Map<String, dynamic>) {
        _callAnswerSdpController.add(data);
      }
    });

    _socket?.on('ice-candidate', (data) {
      if (data is Map<String, dynamic>) {
        _iceCandidateController.add(data);
      }
    });
  }

  /// قطع الاتصال — تُستدعى عند تسجيل الخروج
  static void disconnect() {
    if (_currentUserId != null) {
      _socket?.emit('user-offline', {'userId': _currentUserId});
    }
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    _currentUserId = null;
    _connectionController.add(false);
    debugPrint('[SOCKET] Disconnected and cleaned up');
  }

  // ══ أحداث الإرسال (Emitters) ═════════════════════════════

  /// الانضمام لمحادثة
  static void joinChat(String chatId, {String? userId, String? userName}) {
    _socket?.emit('join-chat', {
      'chatId': chatId,
      'userId': userId ?? _currentUserId ?? '',
      'userName': userName ?? '',
    });
  }

  /// مغادرة محادثة
  static void leaveChat(String chatId) {
    _socket?.emit('leave-chat', {'chatId': chatId});
  }

  /// إرسال رسالة (بعد حفظها عبر API)
  static void sendMessage({
    required String chatId,
    required String senderId,
    required String content,
    String messageType = 'text',
  }) {
    _socket?.emit('send-message', {
      'chatId': chatId,
      'senderId': senderId,
      'content': content,
      'messageType': messageType,
    });
  }

  /// تعليم رسائل كمقروءة
  static void markRead(String chatId, {List<int>? messageIds}) {
    _socket?.emit('mark-read', {
      'chatId': chatId,
      'messageIds': messageIds,
    });
  }

  /// إرسال حالة الكتابة
  static void emitTyping(String chatId, {String? userId}) {
    _socket?.emit('typing', {
      'chatId': chatId,
      'userId': userId ?? _currentUserId ?? '',
    });
  }

  /// إيقاف حالة الكتابة
  static void emitStopTyping(String chatId, {String? userId}) {
    _socket?.emit('stop-typing', {
      'chatId': chatId,
      'userId': userId ?? _currentUserId ?? '',
    });
  }

  // ══ أحداث المكالمات ═══════════════════════════════════════

  /// بدء مكالمة
  static void initiateCall({
    required String callId,
    required String callerId,
    required String calleeId,
    String callType = 'audio',
    String? requestId,
  }) {
    _socket?.emit('call-initiate', {
      'callId': callId,
      'callerId': callerId,
      'calleeId': calleeId,
      'callType': callType,
      'requestId': requestId,
    });
  }

  /// الرد على مكالمة
  static void answerCall(String callId) {
    _socket?.emit('call-answer', {'callId': callId});
  }

  /// رفض مكالمة
  static void rejectCall(String callId) {
    _socket?.emit('call-reject', {'callId': callId});
  }

  /// إنهاء مكالمة
  static void endCall(String callId, {String? userId}) {
    _socket?.emit('call-end', {
      'callId': callId,
      'userId': userId ?? _currentUserId ?? '',
    });
  }

  /// إرسال عرض WebRTC SDP
  static void sendOffer(String callId, Map<String, dynamic> offer) {
    _socket?.emit('call-offer', {
      'callId': callId,
      'offer': offer,
    });
  }

  /// إرسال إجابة WebRTC SDP
  static void sendAnswerSdp(String callId, Map<String, dynamic> answer) {
    _socket?.emit('call-answer-sdp', {
      'callId': callId,
      'answer': answer,
    });
  }

  /// إرسال مرشح ICE
  static void sendIceCandidate(String callId, Map<String, dynamic> candidate, {String? senderId}) {
    _socket?.emit('ice-candidate', {
      'callId': callId,
      'candidate': candidate,
      'senderId': senderId ?? _currentUserId ?? '',
    });
  }

  // ══ تنظيف ═══════════════════════════════════════════════════

  /// تحرير الموارد — يُستدعى عند إغلاق التطبيق
  static void dispose() {
    disconnect();
    _messageController.close();
    _chatUpdatedController.close();
    _typingController.close();
    _stopTypingController.close();
    _incomingCallController.close();
    _callAnsweredController.close();
    _callRejectedController.close();
    _callEndedController.close();
    _callOfferController.close();
    _callAnswerSdpController.close();
    _iceCandidateController.close();
    _messagesReadController.close();
    _connectionController.close();
  }
}
