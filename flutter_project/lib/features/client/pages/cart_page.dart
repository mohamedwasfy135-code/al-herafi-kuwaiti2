// cart_page_fixed_v2.dart — النسخة النهائية المُصلحة لسلة المشتريات
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/myfatoorah_service.dart';
import '../../auth/pages/auth_page.dart';
import 'order_detail_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  /// ✅ جلب مفتاح ماي فاتورة الخاص بالمحل
  Future<String?> _getBusinessApiKey(String businessId) async {
    try {
      final data = await FirestoreService.getBusiness(businessId);
      if (data != null) {
        return data['myfatoorahApiKey'] as String?;
      }
    } catch (e) {
      debugPrint('Error fetching business API key: $e');
    }
    return null;
  }

  /// ✅ فتح رابط الدفع في المتصفح
  Future<bool> _launchPaymentUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  Future<void> _checkout() async {
    final cart = context.read<CartProvider>();
    final user = AuthService.currentUser;
    if (user == null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthPage()));
      return;
    }

    final address = _addressCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (address.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال العنوان ورقم الهاتف'), backgroundColor: Colors.red),
      );
      return;
    }

    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السلة فارغة'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final totalAmount = cart.totalPrice;
      final businessId = cart.items.values.first.businessId;

      // ✅ التحقق من المخزون قبل إنشاء الطلب
      for (final item in cart.items.values) {
        try {
          final res = await ApiService.get('/api/products/${item.productId}');
          if (res.success && res.data != null) {
            final productData = res.data!['product'] as Map<String, dynamic>? ?? res.data!;
            final currentStock = (productData['stock'] as num?)?.toInt() ?? 0;
            if (currentStock < item.quantity) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('الكمية المطلوبة من "${item.name}" غير متوفرة (المتوفر: $currentStock)'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return;
            }
          }
        } catch (e) {
          debugPrint('Error checking stock for ${item.productId}: $e');
        }
      }

      final businessApiKey = await _getBusinessApiKey(businessId);

      // ✅ إنشاء الطلب عبر API
      final orderRes = await ApiService.post('/api/orders', body: {
        'clientId': user.id,
        'clientName': user.name,
        'clientPhone': phone,
        'address': address,
        'products': cart.items.values.map((e) => {
          'productId': e.productId,
          'name': e.name,
          'price': e.price,
          'quantity': e.quantity,
        }).toList(),
        'totalAmount': totalAmount,
        'businessId': businessId,
        'status': 'pending_payment',
        'paymentStatus': 'pending',
        'createdAt': DateTime.now().toIso8601String(),
      });

      if (!orderRes.success || orderRes.data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل إنشاء الطلب: ${orderRes.errorMessage}'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final orderId = orderRes.data!['id']?.toString() ?? orderRes.data!['orderId']?.toString() ?? '';

      // ✅ إنشاء رابط الدفع
      final paymentResult = await MyFatoorahService.createPaymentLink(
        requestId: orderId,
        amount: totalAmount,
        clientName: user.name,
        clientPhone: phone,
        service: 'منتجات متعددة',
        businessApiKey: businessApiKey,
      );

      if (paymentResult == null || paymentResult['success'] != true) {
        // حذف الطلب عند فشل إنشاء رابط الدفع
        await ApiService.delete('/api/orders/$orderId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل إنشاء رابط الدفع'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final paymentUrl = paymentResult['paymentURL'];
      final myfatoorahInvoiceId = paymentResult['invoiceId'] as String? ?? '';

      // ✅ تحديث الطلب ببيانات الدفع
      await ApiService.put('/api/orders/$orderId', body: {
        'myfatoorahInvoiceId': myfatoorahInvoiceId,
        'paymentUrl': paymentUrl,
        'paymentStatus': 'link_sent',
      });

      // ✅ تفريغ السلة
      cart.clear();

      if (mounted) {
        // ✅ فتح رابط الدفع في المتصفح
        final launched = await _launchPaymentUrl(paymentUrl);

        if (!launched) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لم يتم فتح صفحة الدفع. حاول مرة أخرى.'), backgroundColor: Colors.red),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم فتح صفحة الدفع. بعد إتمام الدفع، ارجع للتطبيق وسيتم تحديث الحالة تلقائياً.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
            ),
          );

          // ✅ التوجيه إلى صفحة تفاصيل الطلب
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailPage(
                orderId: orderId,
                isClient: true,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('سلة المشتريات'),
        backgroundColor: const Color(0xFF1D1D1F),
      ),
      body: cart.items.isEmpty
          ? const Center(child: Text('السلة فارغة', style: TextStyle(fontSize: 18)))
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (_, i) {
                      final item = cart.items.values.elementAt(i);
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: item.imageUrl != null
                              ? Image.network(item.imageUrl!, width: 50, height: 50, fit: BoxFit.cover)
                              : const Icon(Icons.image),
                          title: Text(item.name),
                          subtitle: Text('${item.price.toStringAsFixed(3)} د.ك'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle),
                                onPressed: () => cart.updateQuantity(item.productId, item.quantity - 1),
                              ),
                              Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.add_circle),
                                onPressed: () => cart.updateQuantity(item.productId, item.quantity + 1),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => cart.removeItem(item.productId),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D1D1F).withOpacity(0.9),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _addressCtrl,
                        decoration: const InputDecoration(
                          labelText: 'عنوان التوصيل',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _loading ? null : _checkout,
                          icon: _loading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Icon(Icons.payment),
                          label: Text('إتمام الشراء (${cart.totalPrice.toStringAsFixed(3)} د.ك)'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0071E3),
                            foregroundColor: const Color(0xFF1D1D1F),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
