import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../requests/pages/request_detail_page.dart';

class CraftsmanRequestsTab extends StatefulWidget {
  final String uid;
  const CraftsmanRequestsTab({super.key, required this.uid});

  @override
  State<CraftsmanRequestsTab> createState() => _CraftsmanRequestsTabState();
}

class _CraftsmanRequestsTabState extends State<CraftsmanRequestsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String? _lastError;
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() { _loading = true; _lastError = null; });
    try {
      final res = await ApiService.get('/api/requests', queryParameters: {
        'craftsmanId': widget.uid,
      });
      if (res.success && res.data != null) {
        final list = res.data!['requests'] ?? res.data!['data'];
        if (list is List) {
          // Sort by createdAt descending
          final items = list.cast<Map<String, dynamic>>();
          items.sort((a, b) {
            final aTime = a['createdAt'];
            final bTime = b['createdAt'];
            if (aTime == null || bTime == null) return 0;
            return bTime.toString().compareTo(aTime.toString());
          });
          setState(() { _requests = items; _loading = false; });
        } else {
          setState(() { _requests = []; _loading = false; });
        }
      } else {
        setState(() { _lastError = res.error; _loading = false; });
      }
    } catch (e) {
      setState(() { _lastError = e.toString(); _loading = false; });
    }
  }

  Future<Map<String, dynamic>> _fetchDiagnostics() async {
    try {
      final results = await Future.wait([
        ApiService.get('/api/requests', queryParameters: {
          'assignedCraftsmanId': widget.uid,
        }),
        ApiService.get('/api/requests', queryParameters: {
          'craftsmanId': widget.uid,
        }),
        ApiService.get('/api/craftsmen/${widget.uid}'),
      ]);
      final assignedCount = (results[0].data?['requests'] ?? results[0].data?['data'] ?? []) as List;
      final craftsmanIdCount = (results[1].data?['requests'] ?? results[1].data?['data'] ?? []) as List;
      final craftsmanExists = results[2].success && results[2].data != null;
      return {
        'assignedCount': assignedCount.length,
        'craftsmanIdCount': craftsmanIdCount.length,
        'craftsmanExists': craftsmanExists,
        'uid': widget.uid,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Color _statusColor(String s) => switch (s) {
        kStatusNotified => Colors.orange,
        kStatusAccepted => Colors.blue,
        kStatusInProgress => Colors.deepOrange,
        kStatusDone => Colors.green,
        kStatusRejected => Colors.red,
        kStatusNeedsAdmin => Colors.purple,
        _ => Colors.grey,
      };

  IconData _statusIcon(String s) => switch (s) {
        kStatusNotified => Icons.notifications_active_rounded,
        kStatusAccepted => Icons.thumb_up_alt_rounded,
        kStatusInProgress => Icons.play_circle_fill_rounded,
        kStatusDone => Icons.check_circle_rounded,
        kStatusRejected => Icons.cancel_rounded,
        kStatusNeedsAdmin => Icons.warning_amber_rounded,
        _ => Icons.build_rounded,
      };

  String _statusLabel(String s) => switch (s) {
        kStatusNotified => '🔔 ${'new_request_status'.tr()}',
        kStatusAccepted => '✅ ${'accepted_status'.tr()}',
        kStatusInProgress => '🔧 ${'in_progress_status'.tr()}',
        kStatusDone => '🎉 ${'completed_status'.tr()}',
        kStatusRejected => '❌ ${'rejected_status'.tr()}',
        kStatusNeedsAdmin => '⚠️ ${'needs_review_status'.tr()}',
        _ => s,
      };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;

    return Column(
      children: [
        // شريط التشخيص
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            const Icon(Icons.person, size: 14, color: Color(0xFF0071E3)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'UID: ${widget.uid}',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF0071E3).withOpacity(0.3),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final result = await _fetchDiagnostics();
                if (!mounted) return;
                final hasError = result.containsKey('error');
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: Text('diagnosis_result'.tr()),
                    content: hasError
                        ? Text(
                            '${'error_label'.tr()}: ${result['error']}',
                            style: const TextStyle(color: Colors.red))
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _diagRow(
                                  'craftsman_account_exists'.tr(),
                                  result['craftsmanExists']
                                      ? '✅ ${'exists'.tr()}'
                                      : '❌ ${'not_exists'.tr()}'),
                              _diagRow('requests_assigned'.tr(),
                                  '${result['assignedCount']}'),
                              _diagRow('requests_old'.tr(),
                                  '${result['craftsmanIdCount']}'),
                              const Divider(),
                              SelectableText('UID:\n${result['uid']}',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('ok'.tr()),
                      ),
                    ],
                  ),
                );
              },
              child: Text('diagnosis'.tr()),
            ),
          ]),
        ),

        if (_lastError != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_lastError!,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.red)),
              ),
            ]),
          ),

        // قائمة الطلبات
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: isDesktop ? 900 : double.infinity),
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)))
                  : _requests.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox, size: 72, color: Colors.white.withOpacity(0.5)),
                                const SizedBox(height: 16),
                                Text('no_requests_currently'.tr(),
                                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                const SizedBox(height: 8),
                                Text('pull_to_refresh'.tr(),
                                    style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          ],
                        )
                      : RefreshIndicator(
                          onRefresh: _loadRequests,
                          color: const Color(0xFF0071E3),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _requests.length,
                            itemBuilder: (_, i) {
                              final data = _requests[i];
                              final requestId = data['id']?.toString() ?? '';
                              final stat = data['status'] as String? ?? '';
                              final color = _statusColor(stat);

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
                                      child: Icon(_statusIcon(stat), color: color, size: 22),
                                    ),
                                    title: Text(
                                      data['service'] as String? ?? '',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${data['clientName'] ?? ''} — ${data['clientGovernorate'] ?? ''}',
                                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: color.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _statusLabel(stat),
                                              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.white.withOpacity(0.6)),
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RequestDetailPage(requestId: requestId, isClient: false),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _diagRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 13)),
            Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
