import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../requests/pages/request_detail_page.dart';

class RequestsTab extends StatelessWidget {
  final String uid;
  const RequestsTab({super.key, required this.uid});

  IconData _iconForStatus(String s) => switch (s) {
    kStatusPending       => Icons.hourglass_empty,
    kStatusNotified      => Icons.notifications_active_rounded,
    kStatusAccepted      => Icons.thumb_up_alt_rounded,
    'price_proposed'     => Icons.attach_money,
    'payment_pending'    => Icons.payment,
    'payment_confirmed'  => Icons.verified,
    kStatusInProgress    => Icons.play_circle_fill_rounded,
    kStatusDone          => Icons.check_circle_rounded,
    kStatusRejected      => Icons.cancel_rounded,
    kStatusNoCraftsman   => Icons.person_off,
    'cancelled_by_client'=> Icons.cancel_outlined,
    kStatusNeedsAdmin    => Icons.warning_amber_rounded,
    _                    => Icons.build_rounded,
  };

  Color _colorForStatus(String s) => switch (s) {
    kStatusPending       => Colors.grey,
    kStatusNotified      => Colors.orange,
    kStatusAccepted      => Colors.blue,
    'price_proposed'     => Colors.teal,
    'payment_pending'    => Colors.amber,
    'payment_confirmed'  => Colors.green,
    kStatusInProgress    => Colors.deepOrange,
    kStatusDone          => Colors.green,
    kStatusRejected      => Colors.red,
    kStatusNoCraftsman   => Colors.red,
    'cancelled_by_client'=> Colors.red,
    kStatusNeedsAdmin    => Colors.purple,
    _                    => Colors.grey,
  };

  String _translateStatus(String s) => switch (s) {
    kStatusPending       => 'بانتظار الإسناد',
    kStatusNotified      => 'تم إبلاغ حرفي',
    kStatusAccepted      => 'قبل الحرفي الطلب',
    'price_proposed'     => 'بانتظار تأكيد السعر',
    'payment_pending'    => 'بانتظار الدفع',
    'payment_confirmed'  => 'تم تأكيد الدفع',
    kStatusInProgress    => 'جاري العمل',
    kStatusDone          => 'مكتمل',
    kStatusRejected      => 'مرفوض',
    kStatusNoCraftsman   => 'لا يوجد حرفي',
    'cancelled_by_client'=> 'ملغي من العميل',
    kStatusNeedsAdmin    => 'يحتاج تدخل مشرف',
    _                    => s,
  };

  DateTime? _parseDate(dynamic val) {
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return _RequestsContent(
      uid: uid,
      iconForStatus: _iconForStatus,
      colorForStatus: _colorForStatus,
      translateStatus: _translateStatus,
      parseDate: _parseDate,
    );
  }
}

class _RequestsContent extends StatefulWidget {
  final String uid;
  final IconData Function(String) iconForStatus;
  final Color Function(String) colorForStatus;
  final String Function(String) translateStatus;
  final DateTime? Function(dynamic) parseDate;

  const _RequestsContent({
    required this.uid,
    required this.iconForStatus,
    required this.colorForStatus,
    required this.translateStatus,
    required this.parseDate,
  });

  @override
  State<_RequestsContent> createState() => _RequestsContentState();
}

class _RequestsContentState extends State<_RequestsContent> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() { _loading = true; _error = null; });
    try {
      final res = await ApiService.get('/api/requests', queryParameters: {
        'clientId': widget.uid,
      });
      if (res.success && res.data != null) {
        final list = res.data!['requests'] ?? res.data!['data'];
        if (list is List) {
          setState(() { _requests = list.cast<Map<String, dynamic>>(); _loading = false; });
        } else {
          setState(() { _requests = []; _loading = false; });
        }
      } else {
        setState(() { _error = res.error; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));
    }

    if (_error != null) {
      return Center(child: Text('خطأ: $_error', style: const TextStyle(color: Colors.white)));
    }

    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 72, color: Colors.white.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text('لا توجد طلبات بعد',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      color: const Color(0xFF0071E3),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final data = _requests[index];
          final requestId = data['id']?.toString() ?? '';
          final status = data['status'] ?? '';
          final service = data['service'] ?? '';
          final craftsmanName = data['assignedCraftsmanName'] ?? '';
          final createdAt = widget.parseDate(data['createdAt']);
          final notes = data['notes'] as String?;
          final color = widget.colorForStatus(status);
          final icon = widget.iconForStatus(status);
          final statusText = widget.translateStatus(status);

          final dateStr = createdAt != null
              ? DateFormat('yyyy/MM/dd - HH:mm').format(createdAt)
              : '';

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                title: Text(
                  service,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    if (craftsmanName.isNotEmpty)
                      Text(
                        'الحرفي: $craftsmanName',
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                      ),
                    if (notes != null && notes.isNotEmpty)
                      Text(
                        notes,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (dateStr.isNotEmpty)
                      Text(
                        dateStr,
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                      ),
                    const SizedBox(height: 4),
                    Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white.withOpacity(0.5)),
                  ],
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RequestDetailPage(
                      requestId: requestId,
                      isClient: true,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
