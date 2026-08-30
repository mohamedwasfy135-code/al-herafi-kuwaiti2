import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'firestore_service.dart';

/// خدمة بناء البصمة الذكية للحرفي عبر تحليل تقييمات العملاء
class AiCraftsmanProfileService {
  AiCraftsmanProfileService._();

  static const _functionUrl =
      'https://us-central1-sana3i-deroute.cloudfunctions.net/analyzeCraftsmanReviews';

  /// تحليل آخر 20 تقييم نصي للحرفي ثم تخزين الصفات المستخلصة عبر API
  static Future<void> updateCraftsmanProfile(String craftsmanId) async {
    try {
      // 1. جلب آخر 20 تقييم نصي من طلبات مكتملة لهذا الحرفي
      final requests = await FirestoreService.getRequests(
        craftsmanId: craftsmanId,
        status: 'done',
      );

      // ترتيب بالأحدث وأخذ آخر 20
      requests.sort((a, b) {
        final dateA = a['createdAt'] as String? ?? '';
        final dateB = b['createdAt'] as String? ?? '';
        return dateB.compareTo(dateA);
      });
      final recentRequests = requests.take(20).toList();

      final reviews = <String>[];
      for (final data in recentRequests) {
        final notes = data['notes'] as String?;
        if (notes != null && notes.trim().isNotEmpty) {
          reviews.add(notes);
        }
      }

      if (reviews.isEmpty) {
        debugPrint('⏩ لا توجد تقييمات نصية كافية للحرفي $craftsmanId');
        return;
      }

      // 2. الحصول على توكن المصادقة
      final token = await ApiService.getToken();

      // 3. استدعاء Cloud Function عبر HTTP
      final response = await http.post(
        Uri.parse(_functionUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'data': {
            'craftsmanId': craftsmanId,
            'reviews': reviews,
          },
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        debugPrint('✅ تم تحديث بصمة الحرفي $craftsmanId');
      } else {
        debugPrint('❌ updateCraftsmanProfile HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ فشل تحديث بصمة الحرفي: $e');
    }
  }
}
