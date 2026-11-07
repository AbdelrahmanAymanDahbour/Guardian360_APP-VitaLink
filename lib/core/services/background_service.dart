import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../constants/app_thresholds.dart';

/// ==========================================
/// 🛡️ Background Service Manager - Guardian 360
/// ==========================================
/// Foreground service container for persistent protection status.
///
/// مهم جداً:
/// هذا الملف لا يشغّل محرك استشعار بالخلفية حالياً.
/// لا يستخدم SensorService.
/// لا يستخدم AccidentDetectionEngine.
/// لا يكتب Firestore.
/// لا يرسل بلاغات.
///
/// الهدف الحالي:
/// - إبقاء خدمة foreground notification جاهزة.
/// - منع duplicate detection مع foreground flow.
/// - حفظ أوامر monitoring/sensitivity للتوافق مع باقي المشروع.
/// - تجهيز نقطة آمنة لتفعيل background detection لاحقاً بعد اختبار مستقل.
///
/// المسار الحقيقي الحالي للحوادث:
/// SensorFusionService
///   → AccidentDetectionEngine
///   → AccidentMonitorViewModel
///   → SOSViewModel
///   → FirebaseService.reportAccident()
class BackgroundServiceManager {
  static const String _serviceChannelId = 'guardian360_foreground_service';
  static const String _serviceChannelName = 'Guardian 360 Protection';
  static const String _serviceChannelDescription =
      'خدمة الحماية المستمرة لـ Guardian 360';

  static const int _notificationId = 888;

  /// الأفضل إنتاجياً أن تكون أيقونة monochrome داخل drawable:
  /// android/app/src/main/res/drawable/ic_stat_guardian_notification.xml
  ///
  /// نستخدم launcher icon فقط كـ fallback لو الأيقونة غير موجودة.
  static const String _preferredAndroidIcon =
      '@drawable/ic_stat_guardian_notification';
  static const String _fallbackAndroidIcon = '@mipmap/launcher_icon';

  static const Duration _operationTimeout = Duration(seconds: 8);
  static const Duration _serviceStartDelay = Duration(milliseconds: 350);

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  // ==========================================
  // 🚀 Initialize background service
  // ==========================================

  static Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('ℹ️ BackgroundService: Already initialized');
      return;
    }

    try {
      final service = FlutterBackgroundService();

      await _initializeNotifications().timeout(_operationTimeout);

      await service
          .configure(
            iosConfiguration: IosConfiguration(
              autoStart: false,
              onForeground: onStart,
              onBackground: onIosBackground,
            ),
            androidConfiguration: AndroidConfiguration(
              onStart: onStart,
              isForegroundMode: true,
              autoStart: false,
              autoStartOnBoot: false,
              notificationChannelId: _serviceChannelId,
              initialNotificationTitle: 'Guardian 360',
              initialNotificationContent: 'الخدمة جاهزة للحماية في الخلفية',
              foregroundServiceNotificationId: _notificationId,
            ),
          )
          .timeout(_operationTimeout);

      _isInitialized = true;

      debugPrint('✅ BackgroundService: Initialized successfully');
    } on TimeoutException {
      debugPrint('⏱️ BackgroundService: Initialize timeout');
    } catch (e, stackTrace) {
      debugPrint('❌ BackgroundService: Initialize failed - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // 📱 Initialize notifications
  // ==========================================

  static Future<void> _initializeNotifications() async {
    try {
      await _initializeNotificationsWithIcon(_preferredAndroidIcon);
    } catch (e, stackTrace) {
      debugPrint(
        '⚠️ BackgroundService: Preferred notification icon failed - $e',
      );
      debugPrintStack(stackTrace: stackTrace);

      await _initializeNotificationsWithIcon(_fallbackAndroidIcon);
    }

    await _createNotificationChannel();

    debugPrint('✅ BackgroundService: Notifications initialized');
  }

  static Future<void> _initializeNotificationsWithIcon(String iconName) async {
    final androidSettings = AndroidInitializationSettings(iconName);

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
  }

  static Future<void> _createNotificationChannel() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation == null) return;

    const androidChannel = AndroidNotificationChannel(
      _serviceChannelId,
      _serviceChannelName,
      description: _serviceChannelDescription,
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    await androidImplementation.createNotificationChannel(androidChannel);
  }

  // ==========================================
  // ▶️ Start background service container
  // ==========================================

  static Future<bool> startService() async {
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning().timeout(_operationTimeout);

      if (isRunning) {
        debugPrint('ℹ️ BackgroundService: Already running');
        return true;
      }

      await service.startService().timeout(_operationTimeout);
      await Future<void>.delayed(_serviceStartDelay);

      debugPrint('✅ BackgroundService: Started successfully');
      return true;
    } on TimeoutException {
      debugPrint('⏱️ BackgroundService: Start timeout');
      return false;
    } catch (e, stackTrace) {
      debugPrint('❌ BackgroundService: Failed to start - $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  // ==========================================
  // ⏹️ Stop background service completely
  // ==========================================

  static Future<bool> stopService() async {
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning().timeout(_operationTimeout);

      if (!isRunning) {
        debugPrint('ℹ️ BackgroundService: Not running');
        return true;
      }

      service.invoke('stop_service');

      debugPrint('✅ BackgroundService: Stop requested');
      return true;
    } on TimeoutException {
      debugPrint('⏱️ BackgroundService: Stop timeout');
      return false;
    } catch (e, stackTrace) {
      debugPrint('❌ BackgroundService: Failed to stop - $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  // ==========================================
  // ▶️ Start monitoring in background
  // ==========================================
  /// مؤقتاً لا يوجد detection فعلي في الخلفية.
  /// هذه الدالة موجودة للتوافق مع باقي المشروع فقط.
  static Future<void> startMonitoring({String sensitivity = 'medium'}) async {
    final normalizedSensitivity = AppThresholds.normalizeSensitivity(
      sensitivity,
    );

    final started = await startService();

    if (!started) {
      debugPrint(
        '⚠️ BackgroundService: Cannot start monitoring container because service failed to start',
      );
      return;
    }

    final service = FlutterBackgroundService();

    service.invoke('start_monitoring', {
      'sensitivity': normalizedSensitivity,
      'detectionEnabled': false,
      'source': 'foreground_compatibility',
    });
  }

  // ==========================================
  // ⏸️ Stop monitoring in background
  // ==========================================

  static Future<void> stopMonitoring() async {
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning().timeout(_operationTimeout);

      if (!isRunning) {
        debugPrint('ℹ️ BackgroundService: stopMonitoring ignored; not running');
        return;
      }

      service.invoke('stop_monitoring');
    } on TimeoutException {
      debugPrint('⏱️ BackgroundService: stopMonitoring timeout');
    } catch (e, stackTrace) {
      debugPrint('❌ BackgroundService: stopMonitoring failed - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // 🎚️ Update sensitivity while running
  // ==========================================

  static Future<void> updateSensitivity(String sensitivity) async {
    try {
      final normalizedSensitivity = AppThresholds.normalizeSensitivity(
        sensitivity,
      );

      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning().timeout(_operationTimeout);

      if (!isRunning) {
        debugPrint(
          'ℹ️ BackgroundService: Sensitivity stored by caller only; service not running',
        );
        return;
      }

      service.invoke('update_sensitivity', {
        'sensitivity': normalizedSensitivity,
        'detectionEnabled': false,
      });
    } on TimeoutException {
      debugPrint('⏱️ BackgroundService: updateSensitivity timeout');
    } catch (e, stackTrace) {
      debugPrint('❌ BackgroundService: updateSensitivity failed - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // 🔄 Check if service is running
  // ==========================================

  static Future<bool> isServiceRunning() async {
    try {
      final service = FlutterBackgroundService();
      return await service.isRunning().timeout(_operationTimeout);
    } on TimeoutException {
      debugPrint('⏱️ BackgroundService: Status check timeout');
      return false;
    } catch (e, stackTrace) {
      debugPrint('❌ BackgroundService: Failed to check status - $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  // ==========================================
  // 📢 Update persistent notification
  // ==========================================

  static Future<void> updateNotification({
    required String title,
    required String content,
  }) async {
    try {
      final safeTitle = title.trim().isEmpty ? 'Guardian 360' : title.trim();
      final safeContent = content.trim().isEmpty
          ? 'خدمة Guardian 360 تعمل'
          : content.trim();

      const androidDetails = AndroidNotificationDetails(
        _serviceChannelId,
        _serviceChannelName,
        channelDescription: _serviceChannelDescription,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        playSound: false,
        enableVibration: false,
        showWhen: false,
        category: AndroidNotificationCategory.service,
        visibility: NotificationVisibility.public,
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin
          .show(_notificationId, safeTitle, safeContent, notificationDetails)
          .timeout(_operationTimeout);
    } on TimeoutException {
      debugPrint('⏱️ BackgroundService: updateNotification timeout');
    } catch (e, stackTrace) {
      debugPrint('❌ BackgroundService: Failed to update notification - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // 🎯 Main service entry point
  // ==========================================

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    debugPrint('🚀 BackgroundService: onStart called');

    Timer? heartbeatTimer;
    bool isMonitoring = false;
    String currentSensitivity = AppThresholds.sensitivityMedium;

    try {
      await _initializeNotifications();
    } catch (e, stackTrace) {
      debugPrint(
        '⚠️ BackgroundService: Notification initialization inside service failed - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }

    await updateNotification(
      title: 'Guardian 360',
      content: 'الخدمة جاهزة للحماية في الخلفية',
    );

    Future<void> startBackgroundMonitoringContainer() async {
      if (isMonitoring) {
        debugPrint('ℹ️ BackgroundService: Monitoring container already active');
        return;
      }

      isMonitoring = true;

      await updateNotification(
        title: 'Guardian 360',
        content: 'الخدمة الخلفية تعمل، لكن اكتشاف الحوادث معطل مؤقتاً للتشخيص',
      );

      debugPrint(
        '✅ BackgroundService: Background container marked active '
        '(NO sensor detection running)',
      );
    }

    Future<void> stopBackgroundMonitoringContainer() async {
      if (!isMonitoring) {
        debugPrint(
          'ℹ️ BackgroundService: Monitoring container already stopped',
        );
        return;
      }

      isMonitoring = false;

      await updateNotification(
        title: 'Guardian 360',
        content: 'الخدمة تعمل، لكن المراقبة الخلفية متوقفة',
      );

      debugPrint('✅ BackgroundService: Background container stopped');
    }

    service.on('start_monitoring').listen((event) async {
      try {
        final payload = _payloadFromEvent(event);
        final rawSensitivity = payload['sensitivity']?.toString();

        currentSensitivity = AppThresholds.normalizeSensitivity(
          rawSensitivity ?? currentSensitivity,
        );

        debugPrint(
          '▶️ BackgroundService: start_monitoring received '
          '(sensitivity=$currentSensitivity, detection disabled temporarily)',
        );

        await startBackgroundMonitoringContainer();
      } catch (e, stackTrace) {
        debugPrint('❌ BackgroundService: start_monitoring error - $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    });

    service.on('stop_monitoring').listen((event) async {
      try {
        debugPrint('⏸️ BackgroundService: stop_monitoring received');
        await stopBackgroundMonitoringContainer();
      } catch (e, stackTrace) {
        debugPrint('❌ BackgroundService: stop_monitoring error - $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    });

    service.on('update_sensitivity').listen((event) async {
      try {
        final payload = _payloadFromEvent(event);
        final rawSensitivity = payload['sensitivity']?.toString();

        currentSensitivity = AppThresholds.normalizeSensitivity(
          rawSensitivity ?? currentSensitivity,
        );

        debugPrint(
          '🎚️ BackgroundService: Sensitivity updated to $currentSensitivity '
          '(stored only, no background detector running)',
        );
      } catch (e, stackTrace) {
        debugPrint('❌ BackgroundService: update_sensitivity error - $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    });

    service.on('stop_service').listen((event) async {
      try {
        debugPrint('🛑 BackgroundService: stop_service received');

        heartbeatTimer?.cancel();
        heartbeatTimer = null;

        await updateNotification(
          title: 'Guardian 360',
          content: 'يتم إيقاف خدمة الحماية الخلفية...',
        );

        service.stopSelf();
      } catch (e, stackTrace) {
        debugPrint('❌ BackgroundService: stop_service error - $e');
        debugPrintStack(stackTrace: stackTrace);
        service.stopSelf();
      }
    });

    heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      try {
        if (isMonitoring) {
          debugPrint(
            '📊 BackgroundService: container running only '
            '(detection disabled, sensitivity=$currentSensitivity)',
          );
        }
      } catch (e, stackTrace) {
        debugPrint('❌ BackgroundService: heartbeat error - $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    });

    debugPrint('✅ BackgroundService: Ready and waiting for commands');
  }

  // ==========================================
  // 🍎 iOS background handler
  // ==========================================

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    debugPrint('🍎 BackgroundService: iOS background mode');
    return true;
  }

  // ==========================================
  // Helpers
  // ==========================================

  static Map<String, dynamic> _payloadFromEvent(dynamic event) {
    if (event is Map<String, dynamic>) {
      return event;
    }

    if (event is Map) {
      return event.map((key, dynamic value) => MapEntry(key.toString(), value));
    }

    return const <String, dynamic>{};
  }
}
