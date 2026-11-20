import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/in_app_notification_service.dart';
import '../models/safe_arrival_trip_model.dart';

/// ==========================================
/// 🔔 Safe Arrival Notification Service
/// ==========================================
/// Responsible only for user-facing in-app notifications related to
/// Safe Arrival lifecycle events.
///
/// Firestore path:
/// users/{uid}/notifications/{notificationId}
///
/// Important:
/// - Does NOT create accidents.
/// - Does NOT create alerts.
/// - Does NOT trigger SOS.
/// - Does NOT show critical accident sounds.
/// - Uses users/{uid}/notifications through InAppNotificationService.
class SafeArrivalNotificationService {
  SafeArrivalNotificationService({
    InAppNotificationService? inAppNotificationService,
  }) : _inAppNotificationService =
           inAppNotificationService ?? InAppNotificationService();

  final InAppNotificationService _inAppNotificationService;

  final Set<String> _sessionDedupKeys = <String>{};

  static const String source = 'safe_arrival';

  Future<bool> notifyStarted({
    required String uid,
    required SafeArrivalTripModel trip,
  }) {
    return _createLifecycleNotification(
      uid: uid,
      trip: trip,
      type: 'safe_arrival_started',
      status: SafeArrivalTripStatus.tracking.value,
      titleAr: 'بدأ تتبع الوصول الآمن',
      titleEn: 'Safe Arrival tracking started',
      bodyAr: _withDestinationAr(
        trip,
        fallback: 'بدأ Guardian 360 متابعة رحلتك حتى تصل بأمان.',
      ),
      bodyEn: _withDestinationEn(
        trip,
        fallback:
            'Guardian 360 started tracking your trip until you arrive safely.',
      ),
      priority: 'normal',
      dedupKey: 'started:${trip.id}',
    );
  }

  Future<bool> notifyPaused({
    required String uid,
    required SafeArrivalTripModel trip,
  }) {
    return _createLifecycleNotification(
      uid: uid,
      trip: trip,
      type: 'safe_arrival_paused',
      status: SafeArrivalTripStatus.paused.value,
      titleAr: 'تم إيقاف التتبع مؤقتًا',
      titleEn: 'Safe Arrival tracking paused',
      bodyAr: _withDestinationAr(
        trip,
        fallback: 'تم إيقاف التتبع مؤقتًا. يمكنك استئنافه عند جاهزيتك.',
      ),
      bodyEn: _withDestinationEn(
        trip,
        fallback: 'Tracking was paused. You can resume it when ready.',
      ),
      priority: 'low',
      dedupKey: 'paused:${trip.id}:${trip.pausedAt?.toIso8601String() ?? ''}',
      allowRepeatedWhenKeyChanges: true,
    );
  }

  Future<bool> notifyResumed({
    required String uid,
    required SafeArrivalTripModel trip,
  }) {
    return _createLifecycleNotification(
      uid: uid,
      trip: trip,
      type: 'safe_arrival_resumed',
      status: SafeArrivalTripStatus.tracking.value,
      titleAr: 'تم استئناف التتبع',
      titleEn: 'Safe Arrival tracking resumed',
      bodyAr: _withDestinationAr(trip, fallback: 'تم استئناف متابعة رحلتك.'),
      bodyEn: _withDestinationEn(
        trip,
        fallback: 'Your trip tracking has resumed.',
      ),
      priority: 'low',
      dedupKey: 'resumed:${trip.id}:${trip.resumedAt?.toIso8601String() ?? ''}',
      allowRepeatedWhenKeyChanges: true,
    );
  }

  Future<bool> notifyNearDestination({
    required String uid,
    required SafeArrivalTripModel trip,
    double? distanceToDestinationMeters,
  }) {
    final distanceTextAr = _formatDistanceAr(distanceToDestinationMeters);
    final distanceTextEn = _formatDistanceEn(distanceToDestinationMeters);

    return _createLifecycleNotification(
      uid: uid,
      trip: trip,
      type: 'safe_arrival_near_destination',
      status: trip.status.value,
      titleAr: 'أنت قريب من وجهتك',
      titleEn: 'You are near your destination',
      bodyAr: distanceTextAr == null
          ? _withDestinationAr(trip, fallback: 'اقتربت من نطاق الوصول الآمن.')
          : _withDestinationAr(
              trip,
              fallback:
                  'اقتربت من نطاق الوصول الآمن. المتبقي: $distanceTextAr.',
            ),
      bodyEn: distanceTextEn == null
          ? _withDestinationEn(
              trip,
              fallback: 'You are close to the Safe Arrival range.',
            )
          : _withDestinationEn(
              trip,
              fallback:
                  'You are close to the Safe Arrival range. Remaining: $distanceTextEn.',
            ),
      priority: 'normal',
      dedupKey: 'near_destination:${trip.id}',
      extraPayload: <String, dynamic>{
        'distanceToDestinationMeters': distanceToDestinationMeters,
      },
    );
  }

  Future<bool> notifyArrived({
    required String uid,
    required SafeArrivalTripModel trip,
  }) {
    return _createLifecycleNotification(
      uid: uid,
      trip: trip,
      type: 'safe_arrival_arrived',
      status: SafeArrivalTripStatus.arrived.value,
      titleAr: 'تم تأكيد الوصول بسلامة',
      titleEn: 'Safe Arrival confirmed',
      bodyAr: _withDestinationAr(trip, fallback: 'تم تسجيل وصولك بأمان.'),
      bodyEn: _withDestinationEn(
        trip,
        fallback: 'Your safe arrival has been confirmed.',
      ),
      priority: 'normal',
      dedupKey: 'arrived:${trip.id}',
    );
  }

  Future<bool> notifyCancelled({
    required String uid,
    required SafeArrivalTripModel trip,
  }) {
    return _createLifecycleNotification(
      uid: uid,
      trip: trip,
      type: 'safe_arrival_cancelled',
      status: SafeArrivalTripStatus.cancelled.value,
      titleAr: 'تم إلغاء رحلة الوصول الآمن',
      titleEn: 'Safe Arrival trip cancelled',
      bodyAr: _withDestinationAr(trip, fallback: 'تم إلغاء متابعة هذه الرحلة.'),
      bodyEn: _withDestinationEn(
        trip,
        fallback: 'Tracking for this trip has been cancelled.',
      ),
      priority: 'low',
      dedupKey: 'cancelled:${trip.id}',
    );
  }

  Future<bool> notifyDanger({
    required String uid,
    required SafeArrivalTripModel trip,
    String? reasonCode,
  }) {
    final safeReason = _cleanText(reasonCode ?? '');

    return _createLifecycleNotification(
      uid: uid,
      trip: trip,
      type: 'safe_arrival_danger',
      status: SafeArrivalTripStatus.danger.value,
      titleAr: 'تنبيه مهم في رحلة الوصول الآمن',
      titleEn: 'Important Safe Arrival alert',
      bodyAr: _withDestinationAr(
        trip,
        fallback:
            'تحتاج هذه الرحلة إلى مراجعة. تحقق من حالتك أو قم بإلغاء التنبيه إذا كنت بخير.',
      ),
      bodyEn: _withDestinationEn(
        trip,
        fallback:
            'This trip needs attention. Check your status or dismiss the alert if you are safe.',
      ),
      priority: 'critical',
      dedupKey: 'danger:${trip.id}',
      extraPayload: <String, dynamic>{
        'reasonCode': safeReason.isEmpty ? null : safeReason,
      },
    );
  }

  void clearSessionDedupCache() {
    _sessionDedupKeys.clear();
  }

  Future<bool> _createLifecycleNotification({
    required String uid,
    required SafeArrivalTripModel trip,
    required String type,
    required String status,
    required String titleAr,
    required String titleEn,
    required String bodyAr,
    required String bodyEn,
    required String priority,
    required String dedupKey,
    bool allowRepeatedWhenKeyChanges = false,
    Map<String, dynamic>? extraPayload,
  }) async {
    final safeUid = _cleanText(uid);
    final safeTripId = _cleanText(trip.id);

    if (safeUid.isEmpty || safeTripId.isEmpty) {
      debugPrint(
        '⚠️ SafeArrivalNotificationService: skipped notification, missing uid or tripId',
      );
      return false;
    }

    final effectiveDedupKey = allowRepeatedWhenKeyChanges
        ? '$type:$dedupKey'
        : '$type:$safeTripId';

    if (_sessionDedupKeys.contains(effectiveDedupKey)) {
      return true;
    }

    try {
      final success = await _inAppNotificationService.createNotification(
        uid: safeUid,
        type: type,
        titleAr: titleAr,
        titleEn: titleEn,
        bodyAr: bodyAr,
        bodyEn: bodyEn,
        priority: priority,
        source: source,
        payload: <String, dynamic>{
          'tripId': safeTripId,
          'status': status,
          'destinationName': trip.destination?.displayName,
          'destinationAddress': trip.destination?.displayAddress,
          'distanceToDestinationMeters': trip.distanceToDestinationMeters,
          'actualDistanceMeters': trip.actualDistanceMeters,
          'estimatedArrivalAt': trip.estimatedArrivalAt,
          'startedAt': trip.startedAt,
          'arrivedAt': trip.arrivedAt,
          'cancelledAt': trip.cancelledAt,
          'dangerTriggeredAt': trip.dangerTriggeredAt,
          'pausedAt': trip.pausedAt,
          'resumedAt': trip.resumedAt,
          'manualFinishedAt': trip.manualFinishedAt,
          ...?extraPayload,
        },
      );

      if (!success) {
        debugPrint(
          '⚠️ SafeArrivalNotificationService: failed to store type=$type',
        );
        return false;
      }

      _sessionDedupKeys.add(effectiveDedupKey);
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalNotificationService: notification failed - $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  static String _withDestinationAr(
    SafeArrivalTripModel trip, {
    required String fallback,
  }) {
    final destination = _cleanText(trip.destination?.displayName ?? '');

    if (destination.isEmpty) return fallback;

    return '$fallback\nالوجهة: $destination';
  }

  static String _withDestinationEn(
    SafeArrivalTripModel trip, {
    required String fallback,
  }) {
    final destination = _cleanText(trip.destination?.displayName ?? '');

    if (destination.isEmpty) return fallback;

    return '$fallback\nDestination: $destination';
  }

  static String? _formatDistanceAr(double? meters) {
    if (meters == null || meters.isNaN || meters.isInfinite || meters < 0) {
      return null;
    }

    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} م';
    }

    return '${(meters / 1000).toStringAsFixed(1)} كم';
  }

  static String? _formatDistanceEn(double? meters) {
    if (meters == null || meters.isNaN || meters.isInfinite || meters < 0) {
      return null;
    }

    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static String _cleanText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
}
