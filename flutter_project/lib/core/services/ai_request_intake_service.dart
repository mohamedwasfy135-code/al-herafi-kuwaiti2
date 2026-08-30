import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';

/// نتيجة تحليل وصف الطلب
class RequestIntakeResult {
  final String suggestedService; // مثل "تكييف"
  final String urgency; // "urgent" | "normal" | "low"
  final String? notes; // ملاحظات للفني
  final bool serviceMismatch; // هل الخدمة المقترحة مختلفة عن المختارة؟

  const RequestIntakeResult({
    required this.suggestedService,
    required this.urgency,
    this.notes,
    this.serviceMismatch = false,
  });

  factory RequestIntakeResult.fromJson(Map<String, dynamic> json) {
    return RequestIntakeResult(
      suggestedService: json['suggestedService'] as String? ?? '',
      urgency: json['urgency'] as String? ?? 'normal',
      notes: json['notes'] as String?,
      serviceMismatch: json['serviceMismatch'] as bool? ?? false,
    );
  }
}

/// خدمة تحليل وصف الطلب باستخدام OpenRouter عبر Cloud Function (تعمل على كل المنصات)
class AiRequestIntakeService {
  AiRequestIntakeService._();

  // رابط الـ Cloud Function المنشورة (تأكد من أنه صحيح)
  static const _functionUrl =
      'https://us-central1-sana3i-deroute.cloudfunctions.net/analyzeRequest';

  /// يحلل وصف الطلب ويعيد نتيجة منظمة.
  static Future<RequestIntakeResult?> analyze({
    required String description,
    String? userSelectedService,
  }) async {
    if (description.trim().split(RegExp(r'\s+')).length < 3) {
      debugPrint('⏭️ Request description too short, skipping AI analysis.');
      return null;
    }

    try {
      // الحصول على توكن المصادقة (لتمريره إلى الـ Cloud Function)
      final token = await ApiService.getToken();

      final response = await http.post(
        Uri.parse(_functionUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'data': {
            'description': description,
            'userSelectedService': userSelectedService ?? '',
          },
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        // استجابة callable يكون فيها الحقل "result"
        final data = (json['result'] as Map<String, dynamic>?) ?? json;
        return RequestIntakeResult.fromJson(data);
      } else {
        debugPrint('❌ analyzeRequest HTTP ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ AiRequestIntakeService error: $e');
      return null;
    }
  }
}
