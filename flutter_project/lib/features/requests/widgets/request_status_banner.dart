import 'dart:ui' as ui;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';

class RequestStatusBanner extends StatelessWidget {
  final String status;
  const RequestStatusBanner({super.key, required this.status});

  // الألوان لا تتغير باختلاف اللغة
  static const Map<String, Color> colors = {
    kStatusPending:        Colors.grey,
    kStatusNotified:       Colors.orange,
    kStatusAccepted:       Colors.blue,
    'price_proposed':      Colors.teal,
    'payment_pending':     Colors.amber,
    'payment_confirmed':   Colors.green,
    kStatusInProgress:     Colors.deepOrange,
    kStatusDone:           Colors.green,
    kStatusRejected:       Colors.red,
    kStatusNoCraftsman:    Colors.red,
    'cancelled_by_client': Colors.red,
  };

  // تحويل الحالة إلى مفتاح ترجمة
  String _translateStatus(String s) {
    switch (s) {
      case kStatusPending:
        return 'waiting_for_assign';
      case kStatusNotified:
        return 'craftsman_notified';
      case kStatusAccepted:
        return 'craftsman_accepted';
      case 'price_proposed':
        return 'price_proposed';
      case 'payment_pending':
        return 'waiting_for_payment';
      case 'payment_confirmed':
        return 'payment_confirmed';
      case kStatusInProgress:
        return 'in_progress';
      case kStatusDone:
        return 'done';
      case kStatusRejected:
        return 'rejected';
      case kStatusNoCraftsman:
        return 'no_craftsman';
      case 'cancelled_by_client':
        return 'cancelled_by_client';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colors[status] ?? Colors.grey;
    final translated = _translateStatus(status).tr();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          ),
          child: Text(
            translated,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}