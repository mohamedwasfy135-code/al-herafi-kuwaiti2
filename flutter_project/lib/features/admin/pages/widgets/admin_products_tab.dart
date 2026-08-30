import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../shared/widgets/paginated_list.dart';

class AdminProductsTab extends StatelessWidget {
  const AdminProductsTab({super.key});

  void _snack(BuildContext context, String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return PaginatedApiList(
      fetcher: ({required int page, required int pageSize}) => FirestoreService.getProducts(),
      pageSize: 20,
      emptyWidget: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('no_products_yet'.tr(), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
        ]),
      ),
      itemBuilder: (ctx, d, _) {
        final status = d['status'] as String? ?? 'pending';
        final isApproved = status == 'approved';
        final isRejected = status == 'rejected';
        final businessId = d['businessId'] as String? ?? '';
        final docId = d['id'] as String? ?? '';

        Color statusColor;
        IconData statusIcon;
        String statusLabel;
        if (isApproved) {
          statusColor = Colors.green;
          statusIcon = Icons.check_circle_rounded;
          statusLabel = 'approved_label'.tr();
        } else if (isRejected) {
          statusColor = Colors.red;
          statusIcon = Icons.cancel_rounded;
          statusLabel = 'rejected_label'.tr();
        } else {
          statusColor = Colors.orange;
          statusIcon = Icons.hourglass_empty_rounded;
          statusLabel = 'pending_label'.tr();
        }

        // ✅ جلب اسم المحل
        return FutureBuilder<Map<String, dynamic>?>(
          future: FirestoreService.getBusiness(businessId),
          builder: (_, bizSnap) {
            final bizName = bizSnap.data != null
                ? (bizSnap.data!['businessName'] as String? ?? 'محل غير معروف')
                : 'محل غير معروف';

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
                        child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF0071E3), size: 22),
                      ),
                      title: Text(
                        d['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ✅ اسم المحل
                            Row(
                              children: [
                                Icon(Icons.store, size: 14, color: const Color(0xFF0071E3).withOpacity(0.7)),
                                const SizedBox(width: 4),
                                Text(
                                  bizName,
                                  style: TextStyle(color: const Color(0xFF0071E3).withOpacity(0.7), fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.monetization_on_outlined, size: 14, color: Colors.white.withOpacity(0.6)),
                                const SizedBox(width: 4),
                                Text(
                                  '${(d['originalPrice'] as num?)?.toStringAsFixed(3) ?? (d['price'] as num?)?.toStringAsFixed(3) ?? '?'} ${'kwd_currency'.tr()}',
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                                if (d['description'] != null && (d['description'] as String).isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  Flexible(
                                    child: Text(
                                      d['description'] ?? '',
                                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: statusColor.withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon, size: 14, color: statusColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    statusLabel,
                                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert_rounded, size: 14, color: Colors.white.withOpacity(0.7)),
                          color: const Color(0xFF1E2A3A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onSelected: (v) async {
                            if (v == 'approve') {
                              await ApiService.put('/api/products/$docId', body: {'status': 'approved'});
                              _snack(context, '✅ ${'approved_label'.tr()}');
                            } else if (v == 'reject') {
                              await ApiService.put('/api/products/$docId', body: {'status': 'rejected'});
                              _snack(context, '❌ ${'rejected_label'.tr()}');
                            }
                          },
                          itemBuilder: (_) => [
                            if (status != 'approved')
                              PopupMenuItem(value: 'approve', child: Row(children: [Icon(Icons.check_circle_rounded, size: 14, color: Colors.green), const SizedBox(width: 8), Text('approve_label'.tr())])),
                            if (status != 'rejected')
                              PopupMenuItem(value: 'reject', child: Row(children: [Icon(Icons.cancel_rounded, size: 14, color: Colors.red), const SizedBox(width: 8), Text('reject_label'.tr())])),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
