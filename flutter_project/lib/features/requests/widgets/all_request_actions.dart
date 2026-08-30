import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/agreement_service.dart';
import '../../../../core/services/auto_assign_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/myfatoorah_service.dart';
import '../../../../core/services/notification_service.dart';

// ═══════════════════════════════════════════════════════
// فئة إجراءات الدفع
// ═══════════════════════════════════════════════════════
class PaymentActions {
  static Future<void> openPaymentUrl({required String url, required BuildContext context}) async {
    if (kIsWeb) {
      // Web: use url_launcher as fallback since universal_html is removed
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('payment_link_failed'.tr()), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  static Future<void> clientAcceptAmount({
    required BuildContext context,
    required Map<String, dynamic> data,
    required String requestId,
    required void Function(String) showSnack,
    required VoidCallback onStateChanged,
  }) async {
    final amount = (data['proposedAmount'] as num).toDouble();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _glassDialog(
        context: context,
        title: 'accept_and_pay_dialog'.tr(),
        content: 'accept_and_pay_confirm'.tr(args: [amount.toStringAsFixed(3)]),
        confirmText: 'agree_and_pay'.tr(),
        cancelText: 'cancel'.tr(),
      ),
    );
    if (ok != true) return;

    await AgreementService.acceptAmount(requestId: requestId, amount: amount);
    final result = await MyFatoorahService.createPaymentLink(
      requestId: requestId, amount: amount,
      clientName: data['clientName'] ?? '', clientPhone: data['clientPhone'] ?? '', service: data['service'] ?? '',
    );
    if (result != null && result['success'] == true) {
      await openPaymentUrl(url: result['paymentURL'] as String, context: context);
    } else {
      showSnack('payment_link_creation_failed'.tr());
    }
    onStateChanged();
  }

  static Future<void> payRemaining({
    required BuildContext context, required Map<String, dynamic> data,
    required String requestId,
    required void Function(String) showSnack, required VoidCallback onStateChanged,
  }) async {
    final remainingAmount = (data['remainingAmount'] as num?)?.toDouble() ?? 0.0;
    if (remainingAmount <= 0) { showSnack('no_remaining_amount'.tr()); return; }
    final result = await MyFatoorahService.createPaymentLink(
      requestId: requestId, amount: remainingAmount,
      clientName: data['clientName'] ?? '', clientPhone: data['clientPhone'] ?? '', service: data['service'] ?? '',
    );
    if (result != null && result['success'] == true) {
      await FirestoreService.updateRequest(requestId, {'remainingPaymentStatus': 'sent'});
      await openPaymentUrl(url: result['paymentURL'] as String, context: context);
    } else {
      showSnack('payment_link_creation_failed'.tr());
    }
    onStateChanged();
  }

  static Future<void> clientRejectAmount({
    required BuildContext context, required String requestId,
    required void Function(String) showSnack,
    required VoidCallback onStateChanged,
  }) async {
    await AgreementService.rejectAmount(requestId: requestId);
    final req = await FirestoreService.getRequest(requestId);
    final craftsmanId = req?['assignedCraftsmanId'] as String?;
    if (craftsmanId != null) {
      await NotificationService.sendNotification(
        toUid: craftsmanId, title: '❌ ${'price_rejected'.tr()}',
        body: 'price_rejected_body'.tr(), data: {'type': 'price_rejected', 'requestId': requestId},
      );
    }
    showSnack('price_rejected_by_client'.tr());
    onStateChanged();
  }

  static Widget _glassDialog({
    required BuildContext context, required String title, required String content,
    required String confirmText, required String cancelText,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(content, style: const TextStyle(color: Colors.white70)),
          backgroundColor: Colors.white.withOpacity(0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancelText, style: const TextStyle(color: Colors.white70))),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0071E3).withOpacity(0.9),
                foregroundColor: const Color(0xFF1D1D1F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(confirmText),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// فئة إجراءات الطلب
// ═══════════════════════════════════════════════════════
class RequestActions {
  static Future<void> proposeAmount({
    required BuildContext context, required String requestId,
    required TextEditingController amountCtrl,
    required void Function(String) showSnack, required VoidCallback onStateChanged,
  }) async {
    final amt = double.tryParse(amountCtrl.text.trim());
    if (amt == null || amt <= 0) { showSnack('invalid_amount'.tr()); return; }
    await AgreementService.proposeAmount(requestId: requestId, amount: amt);
    final req = await FirestoreService.getRequest(requestId);
    final clientId = req?['clientId'] as String?;
    if (clientId != null) {
      await NotificationService.sendNotification(
        toUid: clientId, title: '💰 ${'price_proposed'.tr()}',
        body: 'craftsman_proposed_price'.tr(args: [amt.toStringAsFixed(3)]),
        data: {'type': 'price_proposed', 'requestId': requestId},
      );
    }
    showSnack('price_sent_to_client'.tr());
    onStateChanged();
  }

  static Future<void> acceptRequest({
    required BuildContext context, required String requestId,
    required void Function(String) showSnack,
    required VoidCallback onStateChanged,
  }) async {
    AutoAssignService.cancelTimer(requestId);
    await FirestoreService.updateRequest(requestId, {
      'status': kStatusAccepted, 'acceptedAt': DateTime.now().toIso8601String(),
    });
    final req = await FirestoreService.getRequest(requestId);
    final clientId = req?['clientId'] as String?;
    if (clientId != null) {
      await NotificationService.sendNotification(
        toUid: clientId, title: '✅ ${'craftsman_accepted'.tr()}',
        body: 'craftsman_accepted_body'.tr(), data: {'type': 'accepted', 'requestId': requestId},
      );
    }
    showSnack('request_accepted'.tr());
    onStateChanged();
  }

  static Future<void> rejectRequest({
    required BuildContext context, required Map<String, dynamic> data,
    required String requestId, required String uid,
    required void Function(String) showSnack, required VoidCallback onStateChanged,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _glassDialog(
        context: context, title: 'reject_request'.tr(), content: 'reject_request_confirm'.tr(),
        confirmText: 'reject'.tr(), cancelText: 'cancel'.tr(), confirmColor: Colors.red,
      ),
    );
    if (ok != true) return;

    await FirestoreService.updateRequest(requestId, {
      'status': kStatusRejected, 'rejectedAt': DateTime.now().toIso8601String(), 'rejectedBy': uid,
    });
    AutoAssignService.cancelTimer(requestId);

    final req = await FirestoreService.getRequest(requestId);
    if (req != null) {
      await AutoAssignService.assignRequest(
        requestId: requestId, service: req['service'] ?? '',
        governorate: req['clientGovernorate'] ?? '',
        clientLat: (req['clientLatitude'] as num?)?.toDouble(),
        clientLng: (req['clientLongitude'] as num?)?.toDouble(),
        clientName: req['clientName'] ?? '', clientPhone: req['clientPhone'] ?? '',
        clientId: req['clientId'] ?? '', requestDescription: req['notes'] ?? '',
      );
    }
    showSnack('request_rejected'.tr());
    onStateChanged();
  }

  static Future<void> cancelRequest({
    required BuildContext context, required Map<String, dynamic> data,
    required String requestId,
    required void Function(String) showSnack, required VoidCallback onStateChanged,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _glassDialog(
        context: context, title: 'cancel_request'.tr(), content: 'cancel_request_confirm'.tr(),
        confirmText: 'cancel'.tr(), cancelText: 'no'.tr(), confirmColor: Colors.red,
      ),
    );
    if (ok != true) return;

    await FirestoreService.updateRequest(requestId, {
      'status': 'cancelled_by_client', 'cancelledAt': DateTime.now().toIso8601String(),
    });
    final craftsmanId = data['assignedCraftsmanId'] as String?;
    if (craftsmanId != null) {
      await NotificationService.sendNotification(
        toUid: craftsmanId, title: '❌ ${'request_cancelled'.tr()}',
        body: 'request_cancelled_by_client_body'.tr(args: [data['clientName'] ?? '']),
        data: {'type': 'request_cancelled', 'requestId': requestId},
      );
    }
    showSnack('request_cancelled'.tr());
    onStateChanged();
  }

  static Widget _glassDialog({
    required BuildContext context, required String title, required String content,
    required String confirmText, required String cancelText,
    Color confirmColor = const Color(0xFF0071E3),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          title: Text(title, style: const TextStyle(color: Colors.white)),
          content: Text(content, style: const TextStyle(color: Colors.white70)),
          backgroundColor: Colors.white.withOpacity(0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancelText, style: const TextStyle(color: Colors.white70))),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor.withOpacity(0.3),
                foregroundColor: confirmColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: confirmColor.withOpacity(0.6)),
                ),
              ),
              child: Text(confirmText, style: TextStyle(color: confirmColor)),
            ),
          ],
        ),
      ),
    );
  }
}
