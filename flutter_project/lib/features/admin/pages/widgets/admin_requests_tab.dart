import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/receipt_service.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../shared/widgets/paginated_list.dart';
import '../../../requests/pages/request_detail_page.dart';

class AdminRequestsTab extends StatelessWidget {
  final String filter;
  const AdminRequestsTab({super.key, required this.filter});

  Future<void> _manualAssign(BuildContext context, String requestId, Map<String, dynamic> d) async {
    // نفس كود _manualAssign القديم
  }

  Future<void> _deleteRequest(BuildContext context, String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('confirm_delete'.tr()),
        content: Text('confirm_delete_request'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr() ?? 'Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('delete'.tr(), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService.delete('/api/requests/$id');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('deleted_successfully'.tr()), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${'error_label'.tr()}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

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

  String _statusLabel(String s) => switch (s) {
    kStatusPending      => 'admin_status_pending'.tr(),
    kStatusNotified     => 'admin_status_notified'.tr(),
    kStatusAccepted     => 'admin_status_accepted'.tr(),
    kStatusInProgress   => 'admin_status_in_progress'.tr(),
    kStatusDone         => 'admin_status_done'.tr(),
    kStatusNoCraftsman  => 'admin_status_no_craftsman'.tr(),
    kStatusNeedsAdmin   => 'admin_status_needs_admin'.tr(),
    _                   => s,
  };

  /// Build the fetcher function based on the filter
  Future<List<Map<String, dynamic>>> _fetchRequests({int page = 0, int pageSize = 15}) async {
    final allRequests = await FirestoreService.getRequests();

    // Filter based on the tab
    final activeStatuses = {kStatusPending, kStatusNotified, kStatusAccepted, kStatusInProgress};
    final problemStatuses = {kStatusNoCraftsman, kStatusNeedsAdmin};

    List<Map<String, dynamic>> filtered;
    if (filter == 'active') {
      filtered = allRequests.where((d) => activeStatuses.contains(d['status'])).toList();
    } else if (filter == 'problem') {
      filtered = allRequests.where((d) => problemStatuses.contains(d['status'])).toList();
    } else {
      filtered = allRequests;
    }

    // Sort by createdAt descending
    filtered.sort((a, b) {
      final aDate = _parseDateTime(a['createdAt']);
      final bDate = _parseDateTime(b['createdAt']);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });

    // Client-side pagination
    final start = page * pageSize;
    if (start >= filtered.length) return [];
    final end = (start + pageSize).clamp(0, filtered.length);
    return filtered.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    return PaginatedApiList(
      fetcher: ({required int page, required int pageSize}) => _fetchRequests(page: page, pageSize: pageSize),
      pageSize: 15,
      emptyWidget: Center(child: Text('no_requests_admin'.tr(), style: TextStyle(color: Colors.white.withOpacity(0.7)))),
      itemBuilder: (ctx, d, _) {
        final stat = d['status'] as String? ?? '';
        final isProblem = stat == kStatusNoCraftsman || stat == kStatusNeedsAdmin;
        final hasAiPrice = d['aiPricingRec'] != null;
        final isCompleted = (stat == kStatusDone || stat == 'cancelled_by_client');
        final docId = d['id'] as String? ?? '';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isProblem ? Colors.red.withOpacity(0.1) : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isProblem ? Colors.red.withOpacity(0.3) : const Color(0xFF0071E3).withOpacity(0.2),
                    child: Icon(isProblem ? Icons.warning : Icons.build, color: isProblem ? Colors.red : const Color(0xFF0071E3)),
                  ),
                  title: Row(children: [
                    Expanded(child: Text('${d['service'] ?? ''} — ${d['clientName'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white))),
                    if (hasAiPrice)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0071E3).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF0071E3).withOpacity(0.5)),
                        ),
                        child: Text('${(d['aiPricingRec'] as num).toStringAsFixed(2)} ${'kwd_currency'.tr()}',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF0071E3), fontWeight: FontWeight.bold)),
                      ),
                  ]),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d['clientGovernorate'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.7))),
                    Text(_statusLabel(stat), style: TextStyle(color: isProblem ? Colors.red : const Color(0xFF0071E3), fontWeight: FontWeight.w600, fontSize: 12)),
                  ]),
                  trailing: PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.7)),
                    onSelected: (v) {
                      if (v == 'detail') Navigator.push(ctx, MaterialPageRoute(builder: (_) => RequestDetailPage(
                        requestId: docId,
                        isClient: false,
                        isAdminView: true,
                      )));
                      if (v == 'assign') _manualAssign(ctx, docId, d);
                      if (v == 'delete') _deleteRequest(ctx, docId);
                      if (v == 'receipt') _openReceipt(docId, d);
                    },
                    itemBuilder: (_) {
                      final items = <PopupMenuEntry<String>>[
                        PopupMenuItem(value: 'detail', child: Row(children: [const Icon(Icons.visibility, size:16), const SizedBox(width:8), Text('view'.tr())])),
                      ];
                      if (!isCompleted) {
                        items.add(PopupMenuItem(value: 'assign', child: Row(children: [const Icon(Icons.person_add, size:16), const SizedBox(width:8), Text('manual_assign'.tr())])));
                      }
                      items.add(PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete, size:16, color: Colors.red), const SizedBox(width:8), Text('delete'.tr(), style: const TextStyle(color: Colors.red))])));
                      if (isCompleted && d['finalAmount'] != null) {
                        items.add(PopupMenuItem(value: 'receipt', child: Row(children: [const Icon(Icons.receipt, size:16), const SizedBox(width:8), Text('invoice'.tr())])));
                      }
                      return items;
                    },
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
