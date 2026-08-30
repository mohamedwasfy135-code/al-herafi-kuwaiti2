// ✅ تم إزالة Firebase — نستخدم FirestoreService + AuthService
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

import '../constants/app_constants.dart';
import 'auth_service.dart';
import 'firestore_service.dart';

class AgreementService {
  AgreementService._();

  /// يقترح الحرفي المُعيَّن مبلغًا — يتحقق من الملكية قبل التحديث
  static Future<void> proposeAmount({
    required String requestId,
    required double amount,
  }) async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) throw Exception('غير مسجل الدخول');

    // ✅ التحقق أن المستخدم هو الحرفي المُعيَّن للطلب
    final doc = await FirestoreService.getRequest(requestId);
    if (doc == null) throw Exception('الطلب غير موجود');
    if (doc['assignedCraftsmanId'] != uid) {
      throw Exception('غير مصرح لك بتحديث هذا الطلب');
    }

    await FirestoreService.updateRequest(requestId, {
      'proposedAmount': amount,
      'proposedAt': DateTime.now().toIso8601String(),
      'status': 'price_proposed',
    });
  }

  /// يوافق العميل على المبلغ — يتحقق أنه صاحب الطلب
  static Future<void> acceptAmount({
    required String requestId,
    required double amount,
  }) async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) throw Exception('غير مسجل الدخول');

    // ✅ التحقق أن المستخدم هو صاحب الطلب
    final doc = await FirestoreService.getRequest(requestId);
    if (doc == null) throw Exception('الطلب غير موجود');
    if (doc['clientId'] != uid) {
      throw Exception('غير مصرح لك بقبول هذا الطلب');
    }

    await FirestoreService.updateRequest(requestId, {
      'status': 'payment_pending',
      'agreedAmount': amount,
    });
  }

  /// يرفض العميل المبلغ — يتحقق أنه صاحب الطلب
  static Future<void> rejectAmount({
    required String requestId,
  }) async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) throw Exception('غير مسجل الدخول');

    // ✅ التحقق أن المستخدم هو صاحب الطلب
    final doc = await FirestoreService.getRequest(requestId);
    if (doc == null) throw Exception('الطلب غير موجود');
    if (doc['clientId'] != uid) {
      throw Exception('غير مصرح لك برفض هذا الطلب');
    }

    await FirestoreService.updateRequest(requestId, {
      'status': kStatusAccepted,
      'proposedAmount': null,
    });
  }
}
