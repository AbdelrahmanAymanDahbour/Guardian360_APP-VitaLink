import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_thresholds.dart';
import '../../../core/services/background_service.dart';
import '../../../core/services/notification_service.dart';
import '../../auth/services/firebase_auth_service.dart';
import '../models/detection_config.dart';
import '../models/detection_event.dart';
import '../services/accident_detection_engine.dart';

/// ==========================================
/// 🧠 Accident Monitor ViewModel - Guardian 360
/// ==========================================
/// مسؤوليات هذا الملف:
/// - تشغيل/إيقاف مراقبة الاستشعار في الواجهة الأمامية.
/// - استقبال DetectionEvent من AccidentDetectionEngine.
/// - فلترة الأحداث غير الحقيقية أو المتكررة.
/// - بدء عد تنازلي قبل تمرير الحالة إلى SOSViewModel.
/// - إرسال إشعار محلي مبكر للمستخدم فقط.
///
/// غير مسؤول عن:
/// - إنشاء البلاغ في Firestore.
/// - إنشاء AlertModel.
/// - تشغيل CriticalAlertService.
/// - حساب شدة الحادث من الصفر.
///
/// البلاغ النهائي يتم عبر:
/// AccidentMonitorViewModel
///   → SOSViewModel
///   → FirebaseService.reportAccident()
class AccidentMonitorViewModel extends ChangeNotifier {
  AccidentMonitorViewModel({
    AccidentDetectionEngine? engine,
    FirebaseAuthService? authService,
    NotificationService? notificationService,
  }) : _ownsEngine = engine == null,
       _engine = engine ?? AccidentDetectionEngine(),
       _authService = authService ?? FirebaseAuthService(),
       _notificationService = notificationService ?? NotificationService();

  final AccidentDetectionEngine _engine;
  final FirebaseAuthService _authService;
  final NotificationService _notificationService;

  final bool _ownsEngine;

  static const Duration _duplicateEventCooldown = Duration(seconds: 15);
  static const int _fallbackCountdownSeconds = 10;

  bool _isMonitoring = false;
  bool _isDisposed = false;

  DetectionEvent? _lastDetectionEvent;
  DetectionConfig _config = DetectionConfig.medium();

  bool _isCountdownActive = false;
  int _countdown = 0;
  int _initialCountdown = 0;
  Timer? _countdownTimer;

  DateTime? _lastEventTime;
  String? _lastEventId;

  void Function(DetectionEvent)? _onAccidentDetected;
  void Function()? _onCountdownFinished;
  void Function()? _onCountdownCancelled;

  bool get isMonitoring => _isMonitoring;
  DetectionEvent? get lastDetectionEvent => _lastDetectionEvent;
  bool get isCountdownActive => _isCountdownActive;
  int get countdown => _countdown;
  int get initialCountdown => _initialCountdown;
  DetectionConfig get currentConfig => _config;

  String? get lastSeverityLevel => _lastDetectionEvent?.severityLevel;
  double? get lastConfidenceScore => _lastDetectionEvent?.confidenceScore;

  double get countdownProgress {
    if (_initialCountdown <= 0) return 0.0;
    return (_countdown / _initialCountdown).clamp(0.0, 1.0);
  }

  bool get hasActiveDetectionEvent => _lastDetectionEvent != null;

  Map<String, dynamic> getDebugSnapshot() {
    return {
      'isMonitoring': _isMonitoring,
      'isCountdownActive': _isCountdownActive,
      'countdown': _countdown,
      'initialCountdown': _initialCountdown,
      'hasDetectionEvent': _lastDetectionEvent != null,
      'lastEventId': _lastEventId,
      'lastEventTime': _lastEventTime?.toIso8601String(),
      'lastSeverityLevel': _lastDetectionEvent?.severityLevel,
      'lastConfidenceScore': _lastDetectionEvent?.confidenceScore,
      'config': _config.toString(),
      'engine': _engine.getDebugSnapshot(),
    };
  }

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  static DetectionConfig _safeConfig(DetectionConfig? config) {
    if (config != null && config.isStructurallyValid) {
      return config;
    }

    if (config != null) {
      debugPrint(
        '⚠️ AccidentMonitorViewModel: Invalid config received, using medium config',
      );
    }

    return DetectionConfig.medium();
  }

  // ==========================================
  // 🔗 UI callbacks
  // ==========================================

  void attachUiCallbacks({
    void Function(DetectionEvent)? onAccidentDetected,
    void Function()? onCountdownFinished,
    void Function()? onCountdownCancelled,
  }) {
    if (_isDisposed) return;

    _onAccidentDetected = onAccidentDetected;
    _onCountdownFinished = onCountdownFinished;
    _onCountdownCancelled = onCountdownCancelled;
  }

  void detachUiCallbacks() {
    _onAccidentDetected = null;
    _onCountdownFinished = null;
    _onCountdownCancelled = null;
  }

  // ==========================================
  // ▶️ Monitoring lifecycle
  // ==========================================

  Future<void> startMonitoring({
    DetectionConfig? config,
    void Function(DetectionEvent)? onAccidentDetected,
    void Function()? onCountdownFinished,
    void Function()? onCountdownCancelled,
  }) async {
    if (_isDisposed) return;

    if (_isMonitoring) {
      debugPrint('⚠️ AccidentMonitorViewModel: Already monitoring');
      return;
    }

    debugPrint('🧠 AccidentMonitorViewModel: Starting monitoring...');

    _config = _safeConfig(config ?? _config);

    if (onAccidentDetected != null ||
        onCountdownFinished != null ||
        onCountdownCancelled != null) {
      attachUiCallbacks(
        onAccidentDetected: onAccidentDetected,
        onCountdownFinished: onCountdownFinished,
        onCountdownCancelled: onCountdownCancelled,
      );
    }

    try {
      await _engine.startDetection(
        onDetection: _handleDetectionEvent,
        config: _config,
      );

      if (_isDisposed) {
        await _engine.stopDetection();
        return;
      }

      _isMonitoring = true;
      _lastDetectionEvent = null;
      _lastEventId = null;
      _lastEventTime = null;

      _safeNotify();
      unawaited(_syncBackgroundMonitoringState());

      debugPrint('✅ AccidentMonitorViewModel: Monitoring started');
    } catch (e, stackTrace) {
      debugPrint('❌ AccidentMonitorViewModel: Failed to start - $e');
      debugPrintStack(stackTrace: stackTrace);

      _isMonitoring = false;
      _isCountdownActive = false;
      _lastDetectionEvent = null;

      _safeNotify();
    }
  }

  Future<void> stopMonitoring() async {
    if (_isDisposed) return;
    if (!_isMonitoring && !_isCountdownActive) return;

    debugPrint('🛑 AccidentMonitorViewModel: Stopping monitoring...');

    try {
      await _engine.stopDetection();
    } catch (e, stackTrace) {
      debugPrint('❌ AccidentMonitorViewModel: Engine stop failed - $e');
      debugPrintStack(stackTrace: stackTrace);
    }

    _cancelCountdown(notify: false, clearEvent: true);

    _isMonitoring = false;
    _lastDetectionEvent = null;

    _safeNotify();

    await _syncBackgroundMonitoringState();

    try {
      await BackgroundServiceManager.stopService();
    } catch (e, stackTrace) {
      debugPrint('❌ AccidentMonitorViewModel: Background stop failed - $e');
      debugPrintStack(stackTrace: stackTrace);
    }

    debugPrint('✅ AccidentMonitorViewModel: Monitoring stopped');
  }

  // ==========================================
  // 🎯 Detection handling
  // ==========================================

  void _handleDetectionEvent(DetectionEvent event) {
    if (_isDisposed) return;

    if (!_isMonitoring) {
      debugPrint(
        '⚠️ AccidentMonitorViewModel: Detection event ignored because monitoring is stopped',
      );
      return;
    }

    final normalizedSeverity = AppThresholds.normalizeSeverityLevel(
      event.severityLevel,
    );

    debugPrint('🎯 AccidentMonitorViewModel: Detection event received');
    debugPrint('   EventId: ${event.eventId}');
    debugPrint('   Severity: ${event.severityLevel} → $normalizedSeverity');
    debugPrint('   Confidence: ${event.confidenceScore.toStringAsFixed(1)}%');
    debugPrint('   Is Accident: ${event.isAccident}');
    debugPrint('   Action: ${event.recommendedAction}');

    if (_isDuplicateEvent(event)) {
      debugPrint('⚠️ AccidentMonitorViewModel: Duplicate event ignored');
      return;
    }

    if (!event.isAccident) {
      debugPrint('ℹ️ AccidentMonitorViewModel: Non-accident event ignored');
      return;
    }

    if (!_shouldTriggerSOS(event)) {
      debugPrint(
        'ℹ️ AccidentMonitorViewModel: Event below SOS escalation threshold',
      );
      return;
    }

    if (_isInsideCooldownWindow()) {
      debugPrint(
        '⚠️ AccidentMonitorViewModel: Escalated event too soon after previous one, ignored',
      );
      return;
    }

    if (_isCountdownActive) {
      debugPrint(
        '⚠️ AccidentMonitorViewModel: Countdown already active, new event ignored',
      );
      return;
    }

    _lastEventId = event.eventId.trim().isEmpty ? null : event.eventId.trim();
    _lastEventTime = DateTime.now();
    _lastDetectionEvent = event;

    _safeNotify();
    unawaited(_syncBackgroundMonitoringState());

    unawaited(_sendAccidentNotification(event));

    _onAccidentDetected?.call(event);
    _triggerSOSCountdown(event);
  }

  bool _isDuplicateEvent(DetectionEvent event) {
    final eventId = event.eventId.trim();

    if (eventId.isEmpty) return false;

    return _lastEventId == eventId;
  }

  bool _isInsideCooldownWindow() {
    final lastEventTime = _lastEventTime;

    if (lastEventTime == null) return false;

    final elapsed = DateTime.now().difference(lastEventTime);

    return elapsed < _duplicateEventCooldown;
  }

  Future<void> _sendAccidentNotification(DetectionEvent event) async {
    try {
      if (!_isValidCoordinatePair(event.latitude, event.longitude)) {
        debugPrint(
          '⚠️ AccidentMonitorViewModel: Notification skipped because real coordinates are unavailable',
        );
        return;
      }

      final user = _authService.currentUser;
      final userName = _firstNotEmpty([
        user?.displayName,
        user?.email,
        'Guardian User',
      ]);

      await _notificationService.sendAccidentNotification(
        severityLevel: AppThresholds.normalizeSeverityLevel(
          event.severityLevel,
        ),
        userName: userName,
        latitude: event.latitude!,
        longitude: event.longitude!,
        userId: user?.uid,
      );

      debugPrint('✅ AccidentMonitorViewModel: Accident notification sent');
    } catch (e, stackTrace) {
      debugPrint(
        '❌ AccidentMonitorViewModel: Failed to send notification - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  bool _shouldTriggerSOS(DetectionEvent event) {
    final normalizedSeverity = AppThresholds.normalizeSeverityLevel(
      event.severityLevel,
    );

    return normalizedSeverity == AppThresholds.severityMedium ||
        normalizedSeverity == AppThresholds.severityHigh ||
        normalizedSeverity == AppThresholds.severityCritical;
  }

  // ==========================================
  // ⏱️ Countdown
  // ==========================================

  void _triggerSOSCountdown(DetectionEvent event) {
    if (_isDisposed) return;

    debugPrint('🚨 AccidentMonitorViewModel: Triggering SOS countdown');

    _countdownTimer?.cancel();
    _countdownTimer = null;

    _initialCountdown = _resolveCountdownSeconds(event);
    _countdown = _initialCountdown;
    _isCountdownActive = true;

    _safeNotify();
    unawaited(_syncBackgroundMonitoringState());

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      if (!_isCountdownActive) {
        timer.cancel();
        _countdownTimer = null;
        return;
      }

      if (_countdown > 1) {
        _countdown--;
        _safeNotify();
        unawaited(_syncBackgroundMonitoringState());
        return;
      }

      _countdown = 0;
      timer.cancel();
      _countdownTimer = null;
      _safeNotify();

      _handleCountdownFinished();
    });

    debugPrint(
      '⏱️ AccidentMonitorViewModel: Countdown started ($_initialCountdown s)',
    );
  }

  int _resolveCountdownSeconds(DetectionEvent event) {
    final eventCountdown = event.countdownDurationSeconds;

    if (eventCountdown > 0 && eventCountdown <= 60) {
      return eventCountdown;
    }

    final fallbackBySeverity =
        AppThresholds.getCountdownDurationForSeverityLevel(event.severityLevel);

    if (fallbackBySeverity > 0 && fallbackBySeverity <= 60) {
      debugPrint(
        '⚠️ AccidentMonitorViewModel: Invalid event countdown ($eventCountdown), using severity fallback $fallbackBySeverity',
      );
      return fallbackBySeverity;
    }

    debugPrint(
      '⚠️ AccidentMonitorViewModel: Invalid countdown duration ($eventCountdown), using fallback',
    );

    return _fallbackCountdownSeconds;
  }

  void _handleCountdownFinished() {
    if (_isDisposed) return;

    debugPrint('⏰ AccidentMonitorViewModel: Countdown finished');

    _countdownTimer?.cancel();
    _countdownTimer = null;
    _isCountdownActive = false;
    _countdown = 0;

    _safeNotify();
    unawaited(_syncBackgroundMonitoringState());

    _onCountdownFinished?.call();

    // مهم:
    // لا نكتب Firestore هنا.
    // SOSViewModel هو المسؤول عن executeEmergencyAction()
    // حتى لا يصير duplicate writes.
  }

  void cancelSOS() {
    if (_isDisposed) return;

    if (!_isCountdownActive && _lastDetectionEvent == null) {
      return;
    }

    debugPrint('❌ AccidentMonitorViewModel: SOS cancelled by user');

    _cancelCountdown(notify: true, clearEvent: true);
    _onCountdownCancelled?.call();
    unawaited(_syncBackgroundMonitoringState());
  }

  void _cancelCountdown({required bool notify, required bool clearEvent}) {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _isCountdownActive = false;
    _countdown = 0;
    _initialCountdown = 0;

    if (clearEvent) {
      _lastDetectionEvent = null;
    }

    if (notify) {
      _safeNotify();
    }
  }

  // ==========================================
  // 🔧 Background sync
  // ==========================================
  // نُبقي هذا المسار مجمداً حالياً.
  // لا نعيد تفعيل background sensor detection قبل فحص مستقل كامل.
  // الهدف الحالي منع duplicate SOS / duplicate Firestore writes.
  Future<void> _syncBackgroundMonitoringState() async {
    return;
  }

  // ==========================================
  // ⚙️ Configuration
  // ==========================================

  void updateConfig(DetectionConfig config) {
    if (_isDisposed) return;

    if (!config.isStructurallyValid) {
      debugPrint(
        '⚠️ AccidentMonitorViewModel: Ignored invalid config update: $config',
      );
      return;
    }

    _config = config;

    if (_isMonitoring) {
      _engine.updateConfig(config);

      unawaited(
        BackgroundServiceManager.updateSensitivity(config.sensitivityLevel),
      );
    }

    debugPrint('🔧 AccidentMonitorViewModel: Configuration updated');
    _safeNotify();
  }

  void setSensitivity(String level) {
    if (_isDisposed) return;

    final config = DetectionConfig.fromSensitivity(level);
    updateConfig(config);
  }

  void clearLastDetectionEvent() {
    if (_isDisposed) return;

    _cancelCountdown(notify: false, clearEvent: true);
    _safeNotify();
    unawaited(_syncBackgroundMonitoringState());
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

  bool _isValidCoordinatePair(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;

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

  @override
  void dispose() {
    _isDisposed = true;

    _countdownTimer?.cancel();
    _countdownTimer = null;

    detachUiCallbacks();

    unawaited(BackgroundServiceManager.stopService());

    if (_ownsEngine) {
      unawaited(_engine.dispose());
    }

    super.dispose();
  }
}
