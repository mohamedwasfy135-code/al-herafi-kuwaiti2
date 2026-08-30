// ✅ تم إزالة Firebase — نستخدم API + Socket.IO
// import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:async';
import 'firestore_service.dart';
import 'api_service.dart';
import 'socket_service.dart';

class CallService {
  CallService._();

  /// إنشاء وثيقة مكالمة جديدة (عرض اتصال)
  static Future<String> createCall({
    required String callerId,
    required String callerName,
    required String receiverId,
    required Map<String, dynamic> offer,
  }) async {
    // ✅ إنشاء المكالمة عبر API
    final res = await ApiService.post('/api/calls', body: {
      'calleeId': receiverId,  // Server expects calleeId
      'callType': 'audio',
    });
    if (res.success && res.data != null) {
      final callId = res.data!['data']?['id'] ?? res.data!['id'] ?? '';

      if (callId.isNotEmpty) {
        // ✅ إرسال إشعار المكالمة عبر Socket.IO
        if (SocketService.isConnected) {
          SocketService.initiateCall(
            callId: callId,
            callerId: callerId,
            calleeId: receiverId,
            callType: 'audio',
          );

          // إرسال SDP Offer عبر Socket.IO
          SocketService.sendOffer(callId, offer);
        }

        return callId;
      }
    }

    // Fallback to FirestoreService
    final callId = await FirestoreService.createCall({
      'callerId': callerId,
      'callerName': callerName,
      'receiverId': receiverId,
      'offer': offer,
      'status': 'ringing',
      'createdAt': DateTime.now().toIso8601String(),
    });
    return callId ?? '';
  }

  /// تحديث الإجابة (answer)
  static Future<void> updateAnswer({
    required String callId,
    required Map<String, dynamic> answer,
  }) async {
    // ✅ تحديث عبر API
    await ApiService.put('/api/calls/$callId', body: {
      'answer': answer,
      'status': 'active',
    });

    // ✅ إرسال عبر Socket.IO
    if (SocketService.isConnected) {
      SocketService.answerCall(callId);
      SocketService.sendAnswerSdp(callId, answer);
    }
  }

  /// إضافة مرشح ICE
  static Future<void> addIceCandidate({
    required String callId,
    required String from,
    required Map<String, dynamic> candidate,
  }) async {
    // ✅ إرسال عبر Socket.IO (فوري)
    if (SocketService.isConnected) {
      SocketService.sendIceCandidate(callId, candidate, senderId: from);
    }

    // ✅ حفظ عبر API كـ fallback
    await ApiService.post('/api/calls/$callId/candidates', body: {
      'from': from,
      'candidate': candidate,
    });
  }

  /// إنهاء المكالمة
  static Future<void> endCall(String callId) async {
    // ✅ إنهاء عبر API
    await ApiService.put('/api/calls/$callId', body: {
      'status': 'ended',
    });

    // ✅ إرسال عبر Socket.IO
    if (SocketService.isConnected) {
      SocketService.endCall(callId);
    }
  }

  /// مستمع للمكالمات الواردة — Socket.IO مع polling كـ fallback
  static Stream<List<Map<String, dynamic>>> incomingCalls(String uid) async* {
    // ✅ Socket.IO: استقبال فوري للمكالمات
    if (SocketService.isConnected) {
      await for (final callData in SocketService.onIncomingCall) {
        yield [callData];
      }
    } else {
      // Fallback: polling كل 3 ثوان
      while (true) {
        await Future.delayed(const Duration(seconds: 3));
        try {
          final res = await ApiService.get('/api/calls', queryParameters: {
            'receiverId': uid,
            'status': 'ringing',
          });
          if (res.success && res.data != null) {
            final calls = res.data!['calls'] ?? res.data!['data'];
            if (calls is List) {
              yield calls.cast<Map<String, dynamic>>();
            }
          }
        } catch (_) {
          yield [];
        }
      }
    }
  }

  /// مستمع لتغييرات وثيقة المكالمة — Socket.IO مع polling كـ fallback
  static Stream<Map<String, dynamic>?> callStream(String callId) async* {
    // ✅ Socket.IO: استماع لأحداث المكالمة
    if (SocketService.isConnected) {
      await for (final event in SocketService.onCallAnswered) {
        if (event['callId'] == callId) {
          // جلب بيانات المكالمة من API
          final res = await ApiService.get('/api/calls/$callId');
          if (res.success && res.data != null) {
            yield res.data!['call'] as Map<String, dynamic>?;
          }
        }
      }
    } else {
      // Fallback: polling كل 2 ثانية
      while (true) {
        await Future.delayed(const Duration(seconds: 2));
        try {
          final res = await ApiService.get('/api/calls/$callId');
          if (res.success && res.data != null) {
            yield res.data!['call'] as Map<String, dynamic>?;
          } else {
            yield null;
          }
        } catch (_) {
          yield null;
        }
      }
    }
  }

  /// مستمع لمرشحات ICE — Socket.IO مع polling كـ fallback
  static Stream<List<Map<String, dynamic>>> candidatesStream(String callId) async* {
    // ✅ Socket.IO: استقبال فوري لمرشحات ICE
    if (SocketService.isConnected) {
      final candidates = <Map<String, dynamic>>[];

      await for (final candidateData in SocketService.onIceCandidate) {
        if (candidateData['callId'] == callId) {
          candidates.add(candidateData);
          yield List.from(candidates);
        }
      }
    } else {
      // Fallback: polling كل ثانية
      while (true) {
        await Future.delayed(const Duration(seconds: 1));
        try {
          final res = await ApiService.get('/api/calls/$callId/candidates');
          if (res.success && res.data != null) {
            final candidates = res.data!['candidates'] ?? res.data!['data'];
            if (candidates is List) {
              yield candidates.cast<Map<String, dynamic>>();
            }
          }
        } catch (_) {
          yield [];
        }
      }
    }
  }

  /// Stream لمكالمة مرفوضة
  static Stream<Map<String, dynamic>> get onCallRejected => SocketService.onCallRejected;

  /// Stream لمكالمة منتهية
  static Stream<Map<String, dynamic>> get onCallEnded => SocketService.onCallEnded;

  /// Stream لعرض WebRTC SDP
  static Stream<Map<String, dynamic>> get onCallOffer => SocketService.onCallOffer;

  /// Stream لإجابة WebRTC SDP
  static Stream<Map<String, dynamic>> get onCallAnswerSdp => SocketService.onCallAnswerSdp;
}
