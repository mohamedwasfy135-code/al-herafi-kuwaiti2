import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../requests/pages/request_detail_page.dart';

class RequestsTab extends StatefulWidget {
  final String uid;
  final String? requestsError;
  final bool requestsLoading;
  final List<Map<String, dynamic>> requests;
  final VoidCallback onRetry;
  const RequestsTab({super.key, required this.uid, required this.requestsError, required this.requestsLoading, required this.requests, required this.onRetry});
  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  String _statusLabel(String s) {
    switch (s) {
      case kStatusPending: return 'waiting_for_assign'.tr();
      case kStatusNotified: return 'craftsman_notified'.tr();
      case kStatusAccepted: return 'craftsman_accepted'.tr();
      case 'price_proposed': return 'price_proposed'.tr();
      case 'payment_confirmed': return 'payment_confirmed'.tr();
      case kStatusInProgress: return 'in_progress'.tr();
      case kStatusDone: return 'done'.tr();
      case kStatusRejected: return 'rejected'.tr();
      case 'cancelled_by_client': return 'cancelled_by_client'.tr();
      default: return s;
    }
  }

  Color _statusColor(String s) => switch (s) {
    kStatusPending => const Color(0xFF78909C), kStatusNotified => const Color(0xFF42A5F5), kStatusAccepted => const Color(0xFF1E88E5),
    'price_proposed' => const Color(0xFF00897B), 'payment_confirmed' => const Color(0xFF43A047), kStatusInProgress => const Color(0xFF1565C0),
    kStatusDone => const Color(0xFF2E7D32), _ => Colors.red,
  };

  IconData _statusIcon(String s) => switch (s) {
    kStatusPending => Icons.hourglass_empty_rounded,
    kStatusNotified => Icons.notifications_active_rounded,
    kStatusAccepted => Icons.thumb_up_alt_rounded,
    'price_proposed' => Icons.local_offer_rounded,
    'payment_confirmed' => Icons.payment_rounded,
    kStatusInProgress => Icons.play_circle_fill_rounded,
    kStatusDone => Icons.check_circle_rounded,
    kStatusRejected => Icons.cancel_rounded,
    'cancelled_by_client' => Icons.remove_circle_rounded,
    _ => Icons.build_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 900;

    if (widget.requestsError != null) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline, size: 60, color: Colors.red.shade300), const SizedBox(height: 16),
        Text('connection_lost'.tr(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 8),
        Text(widget.requestsError!, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.7))), const SizedBox(height: 20),
        ElevatedButton.icon(onPressed: widget.onRetry, icon: const Icon(Icons.refresh), label: Text('retry'.tr()), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0071E3), foregroundColor: const Color(0xFF1D1D1F))),
      ])));
    }
    if (widget.requestsLoading) return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isDesktop ? 900 : double.infinity),
        child: RefreshIndicator(
          onRefresh: () async { widget.onRetry(); await Future.delayed(const Duration(seconds: 1)); },
          color: const Color(0xFF0071E3),
          child: widget.requests.isEmpty
              ? ListView(children: [SizedBox(height: 150), Center(child: Column(children: [Icon(Icons.inbox_outlined, size: 72, color: Colors.white.withOpacity(0.5)), const SizedBox(height: 12), Text('No requests yet', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13))]))])
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: widget.requests.length,
                  itemBuilder: (context, index) {
                    final d = widget.requests[index];
                    final requestId = d['id']?.toString() ?? '';
                    final stat = d['status'] as String? ?? kStatusPending;
                    final c = _statusColor(stat);

                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 0 : 12, vertical: 4),
                      child: Card(
                        elevation: 0,
                        color: Colors.white.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.white.withOpacity(0.15)),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: c.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_statusIcon(stat), color: c, size: 22),
                          ),
                          title: Text(
                            d['service'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(_statusIcon(stat), size: 14, color: c),
                                const SizedBox(width: 4),
                                Text(_statusLabel(stat), style: TextStyle(color: c, fontWeight: FontWeight.w500, fontSize: 12)),
                              ],
                            ),
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white.withOpacity(0.6)),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RequestDetailPage(requestId: requestId, isClient: true))),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
