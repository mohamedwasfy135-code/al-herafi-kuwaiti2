import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../order_detail_page.dart';
import '../invoice_print_page.dart';

class ClientOrdersTab extends StatelessWidget {
  final String uid;
  const ClientOrdersTab({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    return _ClientOrdersContent(uid: uid);
  }
}

class _ClientOrdersContent extends StatefulWidget {
  final String uid;
  const _ClientOrdersContent({required this.uid});

  @override
  State<_ClientOrdersContent> createState() => _ClientOrdersContentState();
}

class _ClientOrdersContentState extends State<_ClientOrdersContent> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.get('/api/orders', queryParameters: {'clientId': widget.uid});
      if (res.success && res.data != null) {
        final list = res.data!['orders'] ?? res.data!['data'];
        if (list is List) {
          setState(() { _orders = list.cast<Map<String, dynamic>>(); _loading = false; });
        } else {
          setState(() { _orders = []; _loading = false; });
        }
      } else {
        setState(() { _error = res.error ?? 'خطأ في التحميل'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  DateTime? _parseDate(dynamic val) {
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));
    }

    if (_error != null) {
      return Center(
        child: Text('خطأ: $_error', style: const TextStyle(color: Colors.white)),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 72, color: Colors.white.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('لا توجد مشتريات من المحلات',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      color: const Color(0xFF0071E3),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final data = _orders[index];
          final orderId = data['id']?.toString() ?? '';
          final invoiceId = data['invoiceId'] as String? ?? orderId;
          final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0;
          final status = data['status'] as String? ?? 'pending_payment';
          final createdAt = _parseDate(data['createdAt']);
          final businessId = data['businessId'] as String? ?? '';

          final dateStr = createdAt != null
              ? DateFormat('yyyy/MM/dd - HH:mm').format(createdAt)
              : '';

          Color statusColor;
          String statusText;
          IconData statusIcon;

          switch (status) {
            case 'paid':
            case 'payment_confirmed':
              statusColor = Colors.green;
              statusText = 'تم الدفع';
              statusIcon = Icons.check_circle;
              break;
            case 'pending_payment':
              statusColor = Colors.orange;
              statusText = 'بانتظار الدفع';
              statusIcon = Icons.hourglass_top;
              break;
            default:
              statusColor = Colors.grey;
              statusText = status;
              statusIcon = Icons.info;
          }

          return FutureBuilder<Map<String, dynamic>?>(
            future: _loadBusinessName(businessId),
            builder: (_, bizSnap) {
              final bizName = bizSnap.data?['businessName'] as String? ?? 'محل';

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailPage(
                          orderId: orderId,
                          isClient: true,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(statusIcon, color: statusColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('فاتورة #$invoiceId',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white)),
                              Text(bizName,
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                              Text('${totalAmount.toStringAsFixed(3)} د.ك',
                                  style: const TextStyle(color: Color(0xFF0071E3), fontWeight: FontWeight.bold)),
                              if (dateStr.isNotEmpty)
                                Text(dateStr, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                            ],
                          ),
                        ),
                        if (status == 'paid')
                          IconButton(
                            icon: const Icon(Icons.print, color: Colors.white70, size: 20),
                            tooltip: 'طباعة الفاتورة',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InvoicePrintPage(
                                    orderId: orderId,
                                    orderData: data,
                                    businessName: bizName,
                                  ),
                                ),
                              );
                            },
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(statusText,
                              style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 11)),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white30),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>?> _loadBusinessName(String businessId) async {
    if (businessId.isEmpty) return null;
    final res = await ApiService.get('/api/business/$businessId');
    return res.success ? (res.data?['business'] as Map<String, dynamic>?) : null;
  }
}
