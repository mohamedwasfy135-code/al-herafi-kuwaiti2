import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class RequestInfoCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isClient;
  const RequestInfoCard({super.key, required this.data, required this.isClient});

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, size: 16, color: const Color(0xFF0071E3)),
      const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
      Expanded(child: Text(value, style: const TextStyle(color: Colors.white))),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final d = data;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Column(children: [
            _row(Icons.build,         'الخدمة',  d['service']           ?? '-'),
            _row(Icons.location_city, 'المنطقة', d['clientGovernorate'] ?? '-'),
            _row(Icons.home,          'العنوان', d['address']           ?? '-'),
            if (isClient) ...[
              _row(Icons.person,    'الحرفي',   d['craftsmanName'] ?? '-'),
            ] else ...[
              _row(Icons.person,    'العميل',   d['clientName']    ?? '-'),
              _row(Icons.phone,     'الجوال',   d['clientPhone']   ?? '-'),
            ],
            if (d['proposedAmount'] != null)
              _row(Icons.price_change, 'السعر المُقترح', '${(d['proposedAmount'] as num).toStringAsFixed(3)} د.ك'),
            if (d['agreedAmount'] != null)
              _row(Icons.check_circle, 'المبلغ المتفق عليه', '${(d['agreedAmount'] as num).toStringAsFixed(3)} د.ك'),
            if (d['paymentStatus'] == 'paid')
              _row(Icons.payment, 'حالة الدفع', 'تم الدفع'),
            if (d['finalAmount'] != null)
              _row(Icons.monetization_on, 'المبلغ النهائي', '${(d['finalAmount'] as num).toStringAsFixed(3)} د.ك'),
            if (d['remainingAmount'] != null)
              _row(Icons.money_off, 'المتبقي', '${(d['remainingAmount'] as num).toStringAsFixed(3)} د.ك'),
            if (d['aiPricingRec'] != null)
              _row(Icons.price_check, 'السعر التقديري AI', '${(d['aiPricingRec'] as num).toStringAsFixed(3)} د.ك'),
            if (d['clientRating'] != null)
              _row(Icons.star, 'تقييم الحرفي', '⭐ ${d['clientRating']}'),
            if (d['craftsmanRating'] != null)
              _row(Icons.star_border, 'تقييم العميل', '⭐ ${d['craftsmanRating']}'),
            if ((d['notes'] as String?)?.isNotEmpty == true)
              _row(Icons.notes, 'ملاحظات', d['notes']),
          ]),
        ),
      ),
    );
  }
}