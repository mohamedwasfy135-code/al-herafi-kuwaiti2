import 'package:sana3i_kuwait/core/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';

class BusinessOrdersTab extends StatefulWidget {
  final String uid;
  const BusinessOrdersTab({super.key, required this.uid});

  @override
  State<BusinessOrdersTab> createState() => _BusinessOrdersTabState();
}

class _BusinessOrdersTabState extends State<BusinessOrdersTab> {
  Future<List<Map<String, dynamic>>>? _ordersFuture;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  void _loadOrders() {
    _ordersFuture = _fetchOrders();
    setState(() {});
  }

  Future<List<Map<String, dynamic>>> _fetchOrders() async {
    final res = await ApiService.get('/api/requests', queryParameters: {
      'businessId': widget.uid,
    });

    if (!res.success || res.data == null) return [];

    final list = res.data!['requests'] ?? res.data!['data'] ?? res.data!['orders'] ?? [];
    if (list is! List) return [];

    final orders = <Map<String, dynamic>>[];
    for (final item in list) {
      orders.add(Map<String, dynamic>.from(item as Map));
    }

    // Sort by createdAt descending
    orders.sort((a, b) {
      final aDate = a['createdAt']?.toString() ?? '';
      final bDate = b['createdAt']?.toString() ?? '';
      return bDate.compareTo(aDate);
    });

    return orders;
  }

  Future<void> _confirmPayment(String orderId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد الدفع'),
        content: const Text('هل تأكدت من استلام المبلغ؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('تأكيد'),
          ),
        ],
      )
    );
    if (confirmed != true) return;

    try {
      await ApiService.patch('/api/requests/$orderId', body: {
        'status': 'paid',
        'paidAt': DateTime.now().toIso8601String()
      });
      _loadOrders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _ordersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('خطأ: ${snapshot.error}',
                style: const TextStyle(color: Colors.white))
          );
        }

        final docs = snapshot.data ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 72, color: Colors.white.withOpacity(0.5)),
                const SizedBox(height: 16),
                Text('لا توجد طلبات واردة',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
              ],
            )
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _loadOrders(),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index];
              final orderId = data['id']?.toString() ?? data['_id']?.toString() ?? '';
              final invoiceId = data['invoiceId'] as String? ?? orderId;
              final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
              final status = data['status'] as String? ?? 'pending_payment';
              final createdAtRaw = data['createdAt'];
              final products = (data['products'] as List?) ?? [];
              final clientName = data['clientName'] as String? ?? 'عميل';
              final clientPhone = data['clientPhone'] as String? ?? '';
              final address = data['address'] as String? ?? '';

              final createdAt = createdAtRaw is DateTime
                  ? createdAtRaw
                  : (createdAtRaw is String ? DateTime.tryParse(createdAtRaw) : null);

              final dateStr = createdAt != null
                  ? DateFormat('yyyy/MM/dd - HH:mm').format(createdAt)
                  : '';

              Color statusColor;
              String statusText;

              switch (status) {
                case 'paid':
                case 'payment_confirmed':
                  statusColor = Colors.green;
                  statusText = 'تم الدفع';
                  break;
                case 'pending_payment':
                  statusColor = Colors.orange;
                  statusText = 'بانتظار الدفع';
                  break;
                default:
                  statusColor = Colors.grey;
                  statusText = status;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: ExpansionTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        status == 'paid' ? Icons.check_circle : Icons.pending,
                        color: statusColor,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      'فاتورة #$invoiceId',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${totalAmount.toStringAsFixed(3)} د.ك',
                            style: const TextStyle(color: Color(0xFF0071E3), fontWeight: FontWeight.bold)),
                        if (dateStr.isNotEmpty)
                          Text(dateStr, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(statusText,
                          style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 11)),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // معلومات العميل كاملة
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0071E3).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF0071E3).withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(children: [
                                    Icon(Icons.person, size: 14, color: Color(0xFF0071E3)),
                                    SizedBox(width: 8),
                                    Text('معلومات العميل',
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0071E3), fontSize: 14)),
                                  ]),
                                  const SizedBox(height: 10),
                                  _clientInfoRow(Icons.person_outline, 'الاسم', clientName),
                                  if (clientPhone.isNotEmpty)
                                    _clientInfoRow(Icons.phone_android, 'رقم الهاتف', clientPhone),
                                  if (address.isNotEmpty)
                                    _clientInfoRow(Icons.location_on, 'عنوان التوصيل', address),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            const Text('المنتجات:',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 12)),
                            const SizedBox(height: 8),
                            ...products.map((p) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text('${p['name']} x${p['quantity']}',
                                            style: const TextStyle(color: Colors.white, fontSize: 13)),
                                      ),
                                      Text('${((p['price'] as num).toDouble() * (p['quantity'] as num).toInt()).toStringAsFixed(3)} د.ك',
                                          style: const TextStyle(color: Color(0xFF0071E3), fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                )),

                            const SizedBox(height: 8),
                            const Divider(color: Colors.white30),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'الإجمالي: ${totalAmount.toStringAsFixed(3)} د.ك',
                                style: const TextStyle(
                                  color: Color(0xFF0071E3),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),

                            // زر تأكيد الدفع
                            if (status != 'paid')
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _confirmPayment(orderId),
                                    icon: const Icon(Icons.check_circle),
                                    label: const Text('تأكيد استلام الدفع'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              );
            }
          ),
        );
      }
    );
  }

  // ويدجت صف معلومات العميل
  Widget _clientInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white70),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text('$label:',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      )
    );
  }
}
