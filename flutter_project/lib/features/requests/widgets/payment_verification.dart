import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/myfatoorah_service.dart';

mixin PaymentVerificationMixin {
  String get requestId;
  void showSnack(String message);

  Timer? _paymentPollTimer;
  bool _isCheckingPayment = false;

  /// بدء الاستماع + polling
  void startPollingIfPending() {
    _paymentPollTimer?.cancel();

    // تحميل حالة الطلب الحالية
    _checkCurrentStatus();
  }

  /// التحقق من الحالة الحالية
  Future<void> _checkCurrentStatus() async {
    try {
      final data = await FirestoreService.getRequest(requestId);
      if (data == null) return;

      final status = data['status'] as String?;
      final paymentStatus = data['paymentStatus'] as String?;

      if (paymentStatus == 'paid') {
        if (status == 'payment_pending' || status == 'price_proposed') {
          await FirestoreService.updateRequest(requestId, {
            'status': 'payment_confirmed',
          });
        }
        showSnack('✅ تم تأكيد الدفع بنجاح');
        return;
      }

      if (status == 'payment_pending' || (paymentStatus == 'link_sent' && status != 'payment_confirmed')) {
        _startPaymentPolling();
      }
    } catch (e) {
      debugPrint('❌ _checkCurrentStatus error: $e');
    }
  }

  /// Polling ذكي مع زيادة الفترة تدريجياً
  void _startPaymentPolling() {
    _paymentPollTimer?.cancel();

    int attemptCount = 0;

    _paymentPollTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      attemptCount++;

      if (attemptCount == 6) {
        timer.cancel();
        _paymentPollTimer = Timer.periodic(const Duration(seconds: 30), (timer2) async {
          await verifyPayment();
        });
        return;
      }

      await verifyPayment();

      try {
        final data = await FirestoreService.getRequest(requestId);
        final paymentStatus = data?['paymentStatus'] as String?;
        if (paymentStatus == 'paid' || attemptCount >= 20) {
          timer.cancel();
        }
      } catch (_) {}
    });
  }

  /// التحقق من الدفع
  Future<void> verifyPayment() async {
    if (_isCheckingPayment) return;
    _isCheckingPayment = true;

    try {
      final data = await FirestoreService.getRequest(requestId);
      if (data != null) {
        final paymentStatus = data['paymentStatus'] as String?;
        if (paymentStatus == 'paid') {
          _paymentPollTimer?.cancel();

          final status = data['status'] as String?;
          if (status != 'payment_confirmed' && status != 'in_progress' && status != 'done') {
            await FirestoreService.updateRequest(requestId, {
              'status': 'payment_confirmed',
            });
          }

          showSnack('✅ تم تأكيد الدفع بنجاح');
          _isCheckingPayment = false;
          return;
        }
      }

      final result = await MyFatoorahService.checkPayment(requestId: requestId);

      if (result != null && result['status'] == 'paid') {
        _paymentPollTimer?.cancel();
        showSnack('✅ تم تأكيد الدفع بنجاح');
      } else if (result != null && result['status'] == 'failed') {
        showSnack('❌ فشلت عملية الدفع. يرجى المحاولة مرة أخرى.');
      }
    } catch (e) {
      debugPrint('❌ verifyPayment error: $e');
    }

    _isCheckingPayment = false;
  }

  Future<void> manualCheckPayment() async {
    showSnack('⏳ جاري التحقق من الدفع...');
    await verifyPayment();
  }

  void disposeVerification() {
    _paymentPollTimer?.cancel();
  }
}
