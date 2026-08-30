// core/services/openrouter_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/ai_config.dart';

class OpenRouterService {
  OpenRouterService._();

  /// إرسال محادثة إلى OpenRouter واستلام الرد النصي
  static Future<String> chat({
    required List<Map<String, String>> messages, // مثلاً [{"role": "user", "content": "..."}]
    String model = AiConfig.openRouterModel,
    double temperature = 0.7,
    int maxTokens = 1024,
  }) async {
    final body = jsonEncode({
      'model': model,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    final response = await http.post(
      Uri.parse(AiConfig.openRouterUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AiConfig.openRouterKey}',
        'HTTP-Referer': 'https://your-app.com',  // عرّف تطبيقك
        'X-Title': 'الحرفي الكويتي',
      },
      body: body,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices']?[0]?['message']?['content'] ?? '';
    } else {
      throw Exception('OpenRouter error ${response.statusCode}: ${response.body}');
    }
  }
}
