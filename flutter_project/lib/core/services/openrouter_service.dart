import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../constants/ai_config.dart';

class OpenRouterService {
  OpenRouterService._();

  static Future<String> chat({
    required List<Map<String, String>> messages,
    double temperature = 0.7,
    int maxTokens = 1024,
  }) async {
    final apiKey = await AiConfig.getOpenRouterKey();

    if (apiKey.isEmpty) {
      throw Exception('OpenRouter API key is missing. Please set it via Firestore (app_config/api_keys) or --dart-define=OPENROUTER_API_KEY=...');
    }

    final body = jsonEncode({
      'model': AiConfig.openRouterModel,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    http.Response response;
    try {
      response = await http.post(
        Uri.parse(AiConfig.openRouterUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://your-app.com',
          'X-Title': 'Al-Herafi Al-Kuwaiti',
        },
        body: body,
      ).timeout(const Duration(seconds: 30));
    } catch (e) {
      debugPrint('❌ OpenRouter network error: $e');
      throw Exception('تعذر الاتصال بخدمة الذكاء الاصطناعي. تأكد من اتصالك بالإنترنت.');
    }

    // التعامل مع جميع أكواد الحالة
    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        return data['choices']?[0]?['message']?['content'] ?? '';
      } catch (e) {
        debugPrint('❌ OpenRouter JSON parse error: $e\nResponse body: ${response.body}');
        throw Exception('تنسيق الرد غير متوقع من خدمة الذكاء الاصطناعي.');
      }
    } else {
      // محاولة استخراج رسالة خطأ من الجسم إذا كان JSON
      String errorMsg = 'خطأ ${response.statusCode}';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody is Map && errorBody.containsKey('error')) {
          final err = errorBody['error'];
          if (err is Map && err.containsKey('message')) {
            errorMsg = err['message'].toString();
          } else {
            errorMsg = err.toString();
          }
        }
      } catch (_) {
        // الجسم ليس JSON – نعرض جزءًا منه
        errorMsg = response.body.length > 200 ? response.body.substring(0, 200) : response.body;
      }
      debugPrint('❌ OpenRouter error ${response.statusCode}: $errorMsg');
      throw Exception('OpenRouter error $errorMsg');
    }
  }
}