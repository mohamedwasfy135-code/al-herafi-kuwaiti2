import 'dart:async';
import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../utils/location_utils.dart';
import 'firestore_service.dart';
import 'notification_service.dart';
import 'whatsapp_service.dart';
import 'ai_request_intake_service.dart';

class AutoAssignService {
  AutoAssignService._();

  static final Map<String, Timer> _activeTimers = {};

  // ── حساب النقاط الأساسي (بدون تغيير) ──────────────────────
  static double _calcScore({
    required double rating,
    required double distanceKm,
    required int totalJobs,
    int maxJobs = kMaxJobsForScore,
  }) {
    final ratingScore    = (rating / 5.0) * 50;
    final proximityScore = (1.0 - (distanceKm.clamp(0, kMaxDistanceKm) / kMaxDistanceKm)) * 30;
    final jobsScore      = (totalJobs.clamp(0, maxJobs) / maxJobs) * 20;
    return ratingScore + proximityScore + jobsScore;
  }

  // ── نقاط التطابق الذكي مع بصمة الحرفي (بدون تغيير) ────────────
  static double _calcAiMatchScore({
    required Map<String, dynamic>? craftsmanTraits,
    required String urgency,
    required String? aiNotes,
  }) {
    if (craftsmanTraits == null) return 0;

    double score = 0;

    final speed = craftsmanTraits['speed'] as String?;
    if (urgency == 'urgent' && speed == 'fast') score += 15;
    if (urgency == 'urgent' && speed == 'slow') score -= 5;

    final quality = craftsmanTraits['quality'] as String?;
    if (aiNotes != null && aiNotes.contains('دقة') && quality == 'excellent') score += 10;

    final politeness = craftsmanTraits['politeness'] as String?;
    if (politeness == 'friendly') score += 5;

    final punctuality = craftsmanTraits['punctuality'] as String?;
    if (punctuality == 'on_time') score += 5;
    if (punctuality == 'often_late') score -= 10;

    return score;
  }

  // ── الإسناد الرئيسي (تعديل: الخدمة الأصلية فقط، بدون تصحيح) ─────
  static Future<void> assignRequest({
    required String requestId,
    required String service,
    required String governorate,
    double? clientLat,
    double? clientLng,
    required String clientName,
    required String clientPhone,
    required String clientId,
    String? requestDescription,       // لم يعد يستخدم لتغيير الخدمة
    RequestIntakeResult? preAnalyzed, // لم يعد يستخدم لتغيير الخدمة
  }) async {
    try {
      debugPrint('=== AutoAssign START: $requestId ===');
      debugPrint('Service: $service | Governorate: $governorate');

      // ✅ نستخدم الخدمة التي اختارها العميل فقط، بدون أي تغيير
      final String effectiveService = service;

      // يمكننا الاحتفاظ بتحليل AI للاستعجال والملاحظات فقط (اختياري)
      String urgency = 'normal';
      String? aiNotes;
      if (preAnalyzed != null) {
        urgency = preAnalyzed.urgency;
        aiNotes = preAnalyzed.notes;
      } else if (requestDescription != null && requestDescription.trim().isNotEmpty) {
        final intake = await AiRequestIntakeService.analyze(
          description: requestDescription,
          userSelectedService: service,
        );
        if (intake != null) {
          urgency = intake.urgency;
          aiNotes = intake.notes;
        }
      }

      // ── 2. جلب الحرفيين المتاحين ─────────────────────────
      const String allRegions = 'كل المناطق';
      const String allKuwait = 'كل مناطق الكويت';

      final Map<String, Map<String, dynamic>> mergedMap = {};

      if (governorate == allRegions) {
        final allDocs = await FirestoreService.getCraftsmen(
          job: effectiveService,
          isAvailable: true,
        );
        for (final d in allDocs) {
          final id = d['id']?.toString() ?? '';
          if (id.isNotEmpty) mergedMap[id] = d;
        }
      } else {
        final localDocs = await FirestoreService.getCraftsmen(
          job: effectiveService,
          governorate: governorate,
          isAvailable: true,
        );
        for (final d in localDocs) {
          final id = d['id']?.toString() ?? '';
          if (id.isNotEmpty) mergedMap[id] = d;
        }

        final allKuwaitDocs = await FirestoreService.getCraftsmen(
          job: effectiveService,
          governorate: allKuwait,
          isAvailable: true,
        );
        for (final d in allKuwaitDocs) {
          final id = d['id']?.toString() ?? '';
          if (id.isNotEmpty && !mergedMap.containsKey(id)) {
            mergedMap[id] = d;
          }
        }
      }

      final allDocs = mergedMap.values.toList();
      debugPrint('Found craftsmen: ${allDocs.length}');

      if (allDocs.isEmpty) {
        await _handleNoCraftsman(
          requestId: requestId,
          service: effectiveService,
          governorate: governorate,
          clientId: clientId,
        );
        return;
      }

      // ── 3. ترتيب المرشحين بالنقاط ────────────────────────
      final scored = allDocs.map((d) {
        final rating = (d['rating'] as num?)?.toDouble() ?? 3.0;
        final jobs   = (d['totalJobs'] as num?)?.toInt() ?? 0;
        double dist  = 10.0;

        final craftsmanGovernorate = d['governorate'] as String? ?? '';
        final isAllKuwait = (craftsmanGovernorate == allKuwait);

        if (!isAllKuwait &&
            clientLat != null &&
            clientLng != null &&
            d['latitude'] != null &&
            d['longitude'] != null) {
          dist = LocationUtils.distanceKm(
            clientLat, clientLng,
            (d['latitude'] as num).toDouble(),
            (d['longitude'] as num).toDouble(),
          );
        }

        final baseScore = _calcScore(rating: rating, distanceKm: dist, totalJobs: jobs);
        final aiTraits = d['aiTraits'] as Map<String, dynamic>?;
        final aiMatchScore = _calcAiMatchScore(
          craftsmanTraits: aiTraits,
          urgency: urgency,
          aiNotes: aiNotes,
        );
        final finalScore = baseScore + aiMatchScore;

        return {'data': d, 'score': finalScore, 'dist': dist};
      }).toList()
        ..sort((a, b) =>
            (b['score'] as double).compareTo(a['score'] as double));

      // ── 4. الإسناد للمرشح الأول ─────────────────────────
      await _assignToCandidate(
        requestId: requestId,
        service: effectiveService,
        governorate: governorate,
        clientName: clientName,
        clientPhone: clientPhone,
        clientId: clientId,
        scored: scored,
        candidateIndex: 0,
      );

      // ── 5. تحديث الطلب بمعلومات AI الإضافية (اختياري) ──
      try {
        await FirestoreService.updateRequest(requestId, {
          'aiUrgency': urgency,
          'aiNotes': aiNotes ?? '',
          // ملاحظة: لا نضبط correctedService أبداً
        });
      } catch (e) {
        debugPrint('Failed to save AI metadata: $e');
      }
    } catch (e, st) {
      debugPrint('AutoAssign error: $e\n$st');
      try {
        await FirestoreService.updateRequest(requestId, {
          'status': kStatusNeedsAdmin,
          'adminNote': 'خطأ في الإسناد التلقائي: $e',
        });
      } catch (_) {}
    }
  }

  // ── باقي الدوال ─────────────────────────
  static Future<void> _assignToCandidate({
    required String requestId,
    required String service,
    required String governorate,
    required String clientName,
    required String clientPhone,
    required String clientId,
    required List<Map<String, dynamic>> scored,
    required int candidateIndex,
  }) async {
    if (candidateIndex >= scored.length) {
      debugPrint('No more candidates for $requestId → needs_admin');
      await FirestoreService.updateRequest(requestId, {
        'status': kStatusNeedsAdmin,
        'adminNote': 'لم يستجب أي حرفي — يحتاج تدخل يدوي',
      });
      return;
    }

    final best     = scored[candidateIndex];
    final bestData = best['data'] as Map<String, dynamic>;

    final craftsmanId    = bestData['id']?.toString() ?? '';
    final craftsmanName  = (bestData['name'] as String?) ?? 'حرفي';
    final craftsmanPhone = (bestData['phone'] as String?) ?? '';

    debugPrint('Assigning $requestId → craftsman: $craftsmanId ($craftsmanName)');

    await FirestoreService.updateRequest(requestId, {
      'status'               : kStatusNotified,
      'assignedCraftsmanId'  : craftsmanId,
      'assignedCraftsmanName': craftsmanName,
      'craftsmanId'          : craftsmanId,
      'craftsmanName'        : craftsmanName,
      'assignedAt'           : DateTime.now().toIso8601String(),
      'autoAssigned'         : true,
      'craftsmanScore'       : (best['score'] as double).toStringAsFixed(1),
      'distanceKm'           : (best['dist'] as double).toStringAsFixed(2),
      'candidateIndex'       : candidateIndex,
    });

    debugPrint('✅ Request $requestId assigned to $craftsmanId');

    await NotificationService.sendNotification(
      toUid: craftsmanId,
      title: '🔔 طلب جديد!',
      body: 'طلب $service من $clientName — $governorate',
      data: {
        'type'     : 'new_request',
        'requestId': requestId,
        'service'  : service,
      },
    );

    await NotificationService.sendNotification(
      toUid: 'admin_panel',
      title: '📋 طلب جديد تم إسناده',
      body: '$service — $clientName → $craftsmanName',
      data: {
        'type'     : 'request_assigned',
        'requestId': requestId,
      },
    );

    if (craftsmanPhone.isNotEmpty) {
      await WhatsAppService.sendToNumber(
        phone: craftsmanPhone,
        message:
            'مرحبا $craftsmanName 👋\n'
            'لديك طلب جديد 🔔\n'
            'الخدمة: $service\n'
            'العميل: $clientName\n'
            'الجوال: $clientPhone\n'
            'المنطقة: $governorate\n'
            'رقم الطلب: $requestId',
      );
    }

    _cancelTimer(requestId);
    _activeTimers[requestId] = Timer(
      const Duration(minutes: kAutoAssignTimeoutMinutes),
      () => _onTimeout(
        requestId     : requestId,
        service       : service,
        governorate   : governorate,
        clientName    : clientName,
        clientPhone   : clientPhone,
        clientId      : clientId,
        scored        : scored,
        candidateIndex: candidateIndex,
      ),
    );
    debugPrint('Timer set for $requestId — ${kAutoAssignTimeoutMinutes}min');
  }

  static Future<void> _onTimeout({
    required String requestId,
    required String service,
    required String governorate,
    required String clientName,
    required String clientPhone,
    required String clientId,
    required List<Map<String, dynamic>> scored,
    required int candidateIndex,
  }) async {
    _activeTimers.remove(requestId);
    debugPrint('⏰ Timeout for $requestId — trying next candidate');

    try {
      final req = await FirestoreService.getRequest(requestId);
      if (req == null) return;

      final currentStatus = req['status'] as String?;

      if (currentStatus == kStatusNotified) {
        await _assignToCandidate(
          requestId     : requestId,
          service       : service,
          governorate   : governorate,
          clientName    : clientName,
          clientPhone   : clientPhone,
          clientId      : clientId,
          scored        : scored,
          candidateIndex: candidateIndex + 1,
        );
      } else {
        debugPrint('Request $requestId already handled (status: $currentStatus) — skip');
      }
    } catch (e) {
      debugPrint('AutoAssign timeout error: $e');
    }
  }

  static Future<void> _handleNoCraftsman({
    required String requestId,
    required String service,
    required String governorate,
    required String clientId,
  }) async {
    debugPrint('No craftsman available for $service in $governorate');

    await FirestoreService.updateRequest(requestId, {
      'status': kStatusNoCraftsman,
      'note'  : 'لا يوجد حرفي $service متاح في $governorate حالياً',
    });

    await NotificationService.sendNotification(
      toUid: clientId,
      title: '⏳ جاري البحث عن حرفي',
      body : 'لا يوجد $service متاح الآن في $governorate. سنتواصل معك فور توفر أحد.',
      data : {'type': 'no_craftsman', 'requestId': requestId},
    );
  }

  static void cancelTimer(String requestId) => _cancelTimer(requestId);

  static void _cancelTimer(String requestId) {
    _activeTimers[requestId]?.cancel();
    _activeTimers.remove(requestId);
  }

  static void cancelAllTimers() {
    for (final t in _activeTimers.values) {
      t.cancel();
    }
    _activeTimers.clear();
  }
}
