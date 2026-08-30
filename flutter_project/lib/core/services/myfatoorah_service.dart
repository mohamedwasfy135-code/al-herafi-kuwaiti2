import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'api_service.dart';

class MyFatoorahService {
  MyFatoorahService._();

  static const _functionUrl =
      'https://us-central1-sana3i-deroute.cloudfunctions.net/createPaymentLinkV2';

  static const _checkPaymentUrl =
      'https://us-central1-sana3i-deroute.cloudfunctions.net/checkPaymentStatus';

  /// ينشئ رابط دفع عبر ماي فاتورة
  /// [businessApiKey] مفتاح ماي فاتورة الخاص بالمحل (اختياري)
  static Future<Map<String, dynamic>?> createPaymentLink({
    required String requestId,
    required double amount,
    required String clientName,
    required String clientPhone,
    required String service,
    String? businessApiKey,
  }) async {
    try {
      final token = await ApiService.getToken();

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final body = <String, dynamic>{
        'requestId': requestId,
        'amount': amount,
        'clientName': clientName,
        'clientPhone': clientPhone,
        'service': service,
      };

      // ✅ إذا كان للمحل مفتاح خاص، نرسله مع الطلب
      if (businessApiKey != null && businessApiKey.isNotEmpty) {
        body['businessApiKey'] = businessApiKey;
      }

      final response = await http.post(
        Uri.parse(_functionUrl),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          return json;
        } else {
          debugPrint('❌ Cloud Function error: ${json['error']}');
          return null;
        }
      } else {
        debugPrint('❌ Cloud Function HTTP ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ MyFatoorahService error: $e');
      return null;
    }
  }

  /// التحقق من حالة الدفع عبر Cloud Function
  static Future<Map<String, dynamic>?> checkPayment({required String requestId}) async {
    try {
      if (AuthService.currentUser == null) return null;
      final token = await ApiService.getToken();

      final response = await http.post(
        Uri.parse(_checkPaymentUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'requestId': requestId,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json;
      } else {
        debugPrint('❌ checkPayment HTTP ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ checkPayment error: $e');
      return null;
    }
  }
}
