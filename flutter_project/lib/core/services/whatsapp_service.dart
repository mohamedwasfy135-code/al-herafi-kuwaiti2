import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';

class WhatsAppService {
  WhatsAppService._();

  /// فتح محادثة واتساب مع رقم معين
  static Future<bool> sendToNumber({
    required String phone,
    required String message,
  }) async {
    final clean   = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final encoded = Uri.encodeComponent(message);
    final url     = Uri.parse('https://wa.me/$clean?text=$encoded');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// إشعار الكنترول (Admin)
  static Future<void> notifyAdmin(String message) =>
      sendToNumber(phone: kAdminWhatsApp, message: message);
}
