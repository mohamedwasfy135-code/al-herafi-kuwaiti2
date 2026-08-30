import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/myfatoorah_service.dart';

class BusinessSubscriptionTab extends StatefulWidget {
  final String uid;
  const BusinessSubscriptionTab({super.key, required this.uid});

  @override
  State<BusinessSubscriptionTab> createState() => _BusinessSubscriptionTabState();
}

class _BusinessSubscriptionTabState extends State<BusinessSubscriptionTab>
    with AutomaticKeepAliveClientMixin {
  late final _uid = widget.uid;

  @override
  bool get wantKeepAlive => true;

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: const Color(0xFF0071E3), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final _apiKeyCtrl = TextEditingController();

    // نحمّل بيانات الاشتراك مرة واحدة
    return FutureBuilder<ApiResponse>(
      future: ApiService.get('/api/subscriptions', queryParameters: {'businessId': _uid}),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snap.hasData || !snap.data!.success) return const Center(child: CircularProgressIndicator());

        final data = snap.data!.data?['subscription'] as Map<String, dynamic>? ?? {};
        final status = data['subscriptionStatus'] as String? ?? 'none';
        final expiryStr = data['subscriptionExpiry'] as String?;
        DateTime? expiry;
        if (expiryStr != null) {
          try { expiry = DateTime.parse(expiryStr); } catch (_) {}
        }
        final daysLeft = expiry != null
            ? expiry.difference(DateTime.now()).inDays
            : 0;
        final currentApiKey = data['myfatoorahApiKey'] as String? ?? '';
        _apiKeyCtrl.text = currentApiKey;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // حالة الاشتراك
              Icon(
                status == 'approved' ? Icons.check_circle : Icons.card_membership,
                size: 80,
                color: status == 'approved' ? Colors.green : const Color(0xFF0071E3),
              ),
              const SizedBox(height: 20),
              Text(
                status == 'approved' ? 'الاشتراك نشط' : 'الاشتراك غير مفعل',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              if (status == 'approved' && daysLeft > 0) ...[
                const SizedBox(height: 10),
                Text('متبقي $daysLeft يوم', style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ],
              if (status == 'approved' && daysLeft <= 0) ...[
                const SizedBox(height: 10),
                const Text('الاشتراك منتهي', style: TextStyle(fontSize: 13, color: Colors.red)),
              ],
              const SizedBox(height: 20),

              // زر تجديد الاشتراك
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await MyFatoorahService.createPaymentLink(
                    requestId: 'sub_${_uid}_${DateTime.now().millisecondsSinceEpoch}',
                    amount: kSubscriptionPrice,
                    clientName: data['businessName'] ?? '',
                    clientPhone: data['phone'] ?? '',
                    service: 'اشتراك شهري',
                  );
                  if (result != null && result['success'] == true) {
                    await ApiService.put('/api/subscriptions/${_uid}', body: {
                      'subscriptionStatus': 'pending',
                      'subscriptionPrice': kSubscriptionPrice,
                      'lastPaymentUrl': result['paymentURL'],
                    });
                    _snack('✅ تم إنشاء رابط الدفع. انتظر اعتماد الأدمن.');
                  } else {
                    _snack('❌ فشل إنشاء رابط الدفع');
                  }
                },
                icon: const Icon(Icons.payment, color: Color(0xFF1D1D1F)),
                label: Text('تجديد الاشتراك ($kSubscriptionPrice د.ك)', style: const TextStyle(color: Color(0xFF1D1D1F))),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0071E3),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),

              const SizedBox(height: 40),
              const Divider(color: Colors.white30),
              const SizedBox(height: 20),

              // حقل مفتاح ماي فاتورة
              const Row(children: [
                Icon(Icons.vpn_key, color: Color(0xFF0071E3), size: 22),
                SizedBox(width: 10),
                Text('مفتاح ماي فاتورة الخاص بالمحل',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
              ]),
              const SizedBox(height: 8),
              Text('أدخل مفتاح API الخاص بحسابك في ماي فاتورة ليتم استلام المدفوعات مباشرة.',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'sk-or-v1-...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0071E3)),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.save, color: Color(0xFF0071E3)),
                    onPressed: () async {
                      final key = _apiKeyCtrl.text.trim();
                      if (key.isEmpty) {
                        _snack('❌ الرجاء إدخال المفتاح');
                        return;
                      }
                      await ApiService.put('/api/subscriptions/${_uid}', body: {
                        'myfatoorahApiKey': key,
                      });
                      _snack('✅ تم حفظ مفتاح ماي فاتورة');
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}