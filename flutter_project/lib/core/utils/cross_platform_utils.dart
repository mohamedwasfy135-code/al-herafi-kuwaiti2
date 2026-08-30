import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// أدوات متوافقة مع الموبايل والويب
/// بديلة لـ dart:html و dart:js
class CrossPlatformUtils {
  CrossPlatformUtils._();

  /// فتح رابط في المتصفح أو التطبيق الخارجي
  static Future<void> openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// فتح محتوى HTML - حفظ كملف وفتحه
  /// بديل لـ html.Blob + html.Url.createObjectUrlFromBlob + html.window.open
  static Future<void> openHtmlContent(String htmlContent, String filename) async {
    try {
      if (kIsWeb) {
        // على الويب: نسخ المحتوى للحافظة كملاذ أخير
        await copyToClipboard(htmlContent);
        return;
      }
      // على الموبايل: حفظ الملف وفتحه بالمتصفح
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(htmlContent);
      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // fallback: نسخ المحتوى للحافظة
        await copyToClipboard(htmlContent);
      }
    } catch (e) {
      // fallback: نسخ المحتوى للحافظة
      await copyToClipboard(htmlContent);
    }
  }

  /// نسخ نص للحافظة
  /// بديل لـ js.context.callMethod('copyToClipboard', [text])
  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// فتح واتساب مع رسالة
  static Future<void> openWhatsApp(String phone, String message) async {
    final url = 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}';
    await openUrl(url);
  }
}
