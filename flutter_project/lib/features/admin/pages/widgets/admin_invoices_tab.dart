import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/receipt_service.dart';
import '../../../shared/widgets/paginated_list.dart';

class AdminInvoicesTab extends StatelessWidget {
  const AdminInvoicesTab({super.key});

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try { return DateTime.parse(value); } catch (_) { return null; }
    }
    return null;
  }

  void _openReceipt(String requestId, Map<String, dynamic> d) async {
    await ReceiptService.generateAndShare(
      requestId: requestId,
      clientName: d['clientName'] ?? '',
      craftsmanName: d['assignedCraftsmanName'] ?? d['craftsmanName'] ?? '',
      service: d['service'] ?? '',
      amount: (d['finalAmount'] as num?)?.toDouble() ?? 0.0,
      date: _parseDateTime(d['finishedAt']) ?? DateTime.now(),
      prepaidAmount: (d['prepaidAmount'] as num?)?.toDouble() ?? 0.0,
      remainingAmount: (d['remainingAmount'] as num?)?.toDouble() ?? 0.0,
      description: d['description'] as String?,
      workDetails: d['workDetails'] as String?,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PaginatedApiList(
      fetcher: ({required int page, required int pageSize}) => FirestoreService.getRequests(status: kStatusDone),
      pageSize: 15,
      emptyWidget: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.white.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('no_invoices_yet'.tr(), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
        ]),
      ),
      itemBuilder: (ctx, d, _) {
        final amount = (d['finalAmount'] as num?)?.toDouble() ?? 0.0;
        final requestId = d['id'] as String? ?? '';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0071E3).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_rounded, color: Color(0xFF0071E3), size: 22),
                  ),
                  title: Text(
                    '${d['service'] ?? ''} — ${d['clientName'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.monetization_on_outlined, size: 14, color: Colors.white.withOpacity(0.6)),
                        const SizedBox(width: 4),
                        Text(
                          'total_amount'.tr(args: [amount.toStringAsFixed(3)]),
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  trailing: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0071E3).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF0071E3), size: 20),
                      onPressed: () => _openReceipt(requestId, d),
                      tooltip: 'download_invoice'.tr(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
