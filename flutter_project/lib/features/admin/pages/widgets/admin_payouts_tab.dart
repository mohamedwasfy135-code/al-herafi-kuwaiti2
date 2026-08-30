import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/notification_service.dart';

class AdminPayoutsTab extends StatefulWidget {
  const AdminPayoutsTab({super.key});
  @override
  State<AdminPayoutsTab> createState() => _AdminPayoutsTabState();
}

class _AdminPayoutsTabState extends State<AdminPayoutsTab> {
  final _referenceCtrl = TextEditingController();
  final _deleteReasonCtrl = TextEditingController();
  List<Map<String, dynamic>> _payouts = [];
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadPayouts();
    // Polling-based stream: refresh every 30 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadPayouts());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _referenceCtrl.dispose();
    _deleteReasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPayouts() async {
    try {
      final res = await ApiService.get('/api/payouts', queryParameters: {
        'orderBy': 'requestedAt',
        'order': 'desc',
      });
      if (res.success && res.data != null) {
        final list = res.data!['payouts'] ?? res.data!['data'];
        if (list is List && mounted) {
          setState(() {
            _payouts = list.cast<Map<String, dynamic>>();
            _loading = false;
          });
        }
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _payoutStatusColor(String status) {
    switch (status) {
      case 'paid': return Colors.green;
      case 'rejected': return Colors.red;
      default: return Colors.orange;
    }
  }

  IconData _payoutStatusIcon(String status) {
    switch (status) {
      case 'paid': return Icons.check_circle_rounded;
      case 'rejected': return Icons.cancel_rounded;
      default: return Icons.hourglass_empty_rounded;
    }
  }

  String _payoutStatusLabel(String status) {
    switch (status) {
      case 'paid': return 'paid_status'.tr();
      case 'rejected': return 'rejected_label'.tr();
      default: return 'pending_status'.tr();
    }
  }

  void _showImageDialog(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Future<void> _processPayout(String payoutId, Map<String, dynamic> d, String newStatus) async {
    final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
    final craftsmanId = d['craftsmanId'] as String?;

    if (newStatus == 'paid') {
      _referenceCtrl.clear();
      final ref = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('confirm_payment'.tr()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      '${'amount_to_pay'.tr()}: ${amount.toStringAsFixed(3)} ${'kwd_currency'.tr()}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _referenceCtrl,
                decoration: InputDecoration(
                  labelText: 'reference_number'.tr(),
                  hintText: 'رقم الحوالة أو WAMD',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context, _referenceCtrl.text.trim()),
              child: Text('confirm'.tr()),
            ),
          ],
        ),
      );
      if (ref == null) return;

      await ApiService.put('/api/payouts/$payoutId', body: {
        'status': newStatus,
        'reference': ref,
        'processedAt': DateTime.now().toIso8601String(),
        'adminId': AuthService.currentUser?.id,
      });

      if (craftsmanId != null) {
        await NotificationService.sendNotification(
          toUid: craftsmanId,
          title: '✅ ${'payout_approved_title'.tr()}',
          body: 'payout_approved_body'.tr(args: [amount.toStringAsFixed(3)]),
          data: {'type': 'payout_approved', 'payoutId': payoutId},
        );
      }
    } else {
      await ApiService.put('/api/payouts/$payoutId', body: {
        'status': newStatus,
        'processedAt': DateTime.now().toIso8601String(),
        'adminId': AuthService.currentUser?.id,
      });

      if (craftsmanId != null) {
        await NotificationService.sendNotification(
          toUid: craftsmanId,
          title: '❌ ${'payout_rejected_title'.tr()}',
          body: 'payout_rejected_body'.tr(),
          data: {'type': 'payout_rejected', 'payoutId': payoutId},
        );
      }
    }
    _loadPayouts();
  }

  Future<void> _deletePayout(String payoutId, Map<String, dynamic> d) async {
    _deleteReasonCtrl.clear();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('delete_payout_title'.tr()),
        content: TextField(
          controller: _deleteReasonCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'delete_reason'.tr(),
            hintText: 'سبب الحذف...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr())),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _deleteReasonCtrl.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;

    try {
      // Archive deleted payout via API
      await ApiService.post('/api/payouts/deleted', body: {
        ...d,
        'deletedAt': DateTime.now().toIso8601String(),
        'deletedBy': AuthService.currentUser?.id,
        'deleteReason': reason,
      });

      // Delete the payout
      await ApiService.delete('/api/payouts/$payoutId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('deleted_successfully'.tr()), backgroundColor: Colors.green),
        );
      }

      _loadPayouts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('error_deleting_payout'.tr()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0071E3)));
    }

    if (_payouts.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.white.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('no_payout_requests'.tr(), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
        ]),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPayouts,
      color: const Color(0xFF0071E3),
      child: ListView.builder(
        itemCount: _payouts.length,
        itemBuilder: (ctx, index) {
          final d = _payouts[index];
          final payoutId = d['id'] as String? ?? '';
          final status = d['status'] as String? ?? 'pending';
          final amount = (d['amount'] as num?)?.toDouble() ?? 0.0;
          final grossAmount = (d['grossAmount'] as num?)?.toDouble();
          final commission = (d['commission'] as num?)?.toDouble();
          final phone = d['phone'] as String? ?? '';
          final email = d['email'] as String? ?? '';
          final profileImageUrl = d['profileImageUrl'] as String?;
          final civilIdUrl = d['civilIdUrl'] as String?;
          final bankName = d['bankName'] as String? ?? '';
          final accountNumber = d['accountNumber'] as String? ?? '';
          final iban = d['iban'] as String? ?? '';
          final reference = d['reference'] as String?;
          final availableBalance = (d['availableBalanceAtRequest'] as num?)?.toDouble();
          final color = _payoutStatusColor(status);

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
                  child: ExpansionTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.account_balance_wallet_rounded, color: color, size: 22),
                    ),
                    title: Text(
                      '${d['craftsmanName'] ?? ''} — ${amount.toStringAsFixed(3)} ${'kwd_currency'.tr()}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                    ),
                    subtitle: Row(
                      children: [
                        Icon(_payoutStatusIcon(status), size: 14, color: color),
                        const SizedBox(width: 4),
                        Text(
                          _payoutStatusLabel(status),
                          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (grossAmount != null) ...[
                              _infoRow('gross_amount'.tr(), '${grossAmount.toStringAsFixed(3)} ${'kwd_currency'.tr()}', isBold: true),
                              _infoRow('commission_amount'.tr(), '${(commission ?? 0).toStringAsFixed(3)} ${'kwd_currency'.tr()}'),
                              _infoRow('net_amount'.tr(), '${amount.toStringAsFixed(3)} ${'kwd_currency'.tr()}', color: Colors.green, isBold: true),
                              const Divider(),
                            ],

                            if (availableBalance != null)
                              _infoRow('available_balance_at_request'.tr(), '${availableBalance.toStringAsFixed(3)} ${'kwd_currency'.tr()}'),

                            if (phone.isNotEmpty) _infoRow('phone_label'.tr(), phone),
                            if (email.isNotEmpty) _infoRow('email_label'.tr(), email),

                            if (profileImageUrl != null && profileImageUrl.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text('${'profile_image_uploaded'.tr()}: ', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                                  GestureDetector(
                                    onTap: () => _showImageDialog(profileImageUrl),
                                    child: Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                                        image: DecorationImage(image: NetworkImage(profileImageUrl), fit: BoxFit.cover),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (civilIdUrl != null && civilIdUrl.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text('${'civil_id_uploaded'.tr()}: ', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                                  GestureDetector(
                                    onTap: () => _showImageDialog(civilIdUrl),
                                    child: Container(
                                      width: 48, height: 30,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                                        image: DecorationImage(image: NetworkImage(civilIdUrl), fit: BoxFit.cover),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            if (bankName.isNotEmpty || accountNumber.isNotEmpty || iban.isNotEmpty) ...[
                              const Divider(color: Colors.white24),
                              if (bankName.isNotEmpty) _infoRow('bank_name'.tr(), bankName),
                              if (accountNumber.isNotEmpty) _infoRow('account_number'.tr(), accountNumber),
                              if (iban.isNotEmpty) _infoRow('IBAN', iban),
                            ],

                            if (reference != null && reference.isNotEmpty)
                              _infoRow('reference_number'.tr(), reference),

                            const SizedBox(height: 12),

                            if (status == 'pending')
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _processPayout(payoutId, d, 'paid'),
                                      icon: const Icon(Icons.check_circle_rounded, size: 14),
                                      label: Text('confirm_payment'.tr(), style: const TextStyle(fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green.withOpacity(0.3),
                                        foregroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          side: BorderSide(color: Colors.green.withOpacity(0.5)),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _processPayout(payoutId, d, 'rejected'),
                                      icon: const Icon(Icons.cancel_rounded, size: 14),
                                      label: Text('reject_label'.tr(), style: const TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        side: const BorderSide(color: Colors.red),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            if (status == 'paid' || status == 'rejected')
                              TextButton.icon(
                                onPressed: () => _deletePayout(payoutId, d),
                                icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Colors.red),
                                label: Text('delete_payout'.tr(), style: const TextStyle(color: Colors.red, fontSize: 12)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: color ?? Colors.white,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
