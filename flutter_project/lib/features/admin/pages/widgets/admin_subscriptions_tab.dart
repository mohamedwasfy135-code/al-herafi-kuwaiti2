import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../shared/widgets/paginated_list.dart';

class AdminSubscriptionsTab extends StatefulWidget {
  const AdminSubscriptionsTab({super.key});
  @override
  State<AdminSubscriptionsTab> createState() => _AdminSubscriptionsTabState();
}

class _AdminSubscriptionsTabState extends State<AdminSubscriptionsTab> {
  final _subscriptionPriceCtrl = TextEditingController();

  @override
  void dispose() {
    _subscriptionPriceCtrl.dispose();
    super.dispose();
  }

  Color _subscriptionColor(String status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'rejected': return Colors.red;
      case 'pending':  return Colors.orange;
      default:         return Colors.grey;
    }
  }

  IconData _subscriptionIcon(String status) {
    switch (status) {
      case 'approved': return Icons.check_circle_rounded;
      case 'rejected': return Icons.cancel_rounded;
      case 'pending':  return Icons.hourglass_empty_rounded;
      default:         return Icons.remove_circle_outline;
    }
  }

  String _subscriptionLabel(String status) {
    switch (status) {
      case 'approved': return 'approved_label'.tr();
      case 'rejected': return 'rejected_label'.tr();
      case 'pending':  return 'pending_status'.tr();
      default:         return 'no_subscription'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // شريط التبويبات زجاجي
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: TabBar(
              indicator: BoxDecoration(
                color: const Color(0xFF0071E3).withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: const Color(0xFF0071E3),
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              tabs: [
                Tab(text: 'craftsmen_subscriptions'.tr()),
                Tab(text: 'businesses_subscriptions'.tr()),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _subscriptionsList(isCraftsman: true),
                _subscriptionsList(isCraftsman: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _subscriptionsList({required bool isCraftsman}) {
    return PaginatedApiList(
      fetcher: ({required int page, required int pageSize}) async {
        if (isCraftsman) {
          return FirestoreService.getCraftsmen();
        } else {
          final res = await ApiService.get('/api/business');
          if (res.success && res.data != null) {
            final list = res.data!['businesses'] as List<dynamic>?;
            return list?.cast<Map<String, dynamic>>() ?? [];
          }
          return <Map<String, dynamic>>[];
        }
      },
      pageSize: 20,
      emptyWidget: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(isCraftsman ? Icons.construction_outlined : Icons.store_outlined, size: 64, color: Colors.white.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(isCraftsman ? 'no_craftsmen'.tr() : 'no_businesses_registered'.tr(),
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
        ]),
      ),
      itemBuilder: (ctx, d, _) {
        final subscriptionStatus = d['subscriptionStatus'] as String? ?? 'none';
        final subscriptionPrice = (d['subscriptionPrice'] as num?)?.toDouble();
        final color = _subscriptionColor(subscriptionStatus);
        final docId = d['id'] as String? ?? '';

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
                      color: isCraftsman ? Colors.orange.withOpacity(0.2) : const Color(0xFF0071E3).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isCraftsman ? Icons.construction_rounded : Icons.store_rounded,
                      color: isCraftsman ? Colors.orange : const Color(0xFF0071E3),
                      size: 22,
                    ),
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
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 12, color: Colors.white.withOpacity(0.6)),
                            const SizedBox(width: 4),
                            Text(
                              d['governorate'] ?? '',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.work_outline, size: 12, color: Colors.white.withOpacity(0.6)),
                            const SizedBox(width: 4),
                            Text(
                              d['job'] ?? d['businessType'] ?? '',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: color.withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_subscriptionIcon(subscriptionStatus), size: 14, color: color),
                                  const SizedBox(width: 4),
                                  Text(
                                    _subscriptionLabel(subscriptionStatus),
                                    style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (subscriptionPrice != null) ...[
                              const SizedBox(width: 12),
                              Icon(Icons.monetization_on_outlined, size: 14, color: Colors.white.withOpacity(0.6)),
                              const SizedBox(width: 4),
                              Text(
                                '$subscriptionPrice ${'kwd_currency'.tr()}',
                                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ],
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
                        final apiPath = isCraftsman ? '/api/users/$docId' : '/api/business/$docId';

                        if (v == 'edit_price') {
                          _subscriptionPriceCtrl.text = subscriptionPrice?.toString() ?? '';
                          final newPrice = await showDialog<double>(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: Text('edit_subscription_price'.tr()),
                              content: TextField(
                                controller: _subscriptionPriceCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'subscription_price'.tr(),
                                  suffixText: 'kwd_currency'.tr(),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0071E3).withOpacity(0.9),
                                    foregroundColor: const Color(0xFF1D1D1F),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => Navigator.pop(context, double.tryParse(_subscriptionPriceCtrl.text.trim())),
                                  child: Text('save'.tr()),
                                ),
                              ],
                            ),
                          );
                          if (newPrice != null) {
                            await ApiService.put(apiPath, body: {
                              'subscriptionPrice': newPrice,
                            });
                          }
                        } else if (v == 'approve') {
                          await ApiService.put(apiPath, body: {
                            'subscriptionStatus': 'approved',
                          });
                        } else if (v == 'reject') {
                          await ApiService.put(apiPath, body: {
                            'subscriptionStatus': 'rejected',
                          });
                        }
                        setState(() {});
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit_price',
                          child: Row(children: [Icon(Icons.edit_rounded, size: 14, color: Colors.blue), const SizedBox(width: 8), Text('edit_price'.tr())]),
                        ),
                        if (subscriptionStatus != 'approved')
                          PopupMenuItem(
                            value: 'approve',
                            child: Row(children: [Icon(Icons.check_circle_rounded, size: 14, color: Colors.green), const SizedBox(width: 8), Text('approve_label'.tr())]),
                          ),
                        if (subscriptionStatus != 'rejected')
                          PopupMenuItem(
                            value: 'reject',
                            child: Row(children: [Icon(Icons.cancel_rounded, size: 14, color: Colors.red), const SizedBox(width: 8), Text('reject_label'.tr())]),
                          ),
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
  }
}
