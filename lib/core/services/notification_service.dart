import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_thresholds.dart';
import '../models/notification_model.dart';
import 'firebase_messaging_service.dart';
import 'in_app_notification_service.dart';

/// ==========================================
/// 🔔 Notification Service - Guardian 360
/// ==========================================
/// مسؤول عن:
/// - تهيئة Firebase Messaging.
/// - تحديث FCM token للمستخدم.
/// - عرض إشعارات محلية للمستخدم.
/// - إشعار انخفاض البطارية.
/// - إنشاء إشعارات داخل التطبيق best-effort في users/{uid}/notifications.
///
/// غير مسؤول عن:
/// - إنشاء بلاغات Firestore الرسمية.
/// - إنشاء accidents أو alerts.
/// - إرسال Push للداشبورد مباشرة من التطبيق.
/// - حساب شدة الحادث.
///
/// ملاحظة مهمة:
/// البلاغ الحقيقي يجب أن يمر من:
/// SOSViewModel → FirebaseService.reportAccident() → accidents collection
class NotificationService {
  NotificationService({
    FirebaseMessagingService? messagingService,
    InAppNotificationService? inAppNotificationService,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    bool storeAccidentNotificationLog = false,
  }) : _ownsMessagingService = messagingService == null,
       _messagingService = messagingService ?? FirebaseMessagingService(),
       _inAppNotificationService =
           inAppNotificationService ?? InAppNotificationService(),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storeAccidentNotificationLog = storeAccidentNotificationLog;

  final FirebaseMessagingService _messagingService;
  final InAppNotificationService _inAppNotificationService;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  final bool _ownsMessagingService;

  /// Disabled by default to avoid creating a third emergency-like collection
  /// before the user countdown is completed.
  ///
  /// Keep false unless we intentionally need a legacy diagnostic log.
  final bool _storeAccidentNotificationLog;

  static const String _usersCollection = 'users';
  static const String _accidentNotificationsCollection =
      'accident_notifications';

  static const Duration _initTimeout = Duration(seconds: 10);
  static const Duration _tokenTimeout = Duration(seconds: 8);
  static const Duration _firestoreTimeout = Duration(seconds: 8);
  static const Duration _notificationTimeout = Duration(seconds: 6);
  static const Duration _inAppNotificationTimeout = Duration(seconds: 6);

  bool _isInitialized = false;
  bool _isDisposed = false;

  // ==========================================
  // 🚀 INITIALIZATION
  // ==========================================

  Future<void> initialize() async {
    if (_isDisposed) return;

    if (_isInitialized) {
      debugPrint('ℹ️ NotificationService: Already initialized');
      await _updateFCMToken();
      return;
    }

    try {
      final result = await _messagingService
          .initialize(
            onTokenRefresh: (token) {
              final safeToken = _trimToNull(token);

              if (safeToken != null) {
                unawaited(_storeFCMToken(safeToken));
              }
            },
            onLocalNotificationTap: _handleLocalNotificationTap,
          )
          .timeout(_initTimeout);

      if (result.isSuccess) {
        _isInitialized = true;

        debugPrint('✅ NotificationService: Initialized successfully');
        await _updateFCMToken();
      } else {
        debugPrint(
          '⚠️ NotificationService: Initialization failed - ${result.error}',
        );
      }
    } on TimeoutException {
      debugPrint('⏱️ NotificationService: Initialization timeout');
    } catch (e, stackTrace) {
      debugPrint('❌ NotificationService: Initialization error - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _handleLocalNotificationTap(Map<String, dynamic> payload) {
    if (_isDisposed) return;

    final type = payload['type']?.toString();

    debugPrint('👆 NotificationService: Local notification tapped');
    debugPrint('   Type: ${type ?? "unknown"}');
    debugPrint('   Payload: $payload');
  }

  Future<void> _updateFCMToken() async {
    try {
      final tokenResult = await _messagingService.getToken().timeout(
        _tokenTimeout,
      );

      if (!tokenResult.isSuccess || tokenResult.data == null) {
        debugPrint(
          '⚠️ NotificationService: Failed to obtain FCM token - ${tokenResult.error}',
        );
        return;
      }

      final token = tokenResult.data!.trim();

      if (token.isEmpty) {
        debugPrint('⚠️ NotificationService: Empty FCM token ignored');
        return;
      }

      await _storeFCMToken(token);
    } on TimeoutException {
      debugPrint('⏱️ NotificationService: FCM token update timeout');
    } catch (e, stackTrace) {
      debugPrint('❌ NotificationService: Failed to update FCM token - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _storeFCMToken(String token) async {
    if (_isDisposed) return;

    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      debugPrint(
        '⚠️ NotificationService: No authenticated user, token not stored',
      );
      return;
    }

    final safeToken = token.trim();

    if (safeToken.isEmpty) {
      debugPrint('⚠️ NotificationService: Empty FCM token ignored');
      return;
    }

    try {
      await _firestore
          .collection(_usersCollection)
          .doc(currentUser.uid)
          .set({
            'fcmToken': safeToken,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(_firestoreTimeout);

      debugPrint(
        '✅ NotificationService: FCM token stored for user ${currentUser.uid} '
        '(${_shortToken(safeToken)})',
      );
    } on TimeoutException {
      debugPrint('⏱️ NotificationService: Store FCM token timeout');
    } catch (e, stackTrace) {
      debugPrint('❌ NotificationService: Failed to store FCM token - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // 🚨 ACCIDENT NOTIFICATION
  // ==========================================

  /// Local pre-alert notification for the user.
  ///
  /// This is intentionally NOT the official emergency report.
  /// The official report is created only after SOS countdown finishes.
  Future<void> sendAccidentNotification({
    required String severityLevel,
    required String userName,
    required double latitude,
    required double longitude,
    String? userId,
    String? eventId,
    bool? storeNotificationLog,
    String? languageCode,
  }) async {
    if (_isDisposed) return;

    try {
      final safeSeverity = AppThresholds.normalizeSeverityLevel(severityLevel);

      if (safeSeverity == AppThresholds.severityIgnored) {
        debugPrint(
          'ℹ️ NotificationService: Ignored severity notification skipped',
        );
        return;
      }

      if (!_hasValidCoordinates(latitude, longitude)) {
        debugPrint(
          '⚠️ NotificationService: Accident notification skipped due to invalid coordinates',
        );
        return;
      }

      final safeUserName = _firstNotEmpty([userName, 'Guardian User']);
      final safeUserId = _trimToNull(userId) ?? _auth.currentUser?.uid;
      final safeEventId = _trimToNull(eventId);
      final resolvedLanguageCode = _resolveLanguageCode(languageCode);

      debugPrint('🚨 NotificationService: Sending local accident notification');
      debugPrint('   Severity: $safeSeverity');
      debugPrint('   User: $safeUserName');
      debugPrint('   Location: ($latitude, $longitude)');

      final title = _getLocalizedSeverityTitle(
        safeSeverity,
        resolvedLanguageCode,
      );

      final body = _getLocalizedAccidentBody(
        userName: safeUserName,
        latitude: latitude,
        longitude: longitude,
        languageCode: resolvedLanguageCode,
      );

      final payload = _removeNullValues({
        'type': 'accident_pre_alert',
        'severityLevel': safeSeverity,
        'severityDisplay': AppThresholds.severityDisplayArabic(safeSeverity),
        'userName': safeUserName,
        'latitude': latitude,
        'longitude': longitude,
        'emergencySource': 'auto_detection',
        'alertSource': 'auto_detection',
        'reportType': 'auto_detection',
        'isOfficialEmergencyReport': false,
        'isPreAlert': true,
        'timestamp': DateTime.now().toIso8601String(),
        'userId': safeUserId,
        'eventId': safeEventId,
      });

      final notificationResult = await _messagingService
          .showCustomNotification(
            title: title,
            body: body,
            payload: jsonEncode(payload),
            isAccident: true,
          )
          .timeout(_notificationTimeout);

      if (notificationResult.isFailure) {
        debugPrint(
          '⚠️ NotificationService: Local accident notification failed - ${notificationResult.error}',
        );
        return;
      }

      final shouldStoreLog =
          storeNotificationLog ?? _storeAccidentNotificationLog;

      if (shouldStoreLog) {
        await _storeAccidentNotification(
          severityLevel: safeSeverity,
          userName: safeUserName,
          latitude: latitude,
          longitude: longitude,
          userId: safeUserId,
          eventId: safeEventId,
        );
      }

      debugPrint(
        '✅ NotificationService: Local accident notification shown successfully',
      );
    } on TimeoutException {
      debugPrint('⏱️ NotificationService: Accident notification timeout');
    } catch (e, stackTrace) {
      debugPrint(
        '❌ NotificationService: Failed to send accident notification - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _getLocalizedSeverityTitle(String severityLevel, String languageCode) {
    final isArabic = languageCode.toLowerCase().startsWith('ar');

    switch (AppThresholds.normalizeSeverityLevel(severityLevel)) {
      case AppThresholds.severityLow:
        return isArabic
            ? 'تنبيه: تم رصد اصطدام بسيط'
            : 'Alert: Minor impact detected';

      case AppThresholds.severityMedium:
        return isArabic
            ? 'تنبيه: تم رصد حادث متوسط'
            : 'Alert: Moderate accident detected';

      case AppThresholds.severityHigh:
        return isArabic
            ? 'تنبيه: تم رصد حادث خطير'
            : 'Alert: Severe accident detected';

      case AppThresholds.severityCritical:
        return isArabic
            ? 'تنبيه: تم رصد حادث حرج!'
            : 'Critical alert: Accident detected!';

      case AppThresholds.severityIgnored:
      default:
        return isArabic ? 'تنبيه: تم رصد حادث' : 'Alert: Accident detected';
    }
  }

  String _getLocalizedAccidentBody({
    required String userName,
    required double latitude,
    required double longitude,
    required String languageCode,
  }) {
    final isArabic = languageCode.toLowerCase().startsWith('ar');
    final lat = latitude.toStringAsFixed(6);
    final lng = longitude.toStringAsFixed(6);

    if (isArabic) {
      return 'المستخدم: $userName\nالموقع: $lat, $lng';
    }

    return 'User: $userName\nLocation: $lat, $lng';
  }

  /// Legacy diagnostic log only.
  ///
  /// This must not be used by the dashboard as the source of truth,
  /// because it is created before the SOS countdown is completed.
  Future<void> _storeAccidentNotification({
    required String severityLevel,
    required String userName,
    required double latitude,
    required double longitude,
    String? userId,
    String? eventId,
  }) async {
    try {
      final logData = _removeNullValues({
        'type': 'local_pre_alert_log',
        'severityLevel': AppThresholds.normalizeSeverityLevel(severityLevel),
        'severityDisplay': AppThresholds.severityDisplayArabic(severityLevel),
        'userName': userName,
        'latitude': latitude,
        'longitude': longitude,
        'location': GeoPoint(latitude, longitude),
        'userId': _trimToNull(userId),
        'eventId': _trimToNull(eventId),
        'emergencySource': 'auto_detection',
        'alertSource': 'auto_detection',
        'reportType': 'auto_detection',
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'logged',
        'isOfficialEmergencyReport': false,
        'isPreAlert': true,
      });

      await _firestore
          .collection(_accidentNotificationsCollection)
          .add(logData)
          .timeout(_firestoreTimeout);

      debugPrint('✅ NotificationService: Diagnostic notification log stored');
    } on TimeoutException {
      debugPrint('⏱️ NotificationService: Notification log timeout');
    } catch (e, stackTrace) {
      debugPrint(
        '❌ NotificationService: Failed to store notification log - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // 🔋 BATTERY ALERT
  // ==========================================

  Future<void> sendBatteryLowNotification({String? languageCode}) async {
    if (_isDisposed) return;

    try {
      debugPrint('🔋 NotificationService: Sending battery low notification');

      final resolvedLanguageCode = _resolveLanguageCode(languageCode);
      final isArabic = resolvedLanguageCode.toLowerCase().startsWith('ar');

      const titleAr = 'تحذير: البطارية منخفضة';
      const titleEn = 'Warning: Low battery';
      const bodyAr = 'قد يتوقف نظام Guardian 360 إذا انخفضت البطارية أكثر.';
      const bodyEn = 'Guardian 360 may stop if the battery gets too low.';

      final title = isArabic ? titleAr : titleEn;
      final body = isArabic ? bodyAr : bodyEn;

      final payload = {
        'type': 'battery_low',
        'isOfficialEmergencyReport': false,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final result = await _messagingService
          .showCustomNotification(
            title: title,
            body: body,
            payload: jsonEncode(payload),
            isAccident: false,
          )
          .timeout(_notificationTimeout);

      if (result.isFailure) {
        debugPrint(
          '⚠️ NotificationService: Battery notification failed - ${result.error}',
        );
        return;
      }

      unawaited(
        _storeInAppNotification(
          type: 'battery_low',
          titleAr: titleAr,
          titleEn: titleEn,
          bodyAr: bodyAr,
          bodyEn: bodyEn,
          priority: 'high',
          source: 'battery_monitor',
          payload: payload,
        ),
      );

      debugPrint('✅ NotificationService: Battery low notification sent');
    } on TimeoutException {
      debugPrint('⏱️ NotificationService: Battery notification timeout');
    } catch (e, stackTrace) {
      debugPrint(
        '❌ NotificationService: Failed to send battery notification - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // 📡 OFFLINE SYNC CONFIRMATION
  // ==========================================

  /// إشعار تأكيد هادئ بعد نجاح مزامنة البلاغات المخزنة محلياً.
  ///
  /// مهم:
  /// - هذا ليس إنذار حادث جديد.
  /// - لا ينشئ accidents أو alerts.
  /// - لا يستخدم قناة accident critical.
  /// - الهدف فقط طمأنة المستخدم أن البلاغ الذي حُفظ محلياً تم إرساله.
  Future<void> sendOfflineSyncSuccessNotification({
    required int syncedReportsCount,
    int remainingReportsCount = 0,
    String? languageCode,
  }) async {
    if (_isDisposed) return;
    if (syncedReportsCount <= 0) return;

    final safeRemainingReportsCount = remainingReportsCount < 0
        ? 0
        : remainingReportsCount;

    try {
      final resolvedLanguageCode = _resolveLanguageCode(languageCode);
      final isArabic = resolvedLanguageCode.toLowerCase().startsWith('ar');

      final titleAr = syncedReportsCount == 1
          ? 'تم إرسال البلاغ المخزن'
          : 'تم إرسال البلاغات المخزنة';

      final titleEn = syncedReportsCount == 1
          ? 'Stored report sent'
          : 'Stored reports sent';

      final bodyAr = safeRemainingReportsCount > 0
          ? 'تم إرسال $syncedReportsCount بلاغ، وما يزال $safeRemainingReportsCount بانتظار المحاولة لاحقاً.'
          : syncedReportsCount == 1
          ? 'تمت مزامنة بلاغ الطوارئ مع قاعدة البيانات بنجاح.'
          : 'تمت مزامنة $syncedReportsCount بلاغات طوارئ مع قاعدة البيانات بنجاح.';

      final bodyEn = safeRemainingReportsCount > 0
          ? '$syncedReportsCount report(s) were sent. $safeRemainingReportsCount still pending.'
          : syncedReportsCount == 1
          ? 'Your emergency report was synced successfully.'
          : '$syncedReportsCount emergency reports were synced successfully.';

      final title = isArabic ? titleAr : titleEn;
      final body = isArabic ? bodyAr : bodyEn;

      final payload = _removeNullValues({
        'type': 'offline_sync_success',
        'syncedReportsCount': syncedReportsCount,
        'remainingReportsCount': safeRemainingReportsCount,
        'isOfficialEmergencyReport': false,
        'isSyncConfirmation': true,
        'timestamp': DateTime.now().toIso8601String(),
        'userId': _auth.currentUser?.uid,
      });

      final result = await _messagingService
          .showCustomNotification(
            title: title,
            body: body,
            payload: jsonEncode(payload),
            isAccident: false,
          )
          .timeout(_notificationTimeout);

      if (result.isFailure) {
        debugPrint(
          '⚠️ NotificationService: Offline sync notification failed - ${result.error}',
        );
        return;
      }

      unawaited(
        _storeInAppNotification(
          type: 'offline_sync_success',
          titleAr: titleAr,
          titleEn: titleEn,
          bodyAr: bodyAr,
          bodyEn: bodyEn,
          priority: 'normal',
          source: 'offline_sync',
          payload: payload,
        ),
      );

      debugPrint(
        '✅ NotificationService: Offline sync success notification shown '
        '(synced: $syncedReportsCount, remaining: $safeRemainingReportsCount)',
      );
    } on TimeoutException {
      debugPrint('⏱️ NotificationService: Offline sync notification timeout');
    } catch (e, stackTrace) {
      debugPrint(
        '❌ NotificationService: Failed to show offline sync notification - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // 🚗 KROKA REPORT NOTIFICATIONS
  // ==========================================

  /// In-app confirmation after a Smart Kroka report is saved.
  ///
  /// مهم:
  /// - لا يعرض Push محلي.
  /// - لا ينشئ accidents.
  /// - لا ينشئ alerts.
  /// - لا يستخدم relatedAccidentId.
  /// - فشل الإشعار لا يعني فشل تقرير الكروكة.
  Future<void> sendKrokaReportSavedNotification({
    required String reportId,
    required String referenceCode,
    String? languageCode,
  }) async {
    if (_isDisposed) return;

    final safeReportId = _trimToNull(reportId);
    final safeReferenceCode = _trimToNull(referenceCode);

    if (safeReportId == null || safeReferenceCode == null) {
      debugPrint(
        '⚠️ NotificationService: Kroka notification skipped - missing report id/reference',
      );
      return;
    }

    try {
      final resolvedLanguageCode = _resolveLanguageCode(languageCode);
      final isArabic = resolvedLanguageCode.toLowerCase().startsWith('ar');

      const titleAr = 'تم حفظ تقرير الكروكة';
      const titleEn = 'Kroka report saved';

      final bodyAr =
          'تم إنشاء تقرير الحادث المروري البسيط برقم مرجعي: $safeReferenceCode.';
      final bodyEn =
          'Your minor accident report was created with reference: $safeReferenceCode.';

      final payload = _removeNullValues({
        'type': NotificationModel.typeKrokaReportSaved,
        'krokaReportId': safeReportId,
        'referenceCode': safeReferenceCode,
        'source': 'kroka',
        'reportType': 'minor_traffic_accident',
        'isOfficialEmergencyReport': false,
        'isEmergencyNotification': false,
        'timestamp': DateTime.now().toIso8601String(),
        'userId': _auth.currentUser?.uid,
      });

      await _storeInAppNotification(
        type: NotificationModel.typeKrokaReportSaved,
        titleAr: titleAr,
        titleEn: titleEn,
        bodyAr: bodyAr,
        bodyEn: bodyEn,
        priority: 'normal',
        source: 'kroka',
        payload: payload,
      );

      debugPrint(
        '✅ NotificationService: Kroka saved in-app notification requested '
        '(reportId=$safeReportId, reference=$safeReferenceCode, lang=${isArabic ? "ar" : "en"})',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '⚠️ NotificationService: Failed to request Kroka saved notification - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // 🎫 TOKEN MANAGEMENT
  // ==========================================

  Future<String?> getFCMToken() async {
    if (_isDisposed) return null;

    try {
      final result = await _messagingService.getToken().timeout(_tokenTimeout);

      if (!result.isSuccess) {
        debugPrint(
          '⚠️ NotificationService: Failed to get FCM token - ${result.error}',
        );
        return null;
      }

      return _trimToNull(result.data);
    } on TimeoutException {
      debugPrint('⏱️ NotificationService: Get FCM token timeout');
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ NotificationService: Failed to get FCM token - $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> refreshFCMToken() async {
    await _updateFCMToken();
  }

  // ==========================================
  // 🔔 IN-APP NOTIFICATION CENTER
  // ==========================================

  Future<void> _storeInAppNotification({
    required String type,
    required String titleAr,
    required String titleEn,
    required String bodyAr,
    required String bodyEn,
    required String priority,
    required String source,
    Map<String, dynamic>? payload,
    String? relatedAccidentId,
  }) async {
    if (_isDisposed) return;

    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      debugPrint(
        '⚠️ NotificationService: In-app notification skipped - no authenticated user',
      );
      return;
    }

    try {
      final success = await _inAppNotificationService
          .createNotification(
            uid: currentUser.uid,
            type: type,
            titleAr: titleAr,
            titleEn: titleEn,
            bodyAr: bodyAr,
            bodyEn: bodyEn,
            priority: priority,
            source: source,
            relatedAccidentId: relatedAccidentId,
            payload: _removeNullValues({
              ...?payload,
              'isUserFacingNotification': true,
              'isOfficialEmergencyReport': false,
            }),
          )
          .timeout(_inAppNotificationTimeout);

      if (!success) {
        debugPrint(
          '⚠️ NotificationService: In-app notification was not stored',
        );
        return;
      }

      debugPrint(
        '✅ NotificationService: In-app notification stored (type=$type)',
      );
    } on TimeoutException {
      debugPrint('⏱️ NotificationService: In-app notification timeout');
    } catch (e, stackTrace) {
      debugPrint(
        '⚠️ NotificationService: Failed to store in-app notification - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // Helpers
  // ==========================================

  bool _hasValidCoordinates(double latitude, double longitude) {
    return !latitude.isNaN &&
        !latitude.isInfinite &&
        !longitude.isNaN &&
        !longitude.isInfinite &&
        latitude >= -90.0 &&
        latitude <= 90.0 &&
        longitude >= -180.0 &&
        longitude <= 180.0 &&
        !(latitude == 0.0 && longitude == 0.0);
  }

  String _resolveLanguageCode(String? languageCode) {
    final explicit = _trimToNull(languageCode);

    if (explicit != null) {
      return explicit;
    }

    return PlatformDispatcher.instance.locale.languageCode;
  }

  String _firstNotEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = _trimToNull(value);

      if (trimmed != null) {
        return trimmed;
      }
    }

    return '';
  }

  String? _trimToNull(String? value) {
    final trimmed = value?.trim();

    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    return trimmed;
  }

  Map<String, dynamic> _removeNullValues(Map<String, dynamic> map) {
    final result = Map<String, dynamic>.from(map);
    result.removeWhere((_, value) => value == null);
    return result;
  }

  String _shortToken(String token) {
    if (token.length <= 12) return 'token hidden';

    return '${token.substring(0, 6)}...${token.substring(token.length - 4)}';
  }

  // ==========================================
  // 🧹 CLEANUP
  // ==========================================

  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    if (_ownsMessagingService) {
      await _messagingService.dispose();
    }

    debugPrint('🧹 NotificationService: Disposed');
  }
}
