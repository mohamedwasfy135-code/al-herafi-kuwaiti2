import '../services/api_key_service.dart';

class AiConfig {
  AiConfig._();

  static const String openRouterModel = 'google/gemini-2.0-flash-001';
  static const String openRouterUrl = 'https://openrouter.ai/api/v1/chat/completions';

  /// جلب المفتاح من Firestore (أو dart-define كبديل)
  static Future<String> getOpenRouterKey() async {
    final storedKey = await ApiKeyService.getOpenRouterKey();
    if (storedKey != null && storedKey.isNotEmpty) {
      return storedKey;
    }
    // بديل: dart-define (في حال أردت تشغيل مؤقت)
    return const String.fromEnvironment('OPENROUTER_API_KEY', defaultValue: '');
  }
}