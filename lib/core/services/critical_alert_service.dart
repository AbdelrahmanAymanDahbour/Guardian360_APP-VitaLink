import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../constants/app_thresholds.dart';

/// ==========================================
/// 🚨 Critical Alert Service - Guardian 360
/// ==========================================
/// خدمة التنبيهات المحلية الحرجة فقط.
///
/// مسؤولياتها:
/// - تشغيل تنبيه صوتي قوي محلياً.
/// - إظهار notification حرجة.
/// - تشغيل vibration pattern.
/// - إلغاء التنبيه المحلي.
///
/// ليست مسؤولة عن:
/// - إنشاء البلاغ في Firestore.
/// - إرسال بيانات للداشبورد.
/// - حساب severity.
/// - بدء أو إلغاء SOS flow.
///
/// المسار الصحيح:
/// SOSViewModel / AccidentMonitorViewModel
///   → FirebaseService.reportAccident()
///   → CriticalAlertService فقط للتنبيه المحلي عند الحالات الحرجة
class CriticalAlertService {
  static const String _criticalChannelId = 'guardian360_critical_alerts';
  static const String _criticalChannelName = 'Guardian 360 Critical Alerts';
  static const String _criticalChannelDescription =
      'تنبيهات طوارئ حرجة لحالات Guardian 360';

  /// الأفضل إنتاجياً أن تكون أيقونة monochrome داخل drawable:
  /// android/app/src/main/res/drawable/ic_stat_guardian_notification.xml
  static const String _preferredAndroidIcon =
      '@drawable/ic_stat_guardian_notification';

  static const String _fallbackAndroidIcon = '@mipmap/launcher_icon';

  static const int _criticalNotificationId = 999;

  static const Duration _nativeAudioTimeout = Duration(seconds: 3);
  static const Duration _notificationTimeout = Duration(seconds: 6);
  static const Duration _triggerCooldown = Duration(seconds: 20);

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static bool _isTriggering = false;
  static bool _usedFallbackIcon = false;

  static DateTime? _lastTriggeredAt;

  // ==========================================
  // 🚀 Initialize critical alert system
  // ==========================================

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _initializeWithIcon(_preferredAndroidIcon);
      _usedFallbackIcon = false;
      _isInitialized = true;

      debugPrint('✅ CriticalAlertService: Initialized successfully');
    } catch (e, stackTrace) {
      debugPrint(
        '⚠️ CriticalAlertService: Preferred icon initialization failed - $e',
      );
      debugPrintStack(stackTrace: stackTrace);

      await _initializeWithFallbackIcon();
    }
  }

  static Future<void> _initializeWithFallbackIcon() async {
    if (_isInitialized) return;

    try {
      await _initializeWithIcon(_fallbackAndroidIcon);
      _usedFallbackIcon = true;
      _isInitialized = true;

      debugPrint(
        '✅ CriticalAlertService: Initialized with fallback launcher icon',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ CriticalAlertService: Fallback initialization failed - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> _initializeWithIcon(String iconName) async {
    final androidSettings = AndroidInitializationSettings(iconName);

    /// ملاحظة iOS:
    /// Critical alerts على iOS تحتاج Apple entitlement.
    /// لذلك لا نطلب critical permission افتراضياً حتى لا نسبب مشاكل إنتاجية.
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: false,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);

    if (_isAndroid) {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      await androidImplementation?.requestNotificationsPermission();

      const androidChannel = AndroidNotificationChannel(
        _criticalChannelId,
        _criticalChannelName,
        description: _criticalChannelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color(0xFFFF0000),
        showBadge: true,
      );

      await androidImplementation?.createNotificationChannel(androidChannel);
    }
  }

  // ==========================================
  // 🚨 Trigger critical alert
  // ==========================================

  /// يعمل فقط عند الوصول إلى العتبة الحرجة الرسمية.
  ///
  /// لا تنادِ هذه الدالة لإنشاء بلاغ.
  /// إنشاء البلاغ يتم عبر FirebaseService.reportAccident().
  static Future<void> triggerCriticalAlert({
    required String title,
    required String message,
    required double severityScore,
    bool bypassCooldown = false,
  }) async {
    final safeSeverityScore = _safeScore(severityScore);

    if (!AppThresholds.isCriticalSeverity(safeSeverityScore)) {
      debugPrint(
        '⚠️ CriticalAlertService: Severity is not critical '
        '($safeSeverityScore) - skipping',
      );
      return;
    }

    final initialized = await _ensureInitialized();

    if (!initialized) {
      debugPrint(
        '⚠️ CriticalAlertService: Not initialized - skipping critical alert',
      );
      return;
    }

    if (_shouldThrottle(bypassCooldown: bypassCooldown)) {
      debugPrint(
        '⚠️ CriticalAlertService: Critical alert throttled to prevent spam',
      );
      return;
    }

    if (_isTriggering) {
      debugPrint(
        '⚠️ CriticalAlertService: Already triggering - skipping duplicate call',
      );
      return;
    }

    _isTriggering = true;
    _lastTriggeredAt = DateTime.now();

    try {
      await _playMaxVolumeAlert();
      await _showCriticalNotification(
        title: title,
        message: message,
        severityScore: safeSeverityScore,
      );
      await _vibrateEmergencyPattern();

      debugPrint(
        '🚨 CriticalAlertService: Critical alert triggered '
        '(severityScore: ${safeSeverityScore.toStringAsFixed(1)}, '
        'fallbackIcon: $_usedFallbackIcon)',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ CriticalAlertService: Failed to trigger alert - $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isTriggering = false;
    }
  }

  static Future<bool> _ensureInitialized() async {
    if (_isInitialized) return true;

    await initialize();
    return _isInitialized;
  }

  static bool _shouldThrottle({required bool bypassCooldown}) {
    if (bypassCooldown) return false;

    final lastTriggered = _lastTriggeredAt;
    if (lastTriggered == null) return false;

    return DateTime.now().difference(lastTriggered) < _triggerCooldown;
  }

  // ==========================================
  // 🔊 Native max-volume alert
  // ==========================================

  static Future<void> _playMaxVolumeAlert() async {
    try {
      if (!_isAndroid) {
        debugPrint(
          'ℹ️ CriticalAlertService: Native max-volume alert skipped on this platform',
        );
        return;
      }

      const platform = MethodChannel('com.guardian360/audio');

      await platform
          .invokeMethod<void>('playMaxVolumeAlert')
          .timeout(_nativeAudioTimeout);
    } on TimeoutException {
      debugPrint('⏱️ CriticalAlertService: Native audio timeout');
    } on MissingPluginException {
      debugPrint(
        '⚠️ CriticalAlertService: Native audio plugin not implemented yet',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ CriticalAlertService: Failed to play max volume - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // 📢 Show critical notification
  // ==========================================

  static Future<void> _showCriticalNotification({
    required String title,
    required String message,
    required double severityScore,
  }) async {
    try {
      final safeTitle = title.trim().isNotEmpty
          ? title.trim()
          : '🚨 Guardian 360 Alert';

      final safeMessage = message.trim().isNotEmpty
          ? message.trim()
          : 'تم رصد حالة طوارئ حرجة وتحتاج إلى انتباه فوري.';

      final androidDetails = AndroidNotificationDetails(
        _criticalChannelId,
        _criticalChannelName,
        channelDescription: _criticalChannelDescription,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([
          0,
          500,
          200,
          500,
          200,
          700,
          300,
          1000,
        ]),
        enableLights: true,
        color: const Color(0xFFFF0000),
        ledColor: const Color(0xFFFF0000),
        ledOnMs: 1000,
        ledOffMs: 500,
        ongoing: true,
        autoCancel: false,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        ticker: 'حالة طوارئ!',
        showWhen: true,
        usesChronometer: false,
        styleInformation: BigTextStyleInformation(safeMessage),
      );

      /// iOS:
      /// timeSensitive أكثر أماناً بدون critical entitlement.
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'emergency_alert.aiff',
        badgeNumber: 1,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin
          .show(
            _criticalNotificationId,
            safeTitle,
            safeMessage,
            notificationDetails,
            payload:
                '{"type":"critical_alert","severityLevel":"critical","severityScore":$severityScore,"source":"guardian360"}',
          )
          .timeout(_notificationTimeout);
    } on TimeoutException {
      debugPrint('⏱️ CriticalAlertService: Critical notification timeout');
    } catch (e, stackTrace) {
      debugPrint('❌ CriticalAlertService: Failed to show notification - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // 📳 Emergency vibration
  // ==========================================

  static Future<void> _vibrateEmergencyPattern() async {
    try {
      const shortDelay = Duration(milliseconds: 180);
      const mediumDelay = Duration(milliseconds: 350);

      await HapticFeedback.vibrate();
      await Future.delayed(shortDelay);

      await HapticFeedback.vibrate();
      await Future.delayed(shortDelay);

      await HapticFeedback.heavyImpact();
      await Future.delayed(mediumDelay);

      await HapticFeedback.heavyImpact();
      await Future.delayed(mediumDelay);

      await HapticFeedback.vibrate();
      await Future.delayed(shortDelay);

      await HapticFeedback.heavyImpact();
    } catch (e, stackTrace) {
      debugPrint('❌ CriticalAlertService: Failed to vibrate - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // 🔕 Cancel critical alert
  // ==========================================

  static Future<void> cancelCriticalAlert() async {
    try {
      if (_isInitialized) {
        await _notificationsPlugin.cancel(_criticalNotificationId);
      }

      _isTriggering = false;
      _lastTriggeredAt = null;

      debugPrint('✅ CriticalAlertService: Critical alert cancelled');
    } catch (e, stackTrace) {
      debugPrint('❌ CriticalAlertService: Failed to cancel alert - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // 🧪 Debug-only test
  // ==========================================

  /// يعمل فقط في debug mode حتى لا يبقى test trigger في الإنتاج.
  static Future<void> testCriticalAlert() async {
    if (!kDebugMode) {
      debugPrint(
        '⚠️ CriticalAlertService: testCriticalAlert ignored in release mode',
      );
      return;
    }

    await triggerCriticalAlert(
      title: '🚨 اختبار تنبيه حرج',
      message: 'هذا اختبار لنظام التنبيهات الحرجة',
      severityScore: AppThresholds.severityScoreCritical,
      bypassCooldown: true,
    );
  }

  // ==========================================
  // Helpers
  // ==========================================

  static bool get _isAndroid {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  static double _safeScore(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    return value.clamp(0.0, 100.0).toDouble();
  }
}
