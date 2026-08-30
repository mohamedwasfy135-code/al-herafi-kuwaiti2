import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/services/firestore_service.dart';

class OrderDetailPage extends StatefulWidget {
  final String orderId;
  final bool isClient;

  const OrderDetailPage({
    super.key,
    required this.orderId,
    this.isClient = true,
  });

  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  Map<String, dynamic>? _orderData;

  @override
  void initState() {
    super.initState();
    _loadOrderData();
  }

  Future<void> _loadOrderData() async {
    final data = await FirestoreService.getRequest(widget.orderId);

    if (data != null && mounted) {
      setState(() {
        _orderData = data;
      });
    }
  }

  Future<void> _openPaymentUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      // إعادة تحميل البيانات بعد 3 ثوانٍ
      Future.delayed(const Duration(seconds: 3), () {
        _loadOrderData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // إعادة تحميل كل 5 ثوانٍ إذا كان الطلب لم يُدفع
    if (_orderData != null && _orderData!['status'] != 'paid') {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _loadOrderData();
      });
    }

    if (_orderData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الطلب'), backgroundColor: const Color(0xFF1D1D1F)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final status = _orderData!['status'] as String? ?? '';
    final paymentUrl = _orderData!['paymentUrl'] as String? ?? '';
    final totalAmount = (_orderData!['totalAmount'] as num?)?.toDouble() ?? 0;
    final products = List<Map<String, dynamic>>.from(_orderData!['products'] ?? []);
    final isPaid = status == 'paid';

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطلب'),
        backgroundColor: const Color(0xFF1D1D1F),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadOrderData,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // حالة الدفع
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isPaid ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isPaid ? Colors.green : Colors.orange, width: 2),
            ),
            child: Column(
              children: [
                Icon(
                  isPaid ? Icons.check_circle : Icons.hourglass_top,
                  color: isPaid ? Colors.green : Colors.orange,
                  size: 60,
                ),
                const SizedBox(height: 12),
                Text(
                  isPaid ? '✅ تم الدفع بنجاح' : '⏳ بانتظار الدفع',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isPaid ? Colors.green : Colors.orange,
                  ),
                ),
                if (!isPaid) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'اسحب للأسفل أو اضغط 🔄 للتحديث',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // المنتجات
          ...products.map((p) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(p['name'] ?? ''),
                  trailing: Text('${p['quantity']} × ${((p['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(3)} د.ك'),
                ),
              )),

          const SizedBox(height: 12),

          // الإجمالي
          Card(
            child: ListTile(
              title: const Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: Text(
                '${totalAmount.toStringAsFixed(3)} د.ك',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0071E3)),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // أزرار الدفع
          if (!isPaid && paymentUrl.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openPaymentUrl(paymentUrl),
                icon: const Icon(Icons.payment),
                label: const Text('💳 الذهاب إلى صفحة الدفع', style: TextStyle(fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0071E3),
                  foregroundColor: const Color(0xFF1D1D1F),
                  minimumSize: const Size.fromHeight(55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (!isPaid)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loadOrderData,
                icon: const Icon(Icons.refresh, color: Color(0xFF0071E3)),
                label: const Text('🔄 تحديث الحالة', style: TextStyle(color: Color(0xFF0071E3), fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(55),
                  side: const BorderSide(color: Color(0xFF0071E3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
