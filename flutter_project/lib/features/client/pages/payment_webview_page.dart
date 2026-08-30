import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:async';

import '../../../../core/services/firestore_service.dart';

class PaymentWebViewPage extends StatefulWidget {
  final String paymentUrl;
  final String orderId;

  const PaymentWebViewPage({
    super.key,
    required this.paymentUrl,
    required this.orderId,
  });

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends State<PaymentWebViewPage> {
  late final WebViewController _controller;
  bool _isPaid = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _startPollingOrderChanges();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onUrlChange: (change) {
            debugPrint('🔗 URL changed: ${change.url}');
            // مراقبة تغيير الرابط للكشف عن نجاح الدفع
            if (change.url?.contains('orderPaid') == true ||
                change.url?.contains('verifyPayment') == true) {
              _checkAndConfirmPayment();
            }
          },
          onNavigationRequest: (request) {
            // السماح بكل الروابط
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  /// الاستماع لتغييرات الطلب عبر polling
  void _startPollingOrderChanges() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      try {
        final data = await FirestoreService.getRequest(widget.orderId);
        if (data == null) return;

        final status = data['status'] as String? ?? '';
        final paymentStatus = data['paymentStatus'] as String? ?? '';

        if ((status == 'paid' || paymentStatus == 'paid') && !_isPaid) {
          timer.cancel();
          setState(() => _isPaid = true);

          // العودة للتطبيق مع رسالة نجاح
          Navigator.of(context).pop(true);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم تأكيد الدفع بنجاح!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } catch (_) {}
    });
  }

  /// التحقق من الدفع وتأكيده
  Future<void> _checkAndConfirmPayment() async {
    try {
      final data = await FirestoreService.getRequest(widget.orderId);

      if (data != null) {
        final status = data['status'] as String? ?? '';

        if (status != 'paid') {
          await FirestoreService.updateRequest(widget.orderId, {
            'status': 'paid',
            'paidAt': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (e) {
      debugPrint('Error confirming payment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('صفحة الدفع'),
        backgroundColor: const Color(0xFF1D1D1F),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, false),
        ),
        actions: [
          if (_isPaid)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('تم الدفع ✓', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isPaid)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(40),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 80),
                          const SizedBox(height: 20),
                          const Text(
                            '✅ تم تأكيد الدفع بنجاح!',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'شكراً لتسوقك من الحرفي الكويتي',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0071E3),
                              foregroundColor: const Color(0xFF1D1D1F),
                              minimumSize: const Size.fromHeight(50),
                            ),
                            child: const Text('العودة للتطبيق', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
