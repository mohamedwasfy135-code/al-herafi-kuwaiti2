import '../../../../core/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';

class InvoicePrintPage extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;
  final String businessName;

  const InvoicePrintPage({
    super.key,
    required this.orderId,
    required this.orderData,
    required this.businessName,
  });

  @override
  Widget build(BuildContext context) {
    final invoiceId = orderData['invoiceId'] as String? ?? orderId;
    final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0;
    final createdAtRaw = orderData['createdAt'];
    DateTime? createdAt;
    if (createdAtRaw is String) {
      try { createdAt = DateTime.parse(createdAtRaw); } catch (_) {}
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    }
    final products = List<Map<String, dynamic>>.from(orderData['products'] ?? []);
    final clientName = orderData['clientName'] as String? ?? 'عميل';
    final clientPhone = orderData['clientPhone'] as String? ?? '';
    final address = orderData['address'] as String? ?? '';
    final paymentMethod = 'ماي فاتورة';
    final paidAtRaw = orderData['paidAt'];
    DateTime? paidAt;
    if (paidAtRaw is String) {
      try { paidAt = DateTime.parse(paidAtRaw); } catch (_) {}
    } else if (paidAtRaw is DateTime) {
      paidAt = paidAtRaw;
    }

    final dateStr = createdAt != null
        ? DateFormat('yyyy/MM/dd - HH:mm').format(createdAt)
        : '';
    final paidDateStr = paidAt != null
        ? DateFormat('yyyy/MM/dd - HH:mm').format(paidAt)
        : '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('فاتورة شراء', style: TextStyle(color: Color(0xFF1D1D1F))),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1D1D1F),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Color(0xFF1D1D1F)),
            tooltip: 'طباعة',
            onPressed: () {
              // يمكن إضافة وظيفة الطباعة الفعلية هنا
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('استخدم أمر الطباعة في المتصفح (Ctrl+P)')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ رأس الفاتورة
            Center(
              child: Column(
                children: [
                  const Icon(Icons.handyman, size: 48, color: Color(0xFF0071E3)),
                  const SizedBox(height: 8),
                  const Text(
                    'الحرفي الكويتي',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1D1D1F),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'فاتورة شراء رسمية',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: Color(0xFF0071E3), thickness: 2),

            // ✅ معلومات الفاتورة
            _buildInfoSection('معلومات الفاتورة', [
              _buildInfoRow('رقم الفاتورة', invoiceId),
              _buildInfoRow('التاريخ', dateStr),
              _buildInfoRow('حالة الدفع', 'تم الدفع ✓'),
              _buildInfoRow('تاريخ الدفع', paidDateStr),
              _buildInfoRow('طريقة الدفع', paymentMethod),
            ]),

            const SizedBox(height: 16),

            // ✅ معلومات المحل
            _buildInfoSection('معلومات المحل', [
              _buildInfoRow('اسم المحل', businessName),
            ]),

            const SizedBox(height: 16),

            // ✅ معلومات العميل
            _buildInfoSection('معلومات العميل', [
              _buildInfoRow('الاسم', clientName),
              _buildInfoRow('رقم الهاتف', clientPhone),
              _buildInfoRow('عنوان التوصيل', address),
            ]),

            const SizedBox(height: 24),
            const Divider(color: Color(0xFF0071E3), thickness: 2),
            const SizedBox(height: 16),

            // ✅ المنتجات
            const Text(
              'المنتجات',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1D1D1F),
              ),
            ),
            const SizedBox(height: 12),

            // رأس الجدول
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0071E3).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('المنتج', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D1D1F)))),
                  Expanded(child: Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D1D1F)), textAlign: TextAlign.center)),
                  Expanded(child: Text('السعر', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D1D1F)), textAlign: TextAlign.center)),
                  Expanded(child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D1D1F)), textAlign: TextAlign.end)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            ...products.map((p) {
              final price = (p['price'] as num?)?.toDouble() ?? 0;
              final quantity = (p['quantity'] as num?)?.toInt() ?? 1;
              final itemTotal = price * quantity;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(p['name'] ?? '', style: const TextStyle(color: Color(0xFF1D1D1F)))),
                    Expanded(child: Text('$quantity', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF1D1D1F)))),
                    Expanded(child: Text('${price.toStringAsFixed(3)} د.ك', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF1D1D1F)))),
                    Expanded(child: Text('${itemTotal.toStringAsFixed(3)} د.ك', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D1D1F)))),
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),
            const Divider(color: Colors.grey),
            const SizedBox(height: 8),

            // ✅ الإجمالي
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0071E3).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0071E3), width: 2),
                ),
                child: Text(
                  'الإجمالي: ${totalAmount.toStringAsFixed(3)} د.ك',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1D1D1F),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // ✅ تذييل
            Center(
              child: Column(
                children: [
                  const Icon(Icons.verified, color: Color(0xFF0071E3), size: 32),
                  const SizedBox(height: 8),
                  const Text(
                    'شكراً لتسوقك من الحرفي الكويتي',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'هذه فاتورة رسمية صادرة من منصة الحرفي الكويتي',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1D1D1F),
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: Color(0xFF1D1D1F),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}