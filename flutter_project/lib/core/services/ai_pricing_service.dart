import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'firestore_service.dart';
import 'openrouter_service.dart';

class PricingResult {
  final double minPrice, maxPrice, recommended;
  final String reasoning, urgencyLevel;
  final List<String> factors;
  const PricingResult({required this.minPrice, required this.maxPrice, required this.recommended, required this.reasoning, required this.urgencyLevel, required this.factors});
  factory PricingResult.fromJson(Map<String, dynamic> j) => PricingResult(
    minPrice: (j['minPrice'] as num?)?.toDouble() ?? 0,
    maxPrice: (j['maxPrice'] as num?)?.toDouble() ?? 0,
    recommended: (j['recommended'] as num?)?.toDouble() ?? 0,
    reasoning: j['reasoning'] as String? ?? '',
    urgencyLevel: j['urgencyLevel'] as String? ?? 'medium',
    factors: List<String>.from(j['factors'] as List? ?? []),
  );
}

class AiPricingService {
  AiPricingService._();

  // ✅ تعقيم المدخلات لمنع Prompt Injection
  static String _sanitize(String input, {int maxLen = 500}) {
    return input
        .replaceAll(RegExp(r'[<>{}\[\]\\]'), '')
        .replaceAll(RegExp(r'(ignore|forget|disregard).{0,30}(instruction|prompt|system)', caseSensitive: false), '')
        .trim()
        .substring(0, input.length > maxLen ? maxLen : input.length);
  }

  static Future<PricingResult?> getPricing({
    required String service,
    required String governorate,
    required String problemDescription,
    String? imageAnalysis,
  }) async {
    try {
      // جمع بيانات السوق — الطلبات المكتملة بنفس الخدمة والمنطقة
      final reqRes = await ApiService.get('/api/requests', queryParameters: {
        'service': service,
        'clientGovernorate': governorate,
        'status': 'done',
        'hasFinalAmount': 'true',
        'limit': '20',
      });

      final List<Map<String, dynamic>> reqDocs = [];
      if (reqRes.success && reqRes.data != null) {
        final raw = reqRes.data!['requests'] ?? reqRes.data!['data'];
        if (raw is List) {
          reqDocs.addAll(raw.cast<Map<String, dynamic>>());
        }
      }

      final amounts = reqDocs
          .map((d) => (d['finalAmount'] as num?)?.toDouble() ?? 0)
          .where((a) => a > 0)
          .toList();

      final avgPrice = amounts.isEmpty ? 0.0 : amounts.reduce((a, b) => a + b) / amounts.length;

      // جلب الحرفيين المتاحين
      final craftDocs = await FirestoreService.getCraftsmen(
        job: service,
        governorate: governorate,
        isAvailable: true,
      );

      // جلب الطلبات النشطة
      final activeRes = await ApiService.get('/api/requests', queryParameters: {
        'service': service,
        'status': 'pending,notified,accepted,in_progress',
      });

      final List<Map<String, dynamic>> activeDocs = [];
      if (activeRes.success && activeRes.data != null) {
        final raw = activeRes.data!['requests'] ?? activeRes.data!['data'];
        if (raw is List) {
          activeDocs.addAll(raw.cast<Map<String, dynamic>>());
        }
      }

      // ✅ تعقيم المدخلات قبل إرسالها للـ AI
      final safeService = _sanitize(service, maxLen: 100);
      final safeGov = _sanitize(governorate, maxLen: 100);
      final safeDesc = _sanitize(problemDescription, maxLen: 400);
      final safeImage = imageAnalysis != null ? _sanitize(imageAnalysis, maxLen: 200) : null;

      // بناء prompt بالمدخلات المعقّمة
      final safePrompt = """
أنت خبير تسعير خدمات الصيانة في الكويت. حلّل البيانات وأعطِ تسعيراً دقيقاً.

الخدمة: $safeService
المنطقة: $safeGov
وصف المشكلة: $safeDesc
${safeImage != null ? 'تحليل الصورة: $safeImage' : ''}

متوسط الأسعار التاريخية: ${avgPrice.toStringAsFixed(3)} دينار
الحرفيون المتاحون: ${craftDocs.length}
الطلبات النشطة: ${activeDocs.length}

أجب بـ JSON فقط بدون أي نص إضافي:
{
  "minPrice": 0.0,
  "maxPrice": 0.0,
  "recommended": 0.0,
  "urgencyLevel": "low|medium|high|emergency",
  "reasoning": "شرح مختصر بالعربية",
  "factors": ["عامل 1", "عامل 2"]
}
""";

      final text = await OpenRouterService.chat(
        messages: [{'role': 'user', 'content': safePrompt}],
        temperature: 0.3,
        maxTokens: 512,
      );

      final clean = text.replaceAll(RegExp(r'```json|```'), '').trim();
      final json = jsonDecode(clean) as Map<String, dynamic>;
      return PricingResult.fromJson(json);
    } catch (e) {
      debugPrint('AiPricingService error: $e');
      return null;
    }
  }

  // تسعير احتياطي
  static Map<String, double> quickEstimate(String service) {
    const prices = <String, (double, double)>{
      'سباك': (5.0, 25.0),
      'كهربائي': (5.0, 30.0),
      'نجار': (8.0, 40.0),
      'بناء ومقاولة': (50.0, 500.0),
      'دهان': (15.0, 150.0),
      'فني تكييف': (8.0, 50.0),
      'نقل أثاث': (20.0, 100.0),
      'صيانة عامة': (5.0, 30.0),
    };
    final p = prices[service] ?? (5.0, 50.0);
    return {
      'min': p.$1,
      'max': p.$2,
      'recommended': (p.$1 + p.$2) / 2,
    };
  }
}
