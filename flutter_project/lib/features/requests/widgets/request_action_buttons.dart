import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/chat_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/receipt_service.dart';
import '../../../../core/utils/location_utils.dart';
import '../../chat/pages/chat_screen.dart';
import 'proposal_field.dart';
import 'all_request_actions.dart';

class RequestActionButtons extends StatelessWidget {
  final Map<String, dynamic> data;
  final String status;
  final String requestId;
  final bool isClient;
  final String uid;
  final TextEditingController amountCtrl;
  final void Function(String) showSnack;
  final VoidCallback onStateChanged;
  final BuildContext context;
  final bool isAdminView;

  const RequestActionButtons({
    super.key,
    required this.data,
    required this.status,
    required this.requestId,
    required this.isClient,
    required this.uid,
    required this.amountCtrl,
    required this.showSnack,
    required this.onStateChanged,
    required this.context,
    this.isAdminView = false,
  });

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap) => SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withOpacity(0.6)),
        ),
        elevation: 0,
      ),
    ),
  );

  Future<void> _startWork() async {
    if (data['startedAt'] != null || data['status'] == kStatusInProgress) {
      showSnack('work_already_started'.tr());
      onStateChanged();
      return;
    }
    final pos = await LocationUtils.getCurrentPosition();
    final updates = <String, dynamic>{
      'status': kStatusInProgress,
      'startedAt': DateTime.now().toIso8601String(),
    };
    if (pos != null) {
      updates['craftsmanLatitude'] = pos.latitude;
      updates['craftsmanLongitude'] = pos.longitude;
    }
    await FirestoreService.updateRequest(requestId, updates);
    showSnack('work_started'.tr());
    onStateChanged();
  }

  Future<void> _finishWork() async {
    final d = data;
    final prepaidAmount = (d['agreedAmount'] as num?)?.toDouble() ?? 0.0;
    final hasPrepaid = d['paymentStatus'] == 'paid' && prepaidAmount > 0;
    final totalCtrl = TextEditingController();
    final workDetailsCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('finish_service_dialog_title'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasPrepaid)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('prepaid_amount_label'.tr(args: [prepaidAmount.toStringAsFixed(3)]),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            TextField(
              controller: totalCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'final_total'.tr(),
                prefixIcon: const Icon(Icons.monetization_on),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: workDetailsCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'work_details'.tr(),
                hintText: 'أدخل وصفاً موجزاً للأعمال المنجزة',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('cancel'.tr())),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('confirm'.tr())),
        ],
      ),
    );
    if (confirmed != true) return;

    final totalAmount = double.tryParse(totalCtrl.text.trim()) ?? 0.0;
    final remaining = (totalAmount - prepaidAmount).clamp(0.0, double.infinity).toDouble();
    final workDetails = workDetailsCtrl.text.trim();

    final updates = <String, dynamic>{
      'status': kStatusDone,
      'finishedAt': DateTime.now().toIso8601String(),
      'finalAmount': totalAmount,
      'prepaidAmount': prepaidAmount,
      'remainingAmount': remaining,
      'workDetails': workDetails,
      'payoutStatus': 'pending',
    };
    if (remaining > 0) {
      updates['remainingPaymentStatus'] = 'pending';
    }
    await FirestoreService.updateRequest(requestId, updates);

    final craftsmanId = d['assignedCraftsmanId'] as String?;
    if (craftsmanId != null && totalAmount > 0) {
      final platformFee = totalAmount * 0.10;
      final craftsmanShare = totalAmount - platformFee;
      // Create earnings record via API
      await FirestoreService.createPayoutRequest({
        'craftsmanId': craftsmanId,
        'requestId': requestId,
        'totalAmount': totalAmount,
        'platformFee': platformFee,
        'craftsmanShare': craftsmanShare,
        'payoutStatus': 'pending',
        'completedAt': DateTime.now().toIso8601String(),
      });
    }

    if (remaining > 0) {
      final clientId = d['clientId'] as String?;
      if (clientId != null) {
        await NotificationService.sendNotification(
          toUid: clientId,
          title: '💰 ${'remaining_payment_required'.tr()}',
          body: 'remaining_amount'.tr(args: [remaining.toStringAsFixed(3)]),
          data: {'type': 'remaining_payment', 'requestId': requestId},
        );
      }
    }

    if (remaining <= 0) {
      await ReceiptService.generateAndShare(
        requestId: requestId,
        clientName: d['clientName'] ?? '',
        craftsmanName: d['craftsmanName'] ?? '',
        service: d['service'] ?? '',
        amount: totalAmount,
        date: DateTime.now(),
        prepaidAmount: prepaidAmount,
        remainingAmount: 0,
        description: d['description'] ?? '',
        workDetails: workDetails,
      );
    }

    showSnack(remaining > 0
        ? 'service_finished_remaining'.tr(args: [remaining.toStringAsFixed(3)])
        : 'service_finished'.tr());
    onStateChanged();
  }

  Future<void> _rateRequest() async {
    final craftsmanId = data['assignedCraftsmanId'] as String?;
    if (craftsmanId == null) return;
    final ratingNotifier = ValueNotifier<double>(5.0);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('rate_craftsman_dialog'.tr()),
        content: ValueListenableBuilder<double>(
          valueListenable: ratingNotifier,
          builder: (_, val, __) => Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${val.toStringAsFixed(0)} / 5',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Slider(value: val, min: 1, max: 5, divisions: 4, onChanged: (v) => ratingNotifier.value = v),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('later'.tr())),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('send'.tr())),
        ],
      ),
    );
    if (confirmed != true) return;
    final rating = ratingNotifier.value;

    await FirestoreService.updateRequest(requestId, {
      'clientRating': rating,
      'ratedAt': DateTime.now().toIso8601String(),
    });

    // Update craftsman rating via API
    await FirestoreService.createReview({
      'craftsmanId': craftsmanId,
      'requestId': requestId,
      'rating': rating,
      'createdAt': DateTime.now().toIso8601String(),
    });

    showSnack('rating_thanks'.tr());
    onStateChanged();
  }

  Future<void> _rateCraftsmanToClient() async {
    final clientId = data['clientId'] as String?;
    if (clientId == null) return;
    final ratingNotifier = ValueNotifier<double>(5.0);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('rate_client_dialog'.tr()),
        content: ValueListenableBuilder<double>(
          valueListenable: ratingNotifier,
          builder: (_, val, __) => Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${val.toStringAsFixed(0)} / 5',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Slider(value: val, min: 1, max: 5, divisions: 4, onChanged: (v) => ratingNotifier.value = v),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('later'.tr())),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text('send'.tr())),
        ],
      ),
    );
    if (confirmed != true) return;
    final rating = ratingNotifier.value;

    await FirestoreService.updateRequest(requestId, {
      'craftsmanRating': rating,
      'craftsmanRatedAt': DateTime.now().toIso8601String(),
    });
    await FirestoreService.updateUser(clientId, {
      'avgRating': rating,
    });
    showSnack('rating_client_thanks'.tr());
    onStateChanged();
  }

  Future<void> _openChat() async {
    final clientId = data['clientId'] as String? ?? '';
    final craftsmanId = data['assignedCraftsmanId'] as String? ?? '';
    if (clientId.isEmpty || craftsmanId.isEmpty) {
      showSnack('chat_unavailable'.tr());
      return;
    }
    final otherUserId = isClient ? craftsmanId : clientId;
    final otherName = isClient
        ? (data['craftsmanName'] as String? ?? 'craftsman'.tr())
        : (data['clientName'] as String? ?? 'client'.tr());
    final chatId = await ChatService.getOrCreateChat(otherUserId);

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(
        chatId: chatId,
        otherUserName: otherName,
        otherUserId: otherUserId,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (isAdminView) return const SizedBox.shrink();

    final btns = <Widget>[];
    final d = data;
    final stat = status;
    final paymentStatus = d['paymentStatus'] as String?;
    final remainingPaymentStatus = d['remainingPaymentStatus'] as String?;
    final remainingAmount = (d['remainingAmount'] as num?)?.toDouble() ?? 0.0;
    final workStarted = d['startedAt'] != null;

    if (!isClient) {
      if (stat == kStatusNotified) {
        btns.add(_btn('accept_request'.tr(), Icons.check_circle, Colors.green,
            () => RequestActions.acceptRequest(context: context, requestId: requestId, showSnack: showSnack, onStateChanged: onStateChanged)));
        btns.add(_btn('reject_request'.tr(), Icons.cancel, Colors.red,
            () => RequestActions.rejectRequest(context: context, data: data, requestId: requestId, uid: uid, showSnack: showSnack, onStateChanged: onStateChanged)));
      }
      if (stat == kStatusAccepted) {
        btns.add(ProposalField(controller: amountCtrl, onSubmit: () =>
            RequestActions.proposeAmount(context: context, requestId: requestId, amountCtrl: amountCtrl, showSnack: showSnack, onStateChanged: onStateChanged)));
        btns.add(_btn('بدء العمل مباشرة', Icons.play_arrow, Colors.orange, () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('تأكيد بدء العمل'),
              content: const Text('هل تريد بدء العمل الآن دون انتظار دفع مسبق؟'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('بدء')),
              ],
            ),
          );
          if (ok == true) await _startWork();
        }));
      }
      if (stat == 'price_proposed' || stat == 'payment_pending') {
        btns.add(_btn('modify_price'.tr(), Icons.edit, Colors.orange, () {
          FirestoreService.updateRequest(requestId, {
            'status': kStatusAccepted,
            'proposedAmount': null,
          });
          onStateChanged();
        }));
      }
      if (stat == 'payment_confirmed' && !workStarted) {
        btns.add(_btn('start_work'.tr(), Icons.play_arrow, Colors.orange, _startWork));
      }
      if (stat == kStatusInProgress) {
        btns.add(_btn('finish_service'.tr(), Icons.done_all, Colors.blue, _finishWork));
      }
      if (stat == kStatusDone && d['craftsmanRating'] == null) {
        btns.add(_btn('rate_client'.tr(), Icons.star, Colors.amber, _rateCraftsmanToClient));
      }
    } else {
      if (stat == 'price_proposed') {
        btns.add(_btn('accept_and_pay'.tr(), Icons.payment, Colors.green,
            () => PaymentActions.clientAcceptAmount(context: context, data: data, requestId: requestId, showSnack: showSnack, onStateChanged: onStateChanged)));
        btns.add(_btn('reject_price'.tr(), Icons.thumb_down, Colors.red,
            () => PaymentActions.clientRejectAmount(context: context, requestId: requestId, showSnack: showSnack, onStateChanged: onStateChanged)));
      }
      if (stat == 'payment_pending') {
        btns.add(_btn('retry_payment'.tr(), Icons.payment, Colors.green,
            () => PaymentActions.clientAcceptAmount(context: context, data: data, requestId: requestId, showSnack: showSnack, onStateChanged: onStateChanged)));
        // verify_payment button removed — manualCheckPayment no longer available
      }
      if (paymentStatus == 'paid' || stat == 'payment_confirmed') {
        btns.add(_btn('download_receipt'.tr(), Icons.picture_as_pdf, Colors.blue, () {
          ReceiptService.generateAndShare(
            requestId: requestId,
            clientName: d['clientName'] ?? '',
            craftsmanName: d['craftsmanName'] ?? '',
            service: d['service'] ?? '',
            amount: (d['agreedAmount'] as num?)?.toDouble() ?? 0.0,
            date: DateTime.now(),
            prepaidAmount: (d['prepaidAmount'] as num?)?.toDouble() ?? 0.0,
            remainingAmount: (d['remainingAmount'] as num?)?.toDouble() ?? 0.0,
          );
        }));
      }
      if (stat == kStatusDone && remainingAmount > 0 && remainingPaymentStatus != 'paid' && remainingPaymentStatus != 'sent') {
        btns.add(_btn('pay_remaining'.tr(), Icons.payment, Colors.green,
            () => PaymentActions.payRemaining(context: context, data: data, requestId: requestId, showSnack: showSnack, onStateChanged: onStateChanged)));
      }
      if (stat == kStatusDone && d['clientRating'] == null) {
        btns.add(_btn('rate_craftsman'.tr(), Icons.star, Colors.amber, _rateRequest));
      }
      if ([kStatusPending, kStatusNotified, kStatusAccepted].contains(stat)) {
        btns.add(_btn('cancel_request'.tr(), Icons.cancel, Colors.red,
            () => RequestActions.cancelRequest(context: context, data: data, requestId: requestId, showSnack: showSnack, onStateChanged: onStateChanged)));
      }
    }

    if (d['assignedCraftsmanId'] != null &&
        [kStatusAccepted, 'price_proposed', 'payment_pending', 'payment_confirmed', kStatusInProgress, kStatusDone]
            .contains(stat)) {
      btns.add(_btn('chat'.tr(), Icons.chat, Colors.teal, _openChat));
    }

    if (btns.isEmpty) return const SizedBox.shrink();
    return Column(
      children: btns.map((b) => Padding(padding: const EdgeInsets.only(bottom: 10), child: b)).toList(),
    );
  }
}
