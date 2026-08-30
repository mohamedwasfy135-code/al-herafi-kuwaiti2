import 'package:flutter/foundation.dart';

import 'api_service.dart';

class ApiKeyService {
  ApiKeyService._();

  static String? _cachedOpenRouterKey;

  /// جلب مفتاح OpenRouter من الخادم وتخزينه مؤقتاً
  static Future<String?> getOpenRouterKey() async {
    if (_cachedOpenRouterKey != null) {
      return _cachedOpenRouterKey;
    }

    try {
      final res = await ApiService.get('/api/config/api_keys');
      if (res.success && res.data != null) {
        _cachedOpenRouterKey = res.data!['openrouter_key'] as String?;
        return _cachedOpenRouterKey;
      }
    } catch (e) {
      debugPrint('Error fetching API key: $e');
    }
    return null;
  }

  /// حفظ مفتاح OpenRouter عبر API (للأدمن)
  static Future<void> saveOpenRouterKey(String apiKey) async {
    await ApiService.put('/api/config/api_keys', body: {
      'openrouter_key': apiKey,
    });
    _cachedOpenRouterKey = apiKey; // تحديث الذاكرة المؤقتة
  }

  /// مسح المفتاح من الذاكرة المؤقتة (عند تغييره أو تسجيل الخروج)
  static void clearCache() {
    _cachedOpenRouterKey = null;
  }
}
