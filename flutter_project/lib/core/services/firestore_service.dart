// ═══════════════════════════════════════════════════════════════════
// خدمة Firestore البديلة — تستخدم Next.js API بدل Cloud Firestore
// الحرفي الكويتي — تحويل من Firebase إلى PostgreSQL/Prisma
// ═══════════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'auth_service.dart';

/// خدمة قاعدة البيانات — بديل FirebaseFirestore.instance
/// تحوّل جميع عمليات Firestore إلى طلبات HTTP للخادم Next.js
class FirestoreService {
  FirestoreService._();

  // ══ المستخدمون (users) ═══════════════════════════════════════════

  /// جلب بيانات مستخدم
  static Future<Map<String, dynamic>?> getUser(String uid) async {
    final res = await ApiService.get('/api/users/$uid');
    return res.success ? (res.data?['user'] as Map<String, dynamic>?) : null;
  }

  /// تحديث بيانات مستخدم
  static Future<bool> updateUser(String uid, Map<String, dynamic> data) async {
    final res = await ApiService.put('/api/users/$uid', body: data);
    return res.success;
  }

  /// جلب قائمة الحرفيين
  static Future<List<Map<String, dynamic>>> getCraftsmen({
    String? job,
    String? governorate,
    bool? isAvailable,
  }) async {
    final params = <String, dynamic>{
      'role': 'craftsman',
      if (job != null) 'job': job,
      if (governorate != null) 'governorate': governorate,
      if (isAvailable != null) 'isAvailable': isAvailable,
    };
    final res = await ApiService.get('/api/users', queryParameters: params);
    if (res.success && res.data != null) {
      final users = res.data!['users'] as List<dynamic>?;
      return users?.cast<Map<String, dynamic>>() ?? [];
    }
    return [];
  }

  // ══ الطلبات (requests) ═══════════════════════════════════════════

  /// جلب طلب بالمعرف
  static Future<Map<String, dynamic>?> getRequest(String requestId) async {
    final res = await ApiService.get('/api/requests/$requestId');
    return res.success ? (res.data?['request'] as Map<String, dynamic>?) : null;
  }

  /// جلب قائمة الطلبات
  static Future<List<Map<String, dynamic>>> getRequests({
    String? clientId,
    String? craftsmanId,
    String? businessId,
    String? status,
  }) async {
    final params = <String, dynamic>{
      if (clientId != null) 'clientId': clientId,
      if (craftsmanId != null) 'craftsmanId': craftsmanId,
      if (businessId != null) 'businessId': businessId,
      if (status != null) 'status': status,
    };
    final res = await ApiService.get('/api/requests', queryParameters: params);
    if (res.success && res.data != null) {
      final requests = res.data!['requests'] ?? res.data!['data'];
      if (requests is List) {
        return requests.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  /// إنشاء طلب جديد
  static Future<Map<String, dynamic>?> createRequest(
    Map<String, dynamic> data,
  ) async {
    final res = await ApiService.post('/api/requests/create', body: data);
    return res.success ? res.data : null;
  }

  /// تحديث طلب
  static Future<bool> updateRequest(
    String requestId,
    Map<String, dynamic> data,
  ) async {
    final res = await ApiService.put('/api/requests/$requestId', body: data);
    return res.success;
  }

  // ═ـ المحادثات (chats) ═══════════════════════════════════════════

  /// جلب أو إنشاء محادثة
  static Future<String> getOrCreateChat(String otherUserId) async {
    final res = await ApiService.post('/api/chats', body: {
      'otherUserId': otherUserId,
    });
    if (res.success && res.data != null) {
      return res.data!['chatId'] as String? ??
             res.data!['data']?['id'] as String? ??
             res.data!['id'] as String? ?? '';
    }
    return '';
  }

  /// جلب محادثات المستخدم
  static Future<List<Map<String, dynamic>>> getChats() async {
    final res = await ApiService.get('/api/chats');
    if (res.success && res.data != null) {
      final chats = res.data!['chats'] ?? res.data!['data'];
      if (chats is List) {
        return chats.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  /// إرسال رسالة
  static Future<bool> sendMessage({
    required String chatId,
    required String content,
    String messageType = 'text',
    String? attachmentUrl,
  }) async {
    final res = await ApiService.post('/api/chats/$chatId/messages', body: {
      'content': content,
      'messageType': messageType,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
    });
    return res.success;
  }

  /// جلب رسائل محادثة
  static Future<List<Map<String, dynamic>>> getMessages(String chatId) async {
    final res = await ApiService.get('/api/chats/$chatId/messages');
    if (res.success && res.data != null) {
      final messages = res.data!['messages'] ?? res.data!['data'];
      if (messages is List) {
        return messages.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  // ══ الإشعارات (notifications) ═════════════════════════════════════

  /// جلب إشعارات المستخدم
  static Future<List<Map<String, dynamic>>> getNotifications(String uid) async {
    final res = await ApiService.get('/api/notifications/user/$uid');
    if (res.success && res.data != null) {
      final notifs = res.data!['notifications'] ?? res.data!['data'];
      if (notifs is List) {
        return notifs.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  /// إرسال إشعار
  static Future<bool> sendNotification({
    required String toUid,
    required String title,
    required String body,
    String type = 'general',
    Map<String, dynamic>? data,
  }) async {
    final res = await ApiService.post('/api/notifications', body: {
      'userId': toUid,
      'title': title,
      'body': body,
      'type': type,
      if (data != null) 'referenceType': data['type'],
      if (data != null) 'referenceId': data['id'],
    });
    return res.success;
  }

  /// تعليم إشعار كمقروء
  static Future<bool> markNotificationRead(String notificationId) async {
    final res = await ApiService.put('/api/notifications/$notificationId', body: {
      'isRead': true,
    });
    return res.success;
  }

  // ══ المكالمات (calls) ═══════════════════════════════════════════

  /// إنشاء مكالمة
  static Future<String?> createCall(Map<String, dynamic> data) async {
    final res = await ApiService.post('/api/calls', body: data);
    if (res.success && res.data != null) {
      // Server returns { data: { id: ... } } — extract the call ID
      return res.data!['data']?['id'] as String? ?? res.data!['id'] as String?;
    }
    return null;
  }

  /// تحديث مكالمة
  static Future<bool> updateCall(String callId, Map<String, dynamic> data) async {
    final res = await ApiService.put('/api/calls/$callId', body: data);
    return res.success;
  }

  // ══ الأعمال/المحلات (businesses) ═════════════════════════════════

  /// جلب بيانات محل
  static Future<Map<String, dynamic>?> getBusiness(String businessId) async {
    final res = await ApiService.get('/api/business/$businessId');
    if (res.success && res.data != null) {
      // Server returns flat { ...business, summary } — return the whole object
      return res.data?['business'] as Map<String, dynamic>? ?? res.data;
    }
    return null;
  }

  /// تحديث بيانات محل
  static Future<bool> updateBusiness(
    String businessId,
    Map<String, dynamic> data,
  ) async {
    final res = await ApiService.put('/api/business/$businessId', body: data);
    return res.success;
  }

  // ══ المنتجات (products) ═══════════════════════════════════════════

  /// جلب منتجات محل
  static Future<List<Map<String, dynamic>>> getProducts({
    String? businessId,
    String? category,
  }) async {
    final params = <String, dynamic>{
      if (businessId != null) 'businessId': businessId,
      if (category != null) 'category': category,
    };
    final res = await ApiService.get('/api/products', queryParameters: params);
    if (res.success && res.data != null) {
      final products = res.data!['products'] ?? res.data!['data'];
      if (products is List) {
        return products.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  /// إنشاء/تحديث منتج
  static Future<Map<String, dynamic>?> saveProduct(
    Map<String, dynamic> data, {
    int? productId,
  }) async {
    final res = productId != null
        ? await ApiService.put('/api/products/$productId', body: data)
        : await ApiService.post('/api/products', body: data);
    return res.success ? res.data : null;
  }

  // ══ عروض الأسعار (price offers) ═════════════════════════════════

  /// جلب عروض أسعار طلب
  static Future<List<Map<String, dynamic>>> getPriceOffers(
    String requestId,
  ) async {
    final res = await ApiService.get('/api/price-quotes', queryParameters: {
      'requestId': requestId,
    });
    if (res.success && res.data != null) {
      final offers = res.data!['priceQuotes'] ?? res.data!['data'];
      if (offers is List) {
        return offers.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  /// إنشاء عرض سعر
  static Future<bool> createPriceOffer(Map<String, dynamic> data) async {
    final res = await ApiService.post('/api/price-quotes', body: data);
    return res.success;
  }

  // ═ـ الأرباح (earnings) ═══════════════════════════════════════════

  /// جلب أرباح حرفي
  static Future<List<Map<String, dynamic>>> getEarnings({
    String? craftsmanId,
    String? status,
  }) async {
    final params = <String, dynamic>{
      if (craftsmanId != null) 'craftsmanId': craftsmanId,
      if (status != null) 'status': status,
    };
    final res = await ApiService.get('/api/earnings', queryParameters: params);
    if (res.success && res.data != null) {
      final earnings = res.data!['earnings'] ?? res.data!['data'];
      if (earnings is List) {
        return earnings.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  // ══ طلبات الدفع (payout requests) ═══════════════════════════════

  /// إنشاء طلب دفع
  static Future<bool> createPayoutRequest(Map<String, dynamic> data) async {
    final res = await ApiService.post('/api/payouts', body: data);
    return res.success;
  }

  // ══ المراجعات (reviews) ═══════════════════════════════════════════

  /// جلب مراجعات حرفي
  static Future<List<Map<String, dynamic>>> getReviews({
    String? craftsmanId,
    String? businessId,
  }) async {
    final params = <String, dynamic>{
      if (craftsmanId != null) 'craftsmanId': craftsmanId,
      if (businessId != null) 'businessId': businessId,
    };
    final res = await ApiService.get('/api/reviews', queryParameters: params);
    if (res.success && res.data != null) {
      final reviews = res.data!['reviews'] ?? res.data!['data'];
      if (reviews is List) {
        return reviews.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  /// إنشاء مراجعة
  static Future<bool> createReview(Map<String, dynamic> data) async {
    final res = await ApiService.post('/api/reviews', body: data);
    return res.success;
  }

  // ══ طلبات التحقق (verification) ═════════════════════════════════

  /// رفع وثائق التحقق
  static Future<bool> uploadVerificationDocs(Map<String, dynamic> data) async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return false;
    final res = await ApiService.put('/api/users/$uid', body: {
      'verificationStatus': 'submitted',
      ...data,
    });
    return res.success;
  }

  // ══ الفواتير والمعاملات ═══════════════════════════════════════════

  /// جلب فواتير البيع
  static Future<List<Map<String, dynamic>>> getSalesInvoices({
    String? businessId,
  }) async {
    final params = <String, dynamic>{
      if (businessId != null) 'businessId': businessId,
    };
    final res = await ApiService.get('/api/invoices/sales', queryParameters: params);
    if (res.success && res.data != null) {
      final invoices = res.data!['invoices'] ?? res.data!['data'];
      if (invoices is List) {
        return invoices.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  /// جلب فواتير الشراء
  static Future<List<Map<String, dynamic>>> getPurchaseInvoices({
    String? businessId,
  }) async {
    final params = <String, dynamic>{
      if (businessId != null) 'businessId': businessId,
    };
    final res = await ApiService.get('/api/invoices/purchase', queryParameters: params);
    if (res.success && res.data != null) {
      final invoices = res.data!['invoices'] ?? res.data!['data'];
      if (invoices is List) {
        return invoices.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  /// جلب السندات
  static Future<List<Map<String, dynamic>>> getBonds({
    String? businessId,
  }) async {
    final params = <String, dynamic>{
      if (businessId != null) 'businessId': businessId,
    };
    final res = await ApiService.get('/api/bonds', queryParameters: params);
    if (res.success && res.data != null) {
      final bonds = res.data!['bonds'] ?? res.data!['data'];
      if (bonds is List) {
        return bonds.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  /// جلب الحسابات
  static Future<List<Map<String, dynamic>>> getAccounts({
    String? businessId,
  }) async {
    final params = <String, dynamic>{
      if (businessId != null) 'businessId': businessId,
    };
    final res = await ApiService.get('/api/accounts', queryParameters: params);
    if (res.success && res.data != null) {
      final accounts = res.data!['accounts'] ?? res.data!['data'];
      if (accounts is List) {
        return accounts.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  // ══ طلبات الضيوف (guest requests) ═══════════════════════════════

  /// إنشاء طلب ضيف
  static Future<Map<String, dynamic>?> createGuestRequest(
    Map<String, dynamic> data,
  ) async {
    final res = await ApiService.post('/api/requests/create', body: data);
    return res.success ? res.data : null;
  }

  // ══ إحصائيات لوحة التحكم ═══════════════════════════════════════════

  /// جلب إحصائيات لوحة التحكم
  static Future<Map<String, dynamic>?> getDashboardStats({
    String? businessId,
  }) async {
    final params = <String, dynamic>{
      if (businessId != null) 'businessId': businessId,
    };
    final res = await ApiService.get('/api/dashboard', queryParameters: params);
    return res.success ? res.data : null;
  }
}
