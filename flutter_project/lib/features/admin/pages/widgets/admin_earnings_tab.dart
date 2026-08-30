import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/firestore_service.dart';

class AdminEarningsTab extends StatelessWidget {
  const AdminEarningsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        FirestoreService.getRequests(status: kStatusDone),
        FirestoreService.getCraftsmen(),
        ApiService.get('/api/business'),
      ]),
      builder: (ctx, snap) {
        if (!snap.hasData)
          return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));

        final list = snap.data!;
        final requestsList = list[0] as List<Map<String, dynamic>>;
        final craftsmenList = list[1] as List<Map<String, dynamic>>;

        // Parse businesses from API response
        final businessesRes = list[2] as ApiResponse;
        final businessesList = (businessesRes.success && businessesRes.data != null)
            ? (businessesRes.data!['businesses'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? []
            : <Map<String, dynamic>>[];

        double commissionTotal = 0.0;
        final List<Map<String, dynamic>> completedList = [];

        for (final data in requestsList) {
          final amount = (data['finalAmount'] as num?)?.toDouble() ?? 0.0;
          if (amount > 0) {
            final commission = amount * 0.10;
            commissionTotal += commission;
            completedList.add({
              'requestId': data['id'] ?? '',
              'service': data['service'] ?? '',
              'clientName': data['clientName'] ?? '',
              'craftsmanName': data['craftsmanName'] ?? '',
              'amount': amount,
              'commission': commission,
            });
          }
        }

        double subscriptionTotal = 0.0;
        for (final data in craftsmenList) {
          if (data['subscriptionStatus'] == 'approved') {
            subscriptionTotal += (data['subscriptionPrice'] as num?)?.toDouble() ?? 0.0;
          }
        }
        for (final data in businessesList) {
          if (data['subscriptionStatus'] == 'approved') {
            subscriptionTotal += (data['subscriptionPrice'] as num?)?.toDouble() ?? 0.0;
          }
        }

        final totalEarnings = commissionTotal + subscriptionTotal;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // بطاقة الأرباح الرئيسية زجاجية
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0071E3).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.monetization_on_rounded, color: Color(0xFF0071E3), size: 20),
                      ),
                      const SizedBox(height: 16),
                      Text('platform_total_earnings'.tr(),
                          style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text('${totalEarnings.toStringAsFixed(3)} ${'kwd_currency'.tr()}',
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _earningStat('platform_commission_10'.tr(), '${commissionTotal.toStringAsFixed(3)} ${'kwd_currency'.tr()}', Colors.blue),
                          Container(height: 40, width: 1, color: Colors.white.withOpacity(0.2)),
                          _earningStat('subscription_fees_total'.tr(), '${subscriptionTotal.toStringAsFixed(3)} ${'kwd_currency'.tr()}', Colors.green),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // عنوان القائمة
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.list_alt_rounded, color: Colors.green, size: 14),
                ),
                const SizedBox(width: 12),
                Text('completed_requests'.tr(),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            const SizedBox(height: 12),

            if (completedList.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  Icon(Icons.inbox_rounded, size: 64, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('no_completed_requests'.tr(), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                ]),
              )
            else
              ...completedList.map((item) {
                final amount = item['amount'] as double;
                final commission = item['commission'] as double;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
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
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                          ),
                          title: Text(
                            item['service'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${item['clientName'] ?? ''} — ${item['craftsmanName'] ?? ''}',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$amount ${'kwd_currency'.tr()}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0071E3).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${'commission'.tr()}: ${commission.toStringAsFixed(3)}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF0071E3), fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Widget _earningStat(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.monetization_on_rounded, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }
}
