import 'package:url_launcher/url_launcher.dart';
import '../models/order_model.dart';
class WhatsAppService {
  static const String adminPhone = '01141828276';
  static Future<void> sendOrderToWhatsApp(OrderModel order) async {
    String serviceTypeAr = '';
    switch (order.serviceType) {
      case 'electric': serviceTypeAr = 'كهربائي'; break;
      case 'plumbing': serviceTypeAr = 'سباكة'; break;
      case 'carpentry': serviceTypeAr = 'نجارة'; break;
      case 'dish': serviceTypeAr = 'دش / ستالايت'; break;
    }
    final message = '''*طلب جديد - صنايعي ديروط* 🔧
*رقم الطلب:* ${order.id}
*الخدمة:* $serviceTypeAr
*الاسم:* ${order.customerName}
*الموبايل:* ${order.customerPhone}
*العنوان:* ${order.address}
*المشكلة:* ${order.problemDescription}''';
    final url = 'https://wa.me/$adminPhone?text=${Uri.encodeComponent(message)}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}
