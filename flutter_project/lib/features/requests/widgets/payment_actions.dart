import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/agreement_service.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/auto_assign_service.dart';
import '../../../../core/services/notification_service.dart';

class RequestActions {
  static Future<void> proposeAmount({
    required BuildContext context,
    required String requestId,
    required TextEditingController amountCtrl,
    required void Function(String) showSnack,
    required VoidCallback onStateChanged,
  }) async {
    final amt = double.tryParse(amountCtrl.text.trim());
    if (amt == null || amt <= 0) {
      showSnack('invalid_amount'.tr());
      return;
    }
    await AgreementService.proposeAmount(requestId: requestId, amount: amt);
    final res = await ApiService.get('/api/requests/$requestId');
    final clientId = res.data?['request']?['clientId'] as String?;
    if (clientId != null) {
      await NotificationService.sendNotification(
        toUid: clientId,
        title: '💰 ${'price_proposed'.tr()}',
        body: 'craftsman_proposed_price'.tr(args: [amt.toStringAsFixed(3)]),
        data: {'type': 'price_proposed', 'requestId': requestId},
      );
    }
    showSnack('price_sent_to_client'.tr());
    onStateChanged();
  }

  static Future<void> acceptRequest({
    required BuildContext context,
    required String requestId,
    required void Function(String) showSnack,
    required VoidCallback onStateChanged,
  }) async {
    AutoAssignService.cancelTimer(requestId);
    await ApiService.put('/api/requests/$requestId', body: {
      'status': kStatusAccepted,
      'acceptedAt': DateTime.now().toIso8601String(),
    });
    final res = await ApiService.get('/api/requests/$requestId');
    final clientId = res.data?['request']?['clientId'] as String?;
    if (clientId != null) {
      await NotificationService.sendNotification(
        toUid: clientId,
        title: '✅ ${'craftsman_accepted'.tr()}',
        body: 'craftsman_accepted_body'.tr(),
        data: {'type': 'accepted', 'requestId': requestId},
      );
    }
    showSnack('request_accepted'.tr());
    onStateChanged();
  }

  static Future<void> rejectRequest({
    required BuildContext context,
    required Map<String, dynamic> data,
    required String requestId,
    required String uid,
    required void Function(String) showSnack,
    required VoidCallback onStateChanged,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _buildGlassDialog(
        context: _,
        title: 'reject_request'.tr(),
        content: 'reject_request_confirm'.tr(),
        confirmText: 'reject'.tr(),
        cancelText: 'cancel'.tr(),
        confirmColor: Colors.red,
      ),
    );
    if (ok != true) return;

    await ApiService.put('/api/requests/$requestId', body: {
      'status': kStatusRejected,
      'rejectedAt': DateTime.now().toIso8601String(),
      'rejectedBy': uid,
    });

    AutoAssignService.cancelTimer(requestId);

    final res = await ApiService.get('/api/requests/$requestId');
    final req = res.data?['request'] as Map<String, dynamic>?;
    if (req != null) {
      await AutoAssignService.assignRequest(
        requestId: requestId,
        service: req['service'] ?? '',
        governorate: req['clientGovernorate'] ?? '',
        clientLat: (req['clientLatitude'] as num?)?.toDouble(),
        clientLng: (req['clientLongitude'] as num?)?.toDouble(),
        clientName: req['clientName'] ?? '',
        clientPhone: req['clientPhone'] ?? '',
        clientId: req['clientId'] ?? '',
        requestDescription: req['notes'] ?? '',
      );
    }

    showSnack('request_rejected'.tr());
    onStateChanged();
  }

  static Future<void> cancelRequest({
    required BuildContext context,
    required Map<String, dynamic> data,
    required String requestId,
    required void Function(String) showSnack,
    required VoidCallback onStateChanged,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _buildGlassDialog(
        context: _,
        title: 'cancel_request'.tr(),
        content: 'cancel_request_confirm'.tr(),
        confirmText: 'cancel'.tr(),
        cancelText: 'no'.tr(),
        confirmColor: Colors.red,
      ),
    );
    if (ok != true) return;

    await ApiService.put('/api/requests/$requestId', body: {
      'status': 'cancelled_by_client',
      'cancelledAt': DateTime.now().toIso8601String(),
    });

    final craftsmanId = data['assignedCraftsmanId'] as String?;
    if (craftsmanId != null) {
      await NotificationService.sendNotification(
        toUid: craftsmanId,
        title: '❌ ${'request_cancelled'.tr()}',
        body: 'request_cancelled_by_client_body'.tr(args: [data['clientName'] ?? '']),
        data: {'type': 'request_cancelled', 'requestId': requestId},
      );
    }

    showSnack('request_cancelled'.tr());
    onStateChanged();
  }

  static Widget _buildGlassDialog({
    required BuildContext context,
    required String title,
    required String content,
    required String confirmText,
    required String cancelText,
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
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(cancelText, style: const TextStyle(color: Colors.white70)),
            ),
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
