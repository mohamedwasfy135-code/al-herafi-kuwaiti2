import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'openrouter_service.dart';

class AnalyticsInsight {
  final String title, description, type, action;
  const AnalyticsInsight({required this.title, required this.description, required this.type, required this.action});
  factory AnalyticsInsight.fromJson(Map<String, dynamic> j) => AnalyticsInsight(
    title: j['title'] ?? '',
    description: j['description'] ?? '',
    type: j['type'] ?? 'info',
    action: j['action'] ?? '',
  );
}

class AnalyticsReport {
  final Map<String, int> servicesDemand, govDemand;
  final Map<String, double> avgPrices;
  final double avgResponseTime, avgRating;
  final int totalRequests, completedRequests, cancelledRequests;
  final double completionRate;
  final List<AnalyticsInsight> insights;
  final String aiSummary;

  const AnalyticsReport({
    required this.servicesDemand, required this.govDemand, required this.avgPrices,
    required this.avgResponseTime, required this.avgRating, required this.totalRequests,
    required this.completedRequests, required this.cancelledRequests,
    required this.completionRate, required this.insights, required this.aiSummary,
  });
}

class AiAnalyticsService {
  AiAnalyticsService._();

  static Future<Map<String, dynamic>> _collectRawData({DateTime? from, DateTime? to}) async {
    final now = to ?? DateTime.now();
    final start = from ?? now.subtract(const Duration(days: 30));

    // جلب الطلبات من API مع فترة زمنية
    final res = await ApiService.get('/api/requests', queryParameters: {
      'createdAfter': start.toIso8601String(),
      'createdBefore': now.toIso8601String(),
    });

    final List<Map<String, dynamic>> docs = [];
    if (res.success && res.data != null) {
      final raw = res.data!['requests'] ?? res.data!['data'];
      if (raw is List) {
        docs.addAll(raw.cast<Map<String, dynamic>>());
      }
    }

    final servicesDemand = <String, int>{}, govDemand = <String, int>{};
    final pricesByService = <String, List<double>>{};
    final responseTimes = <double>[], ratings = <double>[];
    int completed = 0, cancelled = 0;

    for (final d in docs) {
      final svc = d['service'] as String? ?? 'أخرى';
      final gov = d['clientGovernorate'] as String? ?? 'غير محدد';
      final stat = d['status'] as String? ?? '';

      servicesDemand[svc] = (servicesDemand[svc] ?? 0) + 1;
      govDemand[gov] = (govDemand[gov] ?? 0) + 1;

      if (stat == 'done') completed++;
      if (stat == 'cancelled_by_client' || stat == 'rejected_by_craftsman') cancelled++;

      final amount = (d['finalAmount'] as num?)?.toDouble();
      if (amount != null && amount > 0) {
        pricesByService[svc] = [...(pricesByService[svc] ?? []), amount];
      }

      final rating = (d['clientRating'] as num?)?.toDouble();
      if (rating != null) ratings.add(rating);

      // حساب وقت الاستجابة من createdAt و acceptedAt
      final createdStr = d['createdAt'] as String?;
      final acceptedStr = d['acceptedAt'] as String?;
      if (createdStr != null && acceptedStr != null) {
        try {
          final created = DateTime.parse(createdStr);
          final accepted = DateTime.parse(acceptedStr);
          responseTimes.add(accepted.difference(created).inMinutes.toDouble());
        } catch (_) {}
      }
    }

    final avgPrices = <String, double>{};
    pricesByService.forEach((svc, prices) {
      avgPrices[svc] = prices.reduce((a, b) => a + b) / prices.length;
    });

    final avgRating = ratings.isEmpty ? 0.0 : ratings.reduce((a, b) => a + b) / ratings.length;
    final avgResponse = responseTimes.isEmpty ? 0.0 : responseTimes.reduce((a, b) => a + b) / responseTimes.length;

    return {
      'total': docs.length,
      'completed': completed,
      'cancelled': cancelled,
      'servicesDemand': servicesDemand,
      'govDemand': govDemand,
      'avgPrices': avgPrices,
      'avgRating': avgRating,
      'avgResponseTime': avgResponse,
      'period': '${start.day}/${start.month} - ${now.day}/${now.month}',
    };
  }

  static Future<AnalyticsReport> generateReport({DateTime? from, DateTime? to}) async {
    final raw = await _collectRawData(from: from, to: to);
    final total = raw['total'] as int;
    final completed = raw['completed'] as int;
    final cancelled = raw['cancelled'] as int;
    final servicesDemand = Map<String, int>.from(raw['servicesDemand'] as Map);
    final govDemand = Map<String, int>.from(raw['govDemand'] as Map);
    final avgPrices = (raw['avgPrices'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble()));
    final avgRating = raw['avgRating'] as double;
    final avgResponseTime = raw['avgResponseTime'] as double;

    final top5Services = servicesDemand.entries.toList()..sort((a,b) => b.value.compareTo(a.value));
    final top3Govs = govDemand.entries.toList()..sort((a,b) => b.value.compareTo(a.value));

    final prompt = '''
أنت محلل بيانات خبير لتطبيق خدمات صيانة في الكويت "الحرفي الكويتي".
حلّل هذه البيانات وأعطِ insights قيّمة.

**الفترة:** ${raw['period']}
**إجمالي الطلبات:** $total
**مكتملة:** $completed (${total > 0 ? (completed/total*100).toStringAsFixed(1) : 0}%)
**ملغاة:** $cancelled
**متوسط التقييم:** ${avgRating.toStringAsFixed(1)}/5
**متوسط وقت الاستجابة:** ${avgResponseTime.toStringAsFixed(0)} دقيقة

**أكثر 5 خدمات طلباً:**
${top5Services.take(5).map((e) => '- ${e.key}: ${e.value} طلب').join('\n')}

**أكثر 3 مناطق طلباً:**
${top3Govs.take(3).map((e) => '- ${e.key}: ${e.value} طلب').join('\n')}

**متوسط الأسعار بالدينار:**
${avgPrices.entries.take(5).map((e) => '- ${e.key}: ${e.value.toStringAsFixed(3)} د.ك').join('\n')}

أجب بـ JSON فقط:
{
  "summary": "ملخص تنفيذي 2-3 جمل بالعربية",
  "insights": [
    {
      "title": "عنوان قصير",
      "description": "تفاصيل الملاحظة",
      "type": "warning|success|info|tip",
      "action": "الإجراء المقترح"
    }
  ]
}
    ''';

    List<AnalyticsInsight> insights = [];
    String aiSummary = '';

    try {
      final text = await OpenRouterService.chat(
        messages: [{'role': 'user', 'content': prompt}],
        temperature: 0.4,
        maxTokens: 1024,
      );

      // تحسين: إزالة أي نصوص قبل أو بعد JSON بشكل أكثر أمانًا
      String clean = text.trim();
      // إذا كان الرد يبدأ بنص وليس {، نحاول استخراج أول كائن JSON
      final startIndex = clean.indexOf('{');
      final endIndex = clean.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
        clean = clean.substring(startIndex, endIndex + 1);
      }
      // إزالة أي علامات markdown إذا بقيت
      clean = clean.replaceAll(RegExp(r'```json|```'), '').trim();

      final json = jsonDecode(clean) as Map<String, dynamic>;
      aiSummary = json['summary'] as String? ?? '';
      insights = (json['insights'] as List? ?? [])
          .map((i) => AnalyticsInsight.fromJson(i as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Analytics AI error: $e');
      // لا نترك التطبيق ينهار – نعيد تقريرًا فارغ insights
      aiSummary = '';
      insights = [];
    }

    return AnalyticsReport(
      servicesDemand: servicesDemand,
      govDemand: govDemand,
      avgPrices: avgPrices,
      avgResponseTime: avgResponseTime,
      avgRating: avgRating,
      totalRequests: total,
      completedRequests: completed,
      cancelledRequests: cancelled,
      completionRate: total > 0 ? completed / total * 100 : 0,
      insights: insights,
      aiSummary: aiSummary,
    );
  }
}
