import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/ai_config.dart';

class GrokService {
  GrokService._();

  static Future<String> chat({
    required List<Map<String, String>> messages,
    double temperature = 0.7,
    int maxTokens = 1024,
  }) async {
    final body = jsonEncode({
      'model': AiConfig.grokModel,
      'messages': messages,
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    final response = await http.post(
      Uri.parse(AiConfig.grokUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AiConfig.grokApiKey}',
      },
      body: body,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices']?[0]?['message']?['content'] ?? '';
    } else {
      throw Exception('Grok API error ${response.statusCode}: ${response.body}');
    }
  }
}