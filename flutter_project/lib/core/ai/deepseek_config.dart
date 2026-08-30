// lib/core/ai/deepseek_config.dart
class DeepSeekConfig {
  static const String apiKey = 'sk-518733d2f3d24c789da0b6964ec086f9'; // ⬅️ استبدل هذا
  static const String chatModel = 'deepseek-chat';
  static const String reasonerModel = 'deepseek-reasoner';
  static const String visionModel = 'deepseek-vl';
  static const String baseUrl = 'https://api.deepseek.com/v1/chat/completions';
  static const int maxTokens = 4096;
  static const double temperature = 0.7;
}