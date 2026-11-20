import 'dart:async';
import 'dart:convert';
import 'dart:ui' show Color;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../constants/app_thresholds.dart';

/// ==========================================
/// 📬 Firebase Cloud Messaging Service - Guardian 360
/// ==========================================
/// خدمة مركزية لإدارة Firebase Cloud Messaging والإشعارات المحلية.
///
/// مسؤوليات هذا الملف:
/// - طلب صلاحيات الإشعارات.
/// - إدارة FCM token.
/// - استقبال رسائل FCM أثناء foreground/opened/background.
/// - عرض local notifications.
/// - إنشاء قنوات Android notification.
///
/// غير مسؤول عن:
/// - إنشاء accident report.
/// - الكتابة في Firestore.
/// - إرسال بلاغ للداشبورد.
/// - حساب severity أو منطق الحساسات.
///
/// البلاغ الحقيقي يمر من:
/// SOSViewModel → FirebaseService.reportAccident() → accidents collection
class FirebaseMessagingService {
  FirebaseMessagingService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  static const String _accidentChannelId = 'guardian360_accident_alerts';
  static const String _accidentChannelName = 'Guardian 360 Accident Alerts';
  static const String _accidentChannelDescription =
      'High priority local alerts for accident detection pre-alerts';

  static const String _generalChannelId = 'guardian360_general_notifications';
  static const String _generalChannelName = 'Guardian 360 Notifications';
  static const String _generalChannelDescription =
      'General Guardian 360 notifications and updates';

  /// الأفضل إنتاجياً أن تكون أيقونة monochrome داخل drawable:
  /// android/app/src/main/res/drawable/ic_stat_guardian_notification.xml
  ///
  /// لو لم تكن موجودة، سيتم استخدام launcher icon كـ fallback.
  static const String _preferredAndroidIcon =
      '@drawable/ic_stat_guardian_notification';
  static const String _fallbackAndroidIcon = '@mipmap/launcher_icon';

  static const Duration _permissionTimeout = Duration(seconds: 8);
  static const Duration _tokenTimeout = Duration(seconds: 8);
  static const Duration _localNotificationTimeout = Duration(seconds: 6);
  static const Duration _topicTimeout = Duration(seconds: 8);
  static const Duration _duplicateNotificationWindow = Duration(seconds: 3);

  Function(RemoteMessage)? _onMessageReceived;
  Function(RemoteMessage)? _onMessageOpenedApp;
  Function(String?)? _onTokenRefresh;
  Function(Map<String, dynamic>)? _onLocalNotificationTap;

  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _messageOpenedSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  bool _isInitialized = false;
  bool _isDisposed = false;

  DateTime? _lastNotificationShownAt;
  String? _lastNotificationFingerprint;

  // ==========================================
  // 🚀 INITIALIZATION
  // ==========================================

  Future<MessagingResult<void>> initialize({
    Function(RemoteMessage)? onMessageReceived,
    Function(RemoteMessage)? onMessageOpenedApp,
    Function(String?)? onTokenRefresh,
    Function(Map<String, dynamic>)? onLocalNotificationTap,
  }) async {
    if (_isDisposed) {
      debugPrint(
        '⚠️ FirebaseMessagingService: initialize ignored after dispose',
      );
      return MessagingResult.failure(
        MessagingException(
          message: 'Messaging service is disposed',
          code: 'service-disposed',
        ),
      );
    }

    if (_isInitialized) {
      _onMessageReceived = onMessageReceived ?? _onMessageReceived;
      _onMessageOpenedApp = onMessageOpenedApp ?? _onMessageOpenedApp;
      _onTokenRefresh = onTokenRefresh ?? _onTokenRefresh;
      _onLocalNotificationTap =
          onLocalNotificationTap ?? _onLocalNotificationTap;

      debugPrint('ℹ️ FirebaseMessagingService: Already initialized');
      return MessagingResult.success(null);
    }

    try {
      _onMessageReceived = onMessageReceived;
      _onMessageOpenedApp = onMessageOpenedApp;
      _onTokenRefresh = onTokenRefresh;
      _onLocalNotificationTap = onLocalNotificationTap;

      final permissionResult = await requestPermission().timeout(
        _permissionTimeout,
      );

      if (permissionResult.isFailure) {
        return MessagingResult.failure(
          MessagingException(
            message: 'Failed to get notification permissions',
            code: 'permission-denied',
            originalError: permissionResult.error,
          ),
        );
      }

      await _initializeLocalNotifications();

      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      await _attachFirebaseListeners();

      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      _isInitialized = true;

      debugPrint('✅ FirebaseMessagingService: Initialized successfully');
      return MessagingResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseMessagingService: Initialization timeout');
      return MessagingResult.failure(
        MessagingException(
          message: 'Messaging initialization timed out',
          code: 'initialization-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ FirebaseMessagingService: Initialization failed - $e');
      debugPrintStack(stackTrace: stackTrace);

      return MessagingResult.failure(
        MessagingException(
          message: 'Failed to initialize messaging service',
          code: 'initialization-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> _attachFirebaseListeners() async {
    await _foregroundMessageSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();

    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          '❌ FirebaseMessagingService: Foreground listener error - $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      },
    );

    _messageOpenedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleMessageOpenedApp,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          '❌ FirebaseMessagingService: Opened-app listener error - $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      },
    );

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      _handleTokenRefresh,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          '❌ FirebaseMessagingService: Token refresh listener error - $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  Future<void> _initializeLocalNotifications() async {
    try {
      await _initializeLocalNotificationsWithIcon(_preferredAndroidIcon);
    } catch (e, stackTrace) {
      debugPrint(
        '⚠️ FirebaseMessagingService: Preferred notification icon failed - $e',
      );
      debugPrintStack(stackTrace: stackTrace);

      await _initializeLocalNotificationsWithIcon(_fallbackAndroidIcon);
    }

    await _createNotificationChannels();
  }

  Future<void> _initializeLocalNotificationsWithIcon(String iconName) async {
    final androidSettings = AndroidInitializationSettings(iconName);

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );
  }

  Future<void> _createNotificationChannels() async {
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImplementation == null) return;

    const accidentChannel = AndroidNotificationChannel(
      _accidentChannelId,
      _accidentChannelName,
      description: _accidentChannelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      ledColor: Color(0xFFB00020),
      showBadge: true,
    );

    const generalChannel = AndroidNotificationChannel(
      _generalChannelId,
      _generalChannelName,
      description: _generalChannelDescription,
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await androidImplementation.createNotificationChannel(accidentChannel);
    await androidImplementation.createNotificationChannel(generalChannel);
  }

  // ==========================================
  // 🔔 PERMISSION MANAGEMENT
  // ==========================================

  Future<MessagingResult<NotificationSettings>> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,

        // Critical alert entitlement on iOS needs Apple approval.
        // Critical local emergency sound is handled by CriticalAlertService.
        criticalAlert: false,

        provisional: false,
        sound: true,
      );

      switch (settings.authorizationStatus) {
        case AuthorizationStatus.authorized:
          debugPrint('✅ FirebaseMessagingService: Permission granted');
          break;
        case AuthorizationStatus.provisional:
          debugPrint(
            '⚠️ FirebaseMessagingService: Provisional permission granted',
          );
          break;
        case AuthorizationStatus.denied:
          debugPrint('❌ FirebaseMessagingService: Permission denied');
          break;
        case AuthorizationStatus.notDetermined:
          debugPrint('⚠️ FirebaseMessagingService: Permission not determined');
          break;
      }

      return MessagingResult.success(settings);
    } catch (e, stackTrace) {
      debugPrint(
        '❌ FirebaseMessagingService: Failed to request permission - $e',
      );
      debugPrintStack(stackTrace: stackTrace);

      return MessagingResult.failure(
        MessagingException(
          message: 'Failed to request notification permission',
          code: 'permission-request-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<AuthorizationStatus> getPermissionStatus() async {
    try {
      final settings = await _messaging.getNotificationSettings().timeout(
        _permissionTimeout,
      );

      return settings.authorizationStatus;
    } catch (e, stackTrace) {
      debugPrint(
        '❌ FirebaseMessagingService: Failed to get permission status - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
      return AuthorizationStatus.notDetermined;
    }
  }

  // ==========================================
  // 🎫 TOKEN MANAGEMENT
  // ==========================================

  Future<MessagingResult<String>> getToken() async {
    if (_isDisposed) {
      return MessagingResult.failure(
        MessagingException(
          message: 'Messaging service is disposed',
          code: 'service-disposed',
        ),
      );
    }

    try {
      final token = await _messaging.getToken().timeout(_tokenTimeout);

      final safeToken = token?.trim();

      if (safeToken == null || safeToken.isEmpty) {
        return MessagingResult.failure(
          MessagingException(
            message: 'FCM token is null or empty',
            code: 'token-empty',
          ),
        );
      }

      debugPrint(
        '📱 FirebaseMessagingService: FCM token obtained (${_shortToken(safeToken)})',
      );

      return MessagingResult.success(safeToken);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseMessagingService: Token fetch timeout');
      return MessagingResult.failure(
        MessagingException(
          message: 'FCM token fetch timed out',
          code: 'token-fetch-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ FirebaseMessagingService: Failed to get token - $e');
      debugPrintStack(stackTrace: stackTrace);

      return MessagingResult.failure(
        MessagingException(
          message: 'Failed to get FCM token',
          code: 'token-fetch-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<MessagingResult<void>> deleteToken() async {
    try {
      await _messaging.deleteToken().timeout(_tokenTimeout);

      debugPrint('🗑️ FirebaseMessagingService: Token deleted');
      return MessagingResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseMessagingService: Token delete timeout');
      return MessagingResult.failure(
        MessagingException(
          message: 'FCM token delete timed out',
          code: 'token-delete-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ FirebaseMessagingService: Failed to delete token - $e');
      debugPrintStack(stackTrace: stackTrace);

      return MessagingResult.failure(
        MessagingException(
          message: 'Failed to delete FCM token',
          code: 'token-delete-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ==========================================
  // 📨 MESSAGE HANDLERS
  // ==========================================

  void _handleForegroundMessage(RemoteMessage message) {
    if (_isDisposed) return;

    debugPrint('📬 FirebaseMessagingService: Foreground message received');
    debugPrint('   ├─ Title: ${message.notification?.title}');
    debugPrint('   ├─ Body: ${message.notification?.body}');
    debugPrint('   └─ Data: ${message.data}');

    unawaited(_showLocalNotification(message));
    _onMessageReceived?.call(message);
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    if (_isDisposed) return;

    debugPrint('📭 FirebaseMessagingService: Message opened app');
    debugPrint('   ├─ Title: ${message.notification?.title}');
    debugPrint('   ├─ Body: ${message.notification?.body}');
    debugPrint('   └─ Data: ${message.data}');

    _onMessageOpenedApp?.call(message);
  }

  void _handleTokenRefresh(String token) {
    if (_isDisposed) return;

    final safeToken = token.trim();

    if (safeToken.isEmpty) {
      debugPrint('⚠️ FirebaseMessagingService: Empty refreshed token ignored');
      return;
    }

    debugPrint(
      '🔄 FirebaseMessagingService: Token refreshed (${_shortToken(safeToken)})',
    );

    _onTokenRefresh?.call(safeToken);
  }

  void _handleNotificationTap(NotificationResponse response) {
    if (_isDisposed) return;

    debugPrint('👆 FirebaseMessagingService: Notification tapped');

    final payload = _decodePayload(response.payload);

    if (payload.isNotEmpty) {
      debugPrint('   └─ Payload: $payload');
      _onLocalNotificationTap?.call(payload);
    } else {
      debugPrint('   └─ Payload: empty/invalid');
    }
  }

  // ==========================================
  // 🔔 LOCAL NOTIFICATIONS
  // ==========================================

  Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;

      final title = notification?.title?.trim();
      final body = notification?.body?.trim();

      if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
        debugPrint(
          '⚠️ FirebaseMessagingService: Message has no notification title/body',
        );
        return;
      }

      final payloadMap = _jsonSafePayload(message.data);
      final isAccident = _isAccidentPayload(payloadMap);
      final notificationId = _notificationIdFromRemoteMessage(message);

      await _showNotificationInternal(
        notificationId: notificationId,
        title: title ?? 'Guardian 360',
        body: body ?? '',
        payloadMap: payloadMap,
        isAccident: isAccident,
      );
    } catch (e, stackTrace) {
      debugPrint(
        '❌ FirebaseMessagingService: Failed to show local FCM notification - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<MessagingResult<void>> showCustomNotification({
    required String title,
    required String body,
    String? payload,
    bool isAccident = false,
    int? notificationId,
  }) async {
    if (_isDisposed) {
      return MessagingResult.failure(
        MessagingException(
          message: 'Messaging service is disposed',
          code: 'service-disposed',
        ),
      );
    }

    try {
      final safeTitle = title.trim();
      final safeBody = body.trim();

      if (safeTitle.isEmpty && safeBody.isEmpty) {
        return MessagingResult.failure(
          MessagingException(
            message: 'Notification title and body are empty',
            code: 'notification-content-empty',
          ),
        );
      }

      final payloadMap = _decodePayload(payload);
      final safePayloadMap = _jsonSafePayload(payloadMap);

      final resolvedNotificationId =
          notificationId ??
          _notificationIdFromPayloadOrContent(
            payloadMap: safePayloadMap,
            title: safeTitle,
            body: safeBody,
          );

      final isResolvedAccident =
          isAccident || _isAccidentPayload(safePayloadMap);

      if (_isDuplicateNotification(
        title: safeTitle,
        body: safeBody,
        payloadMap: safePayloadMap,
      )) {
        debugPrint(
          '⚠️ FirebaseMessagingService: Duplicate notification throttled',
        );
        return MessagingResult.success(null);
      }

      await _showNotificationInternal(
        notificationId: resolvedNotificationId,
        title: safeTitle.isNotEmpty ? safeTitle : 'Guardian 360',
        body: safeBody,
        payloadMap: safePayloadMap,
        isAccident: isResolvedAccident,
      ).timeout(_localNotificationTimeout);

      return MessagingResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseMessagingService: Show notification timeout');
      return MessagingResult.failure(
        MessagingException(
          message: 'Show notification timed out',
          code: 'notification-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint(
        '❌ FirebaseMessagingService: Failed to show notification - $e',
      );
      debugPrintStack(stackTrace: stackTrace);

      return MessagingResult.failure(
        MessagingException(
          message: 'Failed to show notification',
          code: 'notification-show-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> _showNotificationInternal({
    required int notificationId,
    required String title,
    required String body,
    required Map<String, dynamic> payloadMap,
    required bool isAccident,
  }) async {
    final channelId = isAccident ? _accidentChannelId : _generalChannelId;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      isAccident ? _accidentChannelName : _generalChannelName,
      channelDescription: isAccident
          ? _accidentChannelDescription
          : _generalChannelDescription,
      importance: isAccident ? Importance.max : Importance.defaultImportance,
      priority: isAccident ? Priority.high : Priority.defaultPriority,
      playSound: true,
      enableVibration: true,
      enableLights: isAccident,
      ledColor: isAccident ? const Color(0xFFB00020) : null,
      category: isAccident ? AndroidNotificationCategory.alarm : null,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(body),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final normalizedPayload = jsonEncode(_jsonSafePayload(payloadMap));

    await _localNotifications.show(
      notificationId,
      title,
      body,
      details,
      payload: normalizedPayload,
    );

    _lastNotificationShownAt = DateTime.now();
    _lastNotificationFingerprint = _notificationFingerprint(
      title: title,
      body: body,
      payloadMap: payloadMap,
    );
  }

  // ==========================================
  // 📡 TOPIC SUBSCRIPTION
  // ==========================================

  Future<MessagingResult<void>> subscribeToTopic(String topic) async {
    try {
      final safeTopic = _normalizeTopic(topic);

      if (safeTopic == null) {
        return MessagingResult.failure(
          MessagingException(
            message: 'Invalid FCM topic',
            code: 'invalid-topic',
          ),
        );
      }

      await _messaging.subscribeToTopic(safeTopic).timeout(_topicTimeout);

      debugPrint(
        '✅ FirebaseMessagingService: Subscribed to topic - $safeTopic',
      );

      return MessagingResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseMessagingService: Topic subscribe timeout');
      return MessagingResult.failure(
        MessagingException(
          message: 'Topic subscribe timed out',
          code: 'topic-subscribe-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ FirebaseMessagingService: Failed to subscribe - $e');
      debugPrintStack(stackTrace: stackTrace);

      return MessagingResult.failure(
        MessagingException(
          message: 'Failed to subscribe to topic',
          code: 'topic-subscribe-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<MessagingResult<void>> unsubscribeFromTopic(String topic) async {
    try {
      final safeTopic = _normalizeTopic(topic);

      if (safeTopic == null) {
        return MessagingResult.failure(
          MessagingException(
            message: 'Invalid FCM topic',
            code: 'invalid-topic',
          ),
        );
      }

      await _messaging.unsubscribeFromTopic(safeTopic).timeout(_topicTimeout);

      debugPrint(
        '✅ FirebaseMessagingService: Unsubscribed from topic - $safeTopic',
      );

      return MessagingResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseMessagingService: Topic unsubscribe timeout');
      return MessagingResult.failure(
        MessagingException(
          message: 'Topic unsubscribe timed out',
          code: 'topic-unsubscribe-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ FirebaseMessagingService: Failed to unsubscribe - $e');
      debugPrintStack(stackTrace: stackTrace);

      return MessagingResult.failure(
        MessagingException(
          message: 'Failed to unsubscribe from topic',
          code: 'topic-unsubscribe-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ==========================================
  // Helpers
  // ==========================================

  bool _isAccidentPayload(Map<String, dynamic> data) {
    final type = data['type']?.toString().trim().toLowerCase();
    final reportType = data['reportType']?.toString().trim().toLowerCase();
    final emergencySource = data['emergencySource']
        ?.toString()
        .trim()
        .toLowerCase();
    final alertSource = data['alertSource']?.toString().trim().toLowerCase();

    return type == 'accident' ||
        type == 'accident_pre_alert' ||
        type == 'emergency_alert' ||
        type == 'critical_alert' ||
        reportType == 'auto_detection' ||
        reportType == 'manual_sos' ||
        emergencySource == 'auto_detection' ||
        emergencySource == 'manual_sos' ||
        alertSource == 'auto_detection' ||
        alertSource == 'manual_sos';
  }

  int _notificationIdFromRemoteMessage(RemoteMessage message) {
    final explicitId = message.data['notificationId']?.toString();
    final parsedId = int.tryParse(explicitId ?? '');

    if (parsedId != null) return parsedId;

    final eventId = message.data['eventId']?.toString();
    final accidentId = message.data['accidentId']?.toString();

    final stableKey = _firstNotEmpty([
      eventId,
      accidentId,
      message.messageId,
      _stablePayloadKey(message.data),
      DateTime.now().microsecondsSinceEpoch.toString(),
    ]);

    return stableKey.hashCode & 0x7fffffff;
  }

  int _notificationIdFromPayloadOrContent({
    required Map<String, dynamic> payloadMap,
    required String title,
    required String body,
  }) {
    final explicitId = payloadMap['notificationId']?.toString();
    final parsedId = int.tryParse(explicitId ?? '');

    if (parsedId != null) return parsedId;

    final stablePayloadKey = _stablePayloadKey(payloadMap);

    if (stablePayloadKey != null) {
      return stablePayloadKey.hashCode & 0x7fffffff;
    }

    // General notification fallback:
    // Keep content stable enough for throttling/overwrite during a short window.
    final stableContentKey = '$title|$body';
    return stableContentKey.hashCode & 0x7fffffff;
  }

  bool _isDuplicateNotification({
    required String title,
    required String body,
    required Map<String, dynamic> payloadMap,
  }) {
    final lastShownAt = _lastNotificationShownAt;
    final lastFingerprint = _lastNotificationFingerprint;

    if (lastShownAt == null || lastFingerprint == null) return false;

    final currentFingerprint = _notificationFingerprint(
      title: title,
      body: body,
      payloadMap: payloadMap,
    );

    final withinWindow =
        DateTime.now().difference(lastShownAt) < _duplicateNotificationWindow;

    return lastFingerprint == currentFingerprint && withinWindow;
  }

  String _notificationFingerprint({
    required String title,
    required String body,
    required Map<String, dynamic> payloadMap,
  }) {
    final stablePayloadKey = _stablePayloadKey(payloadMap);

    return [
      payloadMap['type']?.toString() ?? '',
      payloadMap['emergencySource']?.toString() ?? '',
      payloadMap['reportType']?.toString() ?? '',
      stablePayloadKey ?? '',
      title,
      body,
    ].join('|');
  }

  String? _stablePayloadKey(Map<String, dynamic> payloadMap) {
    final eventId = payloadMap['eventId']?.toString().trim();
    if (eventId != null && eventId.isNotEmpty) return 'event:$eventId';

    final accidentId = payloadMap['accidentId']?.toString().trim();
    if (accidentId != null && accidentId.isNotEmpty) {
      return 'accident:$accidentId';
    }

    final alertId = payloadMap['alertId']?.toString().trim();
    if (alertId != null && alertId.isNotEmpty) return 'alert:$alertId';

    final offlineReportId = payloadMap['offlineReportId']?.toString().trim();
    if (offlineReportId != null && offlineReportId.isNotEmpty) {
      return 'offline:$offlineReportId';
    }

    final type = payloadMap['type']?.toString().trim().toLowerCase();

    if (type == 'accident_pre_alert') {
      final userId = payloadMap['userId']?.toString().trim() ?? '';
      final severity = AppThresholds.normalizeSeverityLevel(
        payloadMap['severityLevel']?.toString() ?? '',
      );
      final latitude = payloadMap['latitude']?.toString().trim() ?? '';
      final longitude = payloadMap['longitude']?.toString().trim() ?? '';

      return 'pre_alert:$userId|$severity|$latitude|$longitude';
    }

    if (type == 'battery_low') {
      return 'battery_low';
    }

    return null;
  }

  Map<String, dynamic> _decodePayload(String? payload) {
    final trimmed = payload?.trim();

    if (trimmed == null || trimmed.isEmpty) {
      return const {};
    }

    try {
      final decoded = jsonDecode(trimmed);

      if (decoded is Map) {
        return decoded.map(
          (key, dynamic value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      return {'rawPayload': trimmed};
    }

    return const {};
  }

  Map<String, dynamic> _jsonSafePayload(Map<String, dynamic> input) {
    if (input.isEmpty) return const <String, dynamic>{};

    final output = <String, dynamic>{};

    input.forEach((key, value) {
      final safeKey = key.trim();
      if (safeKey.isEmpty) return;

      final safeValue = _jsonSafeValue(value);
      if (safeValue != null) {
        output[safeKey] = safeValue;
      }
    });

    return output;
  }

  dynamic _jsonSafeValue(dynamic value) {
    if (value == null) return null;

    if (value is String || value is bool) return value;

    if (value is num) {
      if (value.isNaN || value.isInfinite) return null;
      return value;
    }

    if (value is List) {
      return value.map(_jsonSafeValue).where((item) => item != null).toList();
    }

    if (value is Map) {
      return _jsonSafePayload(
        value.map(
          (key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
        ),
      );
    }

    return value.toString();
  }

  String? _normalizeTopic(String topic) {
    var normalized = topic.trim();

    if (normalized.startsWith('/topics/')) {
      normalized = normalized.substring('/topics/'.length);
    }

    if (normalized.isEmpty || normalized.length > 900) {
      return null;
    }

    final validTopicRegex = RegExp(r'^[a-zA-Z0-9-_.~%]+$');

    if (!validTopicRegex.hasMatch(normalized)) {
      return null;
    }

    return normalized;
  }

  String _firstNotEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();

      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }

    return '';
  }

  String _shortToken(String token) {
    if (token.length <= 12) return 'token hidden';
    return '${token.substring(0, 6)}...${token.substring(token.length - 4)}';
  }

  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    await _foregroundMessageSubscription?.cancel();
    await _messageOpenedSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();

    _foregroundMessageSubscription = null;
    _messageOpenedSubscription = null;
    _tokenRefreshSubscription = null;

    _onMessageReceived = null;
    _onMessageOpenedApp = null;
    _onTokenRefresh = null;
    _onLocalNotificationTap = null;

    _isInitialized = false;
    _lastNotificationShownAt = null;
    _lastNotificationFingerprint = null;

    debugPrint('🧹 FirebaseMessagingService: Disposed');
  }
}

// ==========================================
// 📦 DATA MODELS
// ==========================================

class MessagingResult<T> {
  final T? data;
  final MessagingException? error;
  final bool isSuccess;

  MessagingResult._({this.data, this.error, required this.isSuccess});

  factory MessagingResult.success(T? data) {
    return MessagingResult._(data: data, isSuccess: true);
  }

  factory MessagingResult.failure(MessagingException error) {
    return MessagingResult._(error: error, isSuccess: false);
  }

  bool get isFailure => !isSuccess;
}

class MessagingException {
  final String message;
  final String code;
  final Object? originalError;
  final StackTrace? stackTrace;

  MessagingException({
    required this.message,
    required this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'MessagingException(code: $code, message: $message)';
  }
}

// ==========================================
// 🔧 BACKGROUND MESSAGE HANDLER
// ==========================================

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🌙 FirebaseMessagingService: Background message received');
  debugPrint('   ├─ Title: ${message.notification?.title}');
  debugPrint('   ├─ Body: ${message.notification?.body}');
  debugPrint('   └─ Data: ${message.data}');
}
