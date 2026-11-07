import 'dart:async';
import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_thresholds.dart';
import '../../../core/services/alert_service.dart';
import '../../../core/services/critical_alert_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/gps_location_service.dart';
import '../../../core/services/in_app_notification_service.dart';
import '../../../core/services/offline_sync_service.dart';
import '../../accident_detection/models/detection_event.dart';
import '../../accident_detection/viewmodels/accident_monitor_viewmodel.dart';
import '../../auth/services/firebase_auth_service.dart';

enum SOSState {
  monitoring,
  evaluating,
  countingDown,
  listening,
  sendingAlert,
  alertSent,
  callingContact,
  cancelled,
  error,
}

class SOSViewModel extends ChangeNotifier {
  final AccidentMonitorViewModel _accidentMonitor;
  final AlertService _alertService;
  final FirebaseService _firebaseService;
  final FirebaseAuthService _authService;
  final GPSLocationService _gpsService;
  final OfflineSyncService _offlineSyncService;
  final InAppNotificationService _inAppNotificationService;

  final bool _ownsAccidentMonitor;
  final bool _ownsOfflineSyncService;

  SOSViewModel({
    AccidentMonitorViewModel? accidentMonitor,
    AlertService? alertService,
    FirebaseService? firebaseService,
    FirebaseAuthService? authService,
    GPSLocationService? gpsService,
    OfflineSyncService? offlineSyncService,
    InAppNotificationService? inAppNotificationService,
    bool bindToAccidentMonitor = true,
  }) : _ownsAccidentMonitor = accidentMonitor == null,
       _ownsOfflineSyncService = offlineSyncService == null,
       _accidentMonitor = accidentMonitor ?? AccidentMonitorViewModel(),
       _alertService = alertService ?? AlertService(),
       _firebaseService = firebaseService ?? FirebaseService(),
       _authService = authService ?? FirebaseAuthService(),
       _gpsService = gpsService ?? GPSLocationService(),
       _offlineSyncService = offlineSyncService ?? OfflineSyncService(),
       _inAppNotificationService =
           inAppNotificationService ?? InAppNotificationService() {
    if (bindToAccidentMonitor) {
      _attachMonitorListener();
      _syncFromAccidentMonitor();
    }
  }

  static const int _manualCountdownSeconds = 10;
  static const int _fallbackDetectedCountdownSeconds = 10;

  static const Duration _emergencyGpsRequestTimeout = Duration(seconds: 8);
  static const Duration _emergencyGpsTotalTimeout = Duration(seconds: 10);
  static const Duration _firestoreWriteTimeout = Duration(seconds: 15);
  static const Duration _offlineSaveTimeout = Duration(seconds: 5);
  static const Duration _lastKnownPositionTimeout = Duration(seconds: 3);
  static const Duration _inAppNotificationTimeout = Duration(seconds: 6);

  SOSState currentState = SOSState.monitoring;

  String statusMessage = 'sos.status_monitoring'.tr();
  String aiVoiceText = 'sos.ai_monitoring'.tr();
  String detectedSeverity = 'sos.severity_none'.tr();
  String lastTriggerReason = '';

  int countdown = 0;
  int initialCountdown = 0;

  double severityScore = 0.0;
  double lastImpact = 0.0;
  double lastRotation = 0.0;

  double? lastLatitude;
  double? lastLongitude;

  Timer? _timer;

  bool _isHandlingEmergency = false;
  bool _isEmergencyActionInFlight = false;
  bool _isDisposed = false;
  bool _isBound = false;
  bool _isMonitorListenerAttached = false;
  bool _isManualSOSActive = false;
  bool _manualEmergencyExecuted = false;

  String? _alertProjectionCreatedForAccidentId;
  String? _inAppNotificationCreatedForAccidentId;
  DetectionEvent? _boundEvent;

  String? _activeCallContactName;
  String? get activeCallContactName => _activeCallContactName;

  bool get isEmergencyFlowActive =>
      currentState == SOSState.evaluating ||
      currentState == SOSState.countingDown ||
      currentState == SOSState.listening ||
      currentState == SOSState.sendingAlert ||
      currentState == SOSState.callingContact;

  bool get canCancel =>
      currentState == SOSState.evaluating ||
      currentState == SOSState.countingDown ||
      currentState == SOSState.listening;

  bool get isTerminalState =>
      currentState == SOSState.alertSent ||
      currentState == SOSState.cancelled ||
      currentState == SOSState.error;

  bool get isListeningMode => currentState == SOSState.listening;

  double get progressValue {
    if (initialCountdown <= 0) return 0.0;
    return (countdown / initialCountdown).clamp(0.0, 1.0);
  }

  String get impactText => lastImpact.toStringAsFixed(2);
  String get rotationText => lastRotation.toStringAsFixed(2);
  String get severityScoreText => severityScore.toStringAsFixed(1);

  String get countdownLabel {
    if (currentState == SOSState.listening) {
      return 'sos.countdown_label_listening'.tr();
    }

    if (currentState == SOSState.countingDown) {
      return 'sos.countdown_label_counting'.tr();
    }

    return '';
  }

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // ==========================================
  // 🔗 Binding with AccidentMonitorViewModel
  // ==========================================

  void _attachMonitorListener() {
    if (_isMonitorListenerAttached) return;

    _accidentMonitor.addListener(_handleMonitorChanged);
    _isMonitorListenerAttached = true;
  }

  void startSmartMonitoring() {
    if (_isDisposed) return;

    _attachMonitorListener();
    _isBound = true;
    _syncFromAccidentMonitor();
    _safeNotify();
  }

  void _handleMonitorChanged() {
    if (_isDisposed) return;
    _syncFromAccidentMonitor();
  }

  void _syncFromAccidentMonitor() {
    if (_isDisposed) return;

    if (_isManualSOSActive) {
      return;
    }

    final event = _accidentMonitor.lastDetectionEvent;
    _boundEvent = event;

    if (event != null) {
      lastImpact = event.triggerFrame.gForce;
      lastRotation = event.triggerFrame.rotation;
      severityScore = event.confidenceScore.clamp(0.0, 100.0).toDouble();
      detectedSeverity = _mapSeverityToArabic(event.severityLevel);
      lastLatitude = event.latitude;
      lastLongitude = event.longitude;
    }

    if (_accidentMonitor.isCountdownActive && event != null) {
      _isHandlingEmergency = true;

      countdown = _accidentMonitor.countdown;
      initialCountdown = _accidentMonitor.initialCountdown;

      if (currentState != SOSState.callingContact) {
        currentState = countdown <= 5
            ? SOSState.listening
            : SOSState.countingDown;

        statusMessage = _buildCountdownMessage(event);
        aiVoiceText = _buildCountdownVoiceMessage(event);
      }

      _safeNotify();
      return;
    }

    if (!_accidentMonitor.isCountdownActive && event != null && _isBound) {
      _isHandlingEmergency = false;

      if (!_isEmergencyActionInFlight &&
          currentState != SOSState.sendingAlert &&
          currentState != SOSState.alertSent &&
          currentState != SOSState.cancelled &&
          currentState != SOSState.error) {
        _executeEmergencyActionSafely('auto_countdown_finished');
      }

      return;
    }

    if (event == null && !_isHandlingEmergency && !_isEmergencyActionInFlight) {
      _resetToMonitoringState(notify: true);
    }
  }

  void seedDetectedEvent(DetectionEvent event) {
    if (_isDisposed) return;

    _boundEvent = event;
    lastImpact = event.triggerFrame.gForce;
    lastRotation = event.triggerFrame.rotation;
    severityScore = event.confidenceScore.clamp(0.0, 100.0).toDouble();
    detectedSeverity = _mapSeverityToArabic(event.severityLevel);
    lastLatitude = event.latitude;
    lastLongitude = event.longitude;

    countdown = event.countdownDurationSeconds;
    initialCountdown = event.countdownDurationSeconds;

    currentState = countdown <= 5 ? SOSState.listening : SOSState.countingDown;

    statusMessage = _buildCountdownMessage(event);
    aiVoiceText = _buildCountdownVoiceMessage(event);

    _safeNotify();
  }

  // ==========================================
  // 🧠 Passive Auto Flow + Manual Override
  // ==========================================

  void startManualSOS({required String triggerReason}) {
    if (_isDisposed) return;
    if (triggerReason != 'manual_sos') return;
    if (isTerminalState || currentState == SOSState.sendingAlert) return;
    if (_isManualSOSActive || _manualEmergencyExecuted) return;

    if (_accidentMonitor.isCountdownActive ||
        _accidentMonitor.lastDetectionEvent != null ||
        _boundEvent != null) {
      debugPrint(
        'SOSViewModel: Manual SOS blocked because an auto event is active',
      );
      return;
    }

    _timer?.cancel();
    _timer = null;

    _isManualSOSActive = true;
    _manualEmergencyExecuted = false;
    _isHandlingEmergency = true;
    _isEmergencyActionInFlight = false;

    lastTriggerReason = triggerReason;

    countdown = _manualCountdownSeconds;
    initialCountdown = _manualCountdownSeconds;

    currentState = SOSState.countingDown;
    detectedSeverity = 'sos.severity_manual'.tr();
    statusMessage = 'sos.status_manual_sos_active'.tr();
    aiVoiceText = 'sos.ai_manual_sos'.tr();

    _safeNotify();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      if (!_isManualSOSActive ||
          currentState == SOSState.cancelled ||
          currentState == SOSState.alertSent ||
          currentState == SOSState.error ||
          currentState == SOSState.sendingAlert) {
        timer.cancel();
        _timer = null;
        return;
      }

      if (countdown > 1) {
        countdown--;
        if (currentState != SOSState.callingContact) {
          currentState = countdown <= 5
              ? SOSState.listening
              : SOSState.countingDown;
        }
        _safeNotify();
        return;
      }

      countdown = 0;
      timer.cancel();
      _timer = null;
      _safeNotify();

      _finishManualCountdown();
    });
  }

  void _finishManualCountdown() {
    if (_isDisposed) return;
    if (!_isManualSOSActive || _manualEmergencyExecuted) return;

    _manualEmergencyExecuted = true;
    _isManualSOSActive = false;

    _executeEmergencyActionSafely('manual_sos');
  }

  /// Legacy/fallback entry point.
  void handleDetectedAccident({
    required double gForce,
    required double rotation,
    String triggerReason = 'automatic_detection',
  }) {
    if (_isDisposed) return;
    if (_isEmergencyActionInFlight || currentState == SOSState.sendingAlert) {
      return;
    }

    if (isEmergencyFlowActive) {
      debugPrint(
        'SOSViewModel: Ignoring detected accident because emergency flow is already active',
      );
      return;
    }

    _timer?.cancel();
    _timer = null;

    lastTriggerReason = triggerReason;
    lastImpact = gForce;
    lastRotation = rotation;
    severityScore = 40.0;
    detectedSeverity = 'حادث محتمل';

    countdown = _fallbackDetectedCountdownSeconds;
    initialCountdown = _fallbackDetectedCountdownSeconds;

    currentState = SOSState.countingDown;
    statusMessage = 'sos.status_fallback_event'.tr();
    aiVoiceText = 'sos.ai_fallback_event'.tr();
    _isHandlingEmergency = true;

    _safeNotify();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      if (currentState == SOSState.cancelled ||
          currentState == SOSState.alertSent ||
          currentState == SOSState.error ||
          currentState == SOSState.sendingAlert) {
        timer.cancel();
        _timer = null;
        return;
      }

      if (countdown > 1) {
        countdown--;
        if (currentState != SOSState.callingContact) {
          currentState = countdown <= 5
              ? SOSState.listening
              : SOSState.countingDown;
        }
        _safeNotify();
        return;
      }

      countdown = 0;
      timer.cancel();
      _timer = null;
      _safeNotify();

      _executeEmergencyActionSafely(triggerReason);
    });
  }

  String _buildCountdownMessage(DetectionEvent event) {
    switch (AppThresholds.normalizeSeverityLevel(event.severityLevel)) {
      case AppThresholds.severityCritical:
        return 'sos.status_countdown_critical'.tr();
      case AppThresholds.severityHigh:
        return 'sos.status_countdown_high'.tr();
      case AppThresholds.severityMedium:
        return 'sos.status_countdown_medium'.tr();
      case AppThresholds.severityLow:
        return 'sos.status_countdown_low'.tr();
      case AppThresholds.severityIgnored:
      default:
        return 'sos.status_countdown_default'.tr();
    }
  }

  String _buildCountdownVoiceMessage(DetectionEvent event) {
    switch (AppThresholds.normalizeSeverityLevel(event.severityLevel)) {
      case AppThresholds.severityCritical:
        return 'sos.ai_countdown_critical'.tr();
      case AppThresholds.severityHigh:
        return 'sos.ai_countdown_high'.tr();
      case AppThresholds.severityMedium:
        return 'sos.ai_countdown_medium'.tr();
      case AppThresholds.severityLow:
        return 'sos.ai_countdown_low'.tr();
      case AppThresholds.severityIgnored:
      default:
        return 'sos.ai_countdown_default'.tr();
    }
  }

  String _mapSeverityToArabic(String severityLevel) {
    if (severityLevel.trim().toLowerCase() == 'manual_sos') {
      return 'sos.severity_manual'.tr();
    }

    return AppThresholds.severityDisplayArabic(severityLevel);
  }

  // ==========================================
  // ❌ Cancel / Confirm Safe
  // ==========================================

  void cancelSOS() {
    _timer?.cancel();
    _timer = null;

    _isManualSOSActive = false;
    _manualEmergencyExecuted = false;
    _isEmergencyActionInFlight = false;

    if (_accidentMonitor.isCountdownActive) {
      _accidentMonitor.cancelSOS();
    }

    unawaited(CriticalAlertService.cancelCriticalAlert());

    currentState = SOSState.cancelled;
    statusMessage = 'sos.status_cancelled'.tr();
    aiVoiceText = 'sos.ai_cancelled'.tr();
    _isHandlingEmergency = false;
    _activeCallContactName = null;

    _safeNotify();

    Future.delayed(const Duration(seconds: 3), () {
      if (_isDisposed) return;

      if (currentState == SOSState.cancelled) {
        returnToMonitoring();
      }
    });
  }

  void confirmUserSafe() {
    cancelSOS();
  }

  void returnToMonitoring() {
    _timer?.cancel();
    _timer = null;

    _isManualSOSActive = false;
    _manualEmergencyExecuted = false;
    _isEmergencyActionInFlight = false;

    if (_isBound || _boundEvent != null) {
      _accidentMonitor.clearLastDetectionEvent();
    }

    _resetToMonitoringState(notify: true);
  }

  // ==========================================
  // 🚨 Emergency Action
  // ==========================================

  void _executeEmergencyActionSafely(String reason) {
    executeEmergencyAction(reason).catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      debugPrint('❌ SOSViewModel: Emergency action failed - $error');
      debugPrintStack(stackTrace: stackTrace);

      if (_isDisposed) return;

      currentState = SOSState.error;
      statusMessage = 'sos.status_error_generic'.tr();
      aiVoiceText = 'sos.ai_error_generic'.tr();
      _isHandlingEmergency = false;
      _isEmergencyActionInFlight = false;

      _safeNotify();
    });
  }

  Future<void> executeEmergencyAction(String reason) async {
    if (_isDisposed) return;

    final isManualReport = _isManualReportReason(reason);

    _timer?.cancel();
    _timer = null;

    if (isManualReport) {
      _isManualSOSActive = false;
      _manualEmergencyExecuted = true;
    }

    if (_isEmergencyActionInFlight || currentState == SOSState.sendingAlert) {
      debugPrint('⚠️ SOSViewModel: Already sending alert, skipping duplicate');
      return;
    }

    _isEmergencyActionInFlight = true;

    if (_accidentMonitor.isCountdownActive) {
      _accidentMonitor.cancelSOS();
    }

    final user = _authService.currentUser;

    if (user == null) {
      currentState = SOSState.error;
      statusMessage = 'sos.status_error_no_user'.tr();
      aiVoiceText = 'sos.ai_error_no_user'.tr();
      _isHandlingEmergency = false;
      _isEmergencyActionInFlight = false;
      _safeNotify();
      return;
    }

    currentState = SOSState.sendingAlert;
    statusMessage = 'sos.status_sending_locating'.tr();
    aiVoiceText = 'sos.ai_sending'.tr();
    lastTriggerReason = reason;
    _isHandlingEmergency = true;

    _safeNotify();

    try {
      final LocationResult<dynamic> positionResult = await _gpsService
          .getCurrentPosition(timeout: _emergencyGpsRequestTimeout)
          .then<LocationResult<dynamic>>((result) => result)
          .timeout(
            _emergencyGpsTotalTimeout,
            onTimeout: () {
              debugPrint('⏱️ SOSViewModel: GPS fetch timed out');

              return LocationResult.failure(
                LocationException(
                  message: 'Emergency GPS fetch timed out',
                  code: 'emergency-position-timeout',
                ),
              );
            },
          );

      if (_isDisposed) return;

      final resolvedLocation = await _resolveEmergencyLocation(positionResult);

      if (_isDisposed) return;

      if (resolvedLocation == null) {
        currentState = SOSState.error;
        statusMessage = 'sos.status_error_no_location'.tr();
        aiVoiceText = 'sos.ai_error_no_location'.tr();
        _isHandlingEmergency = false;
        _isEmergencyActionInFlight = false;
        _safeNotify();
        return;
      }

      lastLatitude = resolvedLocation.latitude;
      lastLongitude = resolvedLocation.longitude;

      // ── Reverse Geocoding ───────────────────────────────────────────────
      // Performed ONCE at the moment of sending. Never blocks or delays SOS.
      final locationName = await _reverseGeocode(
        resolvedLocation.latitude,
        resolvedLocation.longitude,
      );
      // ───────────────────────────────────────────────────────────────────

      statusMessage = 'sos.status_sending_uploading'.tr();
      _safeNotify();

      final reportGForce = isManualReport ? 0.0 : lastImpact;
      final reportRotation = isManualReport ? 0.0 : lastRotation;
      final reportSeverityScore = isManualReport
          ? 100.0
          : severityScore.clamp(0.0, 100.0).toDouble();
      final reportSeverityLevel = _resolveRawSeverity(isManualReport);
      final reportSeverityDisplay = _resolveDisplaySeverity(isManualReport);
      final emergencySource = _resolveEmergencySource(isManualReport);

      bool success = false;
      String? accidentId;

      try {
        final accidentResult = await _firebaseService
            .reportAccident(
              userId: user.uid,
              gForce: reportGForce,
              rotation: reportRotation,
              severityScore: reportSeverityScore,
              severityLevel: reportSeverityLevel,
              severityDisplay: reportSeverityDisplay,
              latitude: resolvedLocation.latitude,
              longitude: resolvedLocation.longitude,
              locationName: locationName,
              reason: reason,
              autoDetected: !isManualReport,
              additionalData: {
                'source': 'sos_emergency_action',
                'emergencySource': emergencySource,
                'alertSource': emergencySource,
                'reportType': emergencySource,
                'triggerReason': reason,
                'isManualSOS': isManualReport,
                'locationSource': resolvedLocation.source,
                if (_boundEvent != null) 'eventId': _boundEvent!.eventId,
                if (_boundEvent != null)
                  'eventSeverity': _boundEvent!.severityLevel,
                if (_boundEvent != null)
                  'confidenceScore': _boundEvent!.confidenceScore,
                if (_boundEvent != null)
                  'countdownDurationSeconds':
                      _boundEvent!.countdownDurationSeconds,
              },
            )
            .timeout(
              _firestoreWriteTimeout,
              onTimeout: () {
                debugPrint('⏱️ SOSViewModel: Firestore write timed out');
                throw TimeoutException('Firestore write timeout');
              },
            );

        if (_isDisposed) return;

        success = accidentResult.isSuccess;
        accidentId = accidentResult.data;

        if (success) {
          debugPrint(
            '✅ SOSViewModel: Accident reported successfully: $accidentId',
          );
        } else {
          debugPrint(
            '⚠️ SOSViewModel: Accident report failed - ${accidentResult.error}',
          );
        }
      } on TimeoutException catch (e) {
        debugPrint('⏱️ SOSViewModel: Timeout during accident reporting - $e');
        success = false;
      } catch (e, stackTrace) {
        debugPrint('⚠️ SOSViewModel: Failed to send report online - $e');
        debugPrintStack(stackTrace: stackTrace);
        success = false;
      }

      if (!success) {
        await _handleOfflineFallback(
          userId: user.uid,
          gForce: reportGForce,
          rotation: reportRotation,
          severityScore: reportSeverityScore,
          severityLevel: reportSeverityLevel,
          severityDisplay: reportSeverityDisplay,
          reason: reason,
          latitude: resolvedLocation.latitude,
          longitude: resolvedLocation.longitude,
          locationSource: resolvedLocation.source,
          emergencySource: emergencySource,
          isManualReport: isManualReport,
          eventId: _boundEvent?.eventId,
        );

        return;
      }

      if (accidentId != null && accidentId.trim().isNotEmpty) {
        await _createAlertProjectionOnce(
          accidentId: accidentId,
          userId: user.uid,
          gForce: reportGForce,
          rotation: reportRotation,
          severityScore: reportSeverityScore,
          rawSeverity: reportSeverityLevel,
          displaySeverity: reportSeverityDisplay,
          detectionReason: reason,
          latitude: resolvedLocation.latitude,
          longitude: resolvedLocation.longitude,
          locationName: locationName,
          autoDetected: !isManualReport,
          emergencySource: emergencySource,
          eventId: _boundEvent?.eventId,
        );

        await _createEmergencyReportSentNotificationOnce(
          accidentId: accidentId,
          userId: user.uid,
          isManualReport: isManualReport,
          emergencySource: emergencySource,
          severityLevel: reportSeverityLevel,
          severityDisplay: reportSeverityDisplay,
          reason: reason,
          latitude: resolvedLocation.latitude,
          longitude: resolvedLocation.longitude,
          locationSource: resolvedLocation.source,
          eventId: _boundEvent?.eventId,
        );
      }

      currentState = SOSState.alertSent;
      statusMessage = 'sos.status_sent_online'.tr();
      aiVoiceText = 'sos.ai_sent'.tr();

      await _handleCriticalLocalAlertIfNeeded(
        isManualReport: isManualReport,
        severityScore: reportSeverityScore,
        severityLevel: reportSeverityLevel,
        sentOnline: true,
      );
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ SOSViewModel: Operation timed out - $e');
      debugPrintStack(stackTrace: stackTrace);

      if (_isDisposed) return;

      currentState = SOSState.error;
      statusMessage = 'sos.status_error_timeout'.tr();
      aiVoiceText = 'sos.ai_error_timeout'.tr();
    } catch (e, stackTrace) {
      debugPrint('❌ SOSViewModel executeEmergencyAction error: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (_isDisposed) return;

      currentState = SOSState.error;
      statusMessage = 'sos.status_error_generic'.tr();
      aiVoiceText = 'sos.ai_error_generic'.tr();
    } finally {
      _isHandlingEmergency = false;
      _isEmergencyActionInFlight = false;
      _safeNotify();
    }
  }

  Future<_ResolvedEmergencyLocation?> _resolveEmergencyLocation(
    LocationResult<dynamic> positionResult,
  ) async {
    final previousLatitude = lastLatitude;
    final previousLongitude = lastLongitude;

    if (positionResult.isSuccess && positionResult.data != null) {
      final latitude = positionResult.data!.latitude as double?;
      final longitude = positionResult.data!.longitude as double?;

      if (_isValidCoordinatePair(latitude, longitude)) {
        debugPrint(
          '✅ SOSViewModel: Using fresh GPS position ($latitude, $longitude)',
        );

        return _ResolvedEmergencyLocation(
          latitude: latitude!,
          longitude: longitude!,
          source: 'fresh_gps',
        );
      }
    }

    if (positionResult.isFailure) {
      debugPrint(
        '⚠️ SOSViewModel: Fresh GPS unavailable - '
        '${positionResult.error?.code}: ${positionResult.error?.message}',
      );
    }

    debugPrint('🔄 SOSViewModel: Attempting OS last known position...');

    try {
      final lastKnownResult = await _gpsService.getLastKnownPosition().timeout(
        _lastKnownPositionTimeout,
        onTimeout: () {
          debugPrint('⏱️ SOSViewModel: Last known position timeout');

          return LocationResult.failure(
            LocationException(
              message: 'Last known position timeout',
              code: 'last-position-timeout',
            ),
          );
        },
      );

      if (_isDisposed) return null;

      if (lastKnownResult.isSuccess && lastKnownResult.data != null) {
        final latitude = lastKnownResult.data!.latitude;
        final longitude = lastKnownResult.data!.longitude;

        if (_isValidCoordinatePair(latitude, longitude)) {
          debugPrint(
            '✅ SOSViewModel: Using OS last known position ($latitude, $longitude)',
          );

          return _ResolvedEmergencyLocation(
            latitude: latitude,
            longitude: longitude,
            source: 'last_known_position',
          );
        }
      } else {
        debugPrint(
          '⚠️ SOSViewModel: OS last known position unavailable - '
          '${lastKnownResult.error?.code}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ SOSViewModel: Last known position error - $e');
      debugPrintStack(stackTrace: stackTrace);
    }

    final eventLatitude = _boundEvent?.latitude;
    final eventLongitude = _boundEvent?.longitude;

    if (_isValidCoordinatePair(eventLatitude, eventLongitude)) {
      debugPrint(
        '✅ SOSViewModel: Using detection event location '
        '($eventLatitude, $eventLongitude)',
      );

      return _ResolvedEmergencyLocation(
        latitude: eventLatitude!,
        longitude: eventLongitude!,
        source: 'detection_event',
      );
    }

    if (_isValidCoordinatePair(previousLatitude, previousLongitude)) {
      debugPrint(
        '✅ SOSViewModel: Using previous ViewModel location '
        '($previousLatitude, $previousLongitude)',
      );

      return _ResolvedEmergencyLocation(
        latitude: previousLatitude!,
        longitude: previousLongitude!,
        source: 'previous_viewmodel_location',
      );
    }

    return null;
  }

  Future<void> _handleOfflineFallback({
    required String userId,
    required double gForce,
    required double rotation,
    required double severityScore,
    required String severityLevel,
    required String severityDisplay,
    required String reason,
    required double latitude,
    required double longitude,
    required String locationSource,
    required String emergencySource,
    required bool isManualReport,
    String? eventId,
  }) async {
    debugPrint('💾 SOSViewModel: Saving report offline for later sync');

    try {
      final offlineSaved = await _offlineSyncService
          .saveReportLocally(
            uid: userId,
            gForce: gForce,
            severity: severityLevel,
            severityDisplay: severityDisplay,
            lat: latitude,
            lng: longitude,
            rotation: rotation,
            severityScore: severityScore,
            reason: reason,
            source: isManualReport
                ? 'manual_sos_offline'
                : 'auto_detection_offline',
            emergencySource: emergencySource,
            autoDetected: !isManualReport,
            eventId: eventId,
            additionalData: {
              'triggerReason': reason,
              'isManualSOS': isManualReport,
              'locationSource': locationSource,
            },
          )
          .timeout(
            _offlineSaveTimeout,
            onTimeout: () {
              debugPrint('⏱️ SOSViewModel: Offline save timed out');
              return Future.value(false);
            },
          );

      if (_isDisposed) return;

      if (offlineSaved) {
        currentState = SOSState.alertSent;
        statusMessage = 'sos.status_sent_offline'.tr();
        aiVoiceText = 'sos.ai_offline_sent'.tr();

        await _handleCriticalLocalAlertIfNeeded(
          isManualReport: isManualReport,
          severityScore: severityScore,
          severityLevel: severityLevel,
          sentOnline: false,
        );
      } else {
        currentState = SOSState.error;
        statusMessage = 'sos.status_offline_failed'.tr();
        aiVoiceText = 'sos.ai_offline_failed'.tr();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ SOSViewModel: Offline save failed - $e');
      debugPrintStack(stackTrace: stackTrace);

      if (_isDisposed) return;

      currentState = SOSState.error;
      statusMessage = 'sos.status_offline_failed'.tr();
      aiVoiceText = 'sos.ai_offline_failed'.tr();
    }
  }

  // ==========================================
  // Severity / Source Helpers
  // ==========================================

  bool _isManualReportReason(String reason) {
    return reason.trim().toLowerCase() == 'manual_sos' && _boundEvent == null;
  }

  String _resolveRawSeverity(bool isManualReport) {
    if (isManualReport) return AppThresholds.severityCritical;

    final eventSeverity = _boundEvent?.severityLevel.trim().toLowerCase();

    if (eventSeverity != null && eventSeverity.isNotEmpty) {
      final normalized = AppThresholds.normalizeSeverityLevel(eventSeverity);

      if (_isKnownMachineSeverity(normalized)) {
        return normalized;
      }

      debugPrint('⚠️ SOSViewModel: Event has unknown severity: $eventSeverity');
    }

    return AppThresholds.severityLevelFromScore(severityScore);
  }

  String _resolveDisplaySeverity(bool isManualReport) {
    if (isManualReport) return 'sos.severity_manual_critical'.tr();

    final eventSeverity = _boundEvent?.severityLevel.trim();

    if (eventSeverity != null && eventSeverity.isNotEmpty) {
      return _mapSeverityToArabic(eventSeverity);
    }

    return detectedSeverity.trim().isNotEmpty
        ? detectedSeverity.trim()
        : 'sos.severity_unspecified'.tr();
  }

  String _resolveEmergencySource(bool isManualReport) {
    if (isManualReport) return 'manual_sos';
    return 'auto_detection';
  }

  bool _isKnownMachineSeverity(String? severity) {
    return severity == AppThresholds.severityCritical ||
        severity == AppThresholds.severityHigh ||
        severity == AppThresholds.severityMedium ||
        severity == AppThresholds.severityLow;
  }

  bool _shouldTriggerCriticalLocalAlert({
    required bool isManualReport,
    required double severityScore,
    required String severityLevel,
  }) {
    if (isManualReport) return true;

    final normalizedSeverity = AppThresholds.normalizeSeverityLevel(
      severityLevel,
    );

    return normalizedSeverity == AppThresholds.severityCritical ||
        severityScore >= AppThresholds.severityScoreCritical;
  }

  Future<void> _handleCriticalLocalAlertIfNeeded({
    required bool isManualReport,
    required double severityScore,
    required String severityLevel,
    required bool sentOnline,
  }) async {
    final shouldTrigger = _shouldTriggerCriticalLocalAlert(
      isManualReport: isManualReport,
      severityScore: severityScore,
      severityLevel: severityLevel,
    );

    if (!shouldTrigger) {
      await CriticalAlertService.cancelCriticalAlert();
      return;
    }

    final title = isManualReport
        ? '🚨 استغاثة يدوية حرجة'
        : '🚨 حادث حرج تم رصده';

    final message = sentOnline
        ? (isManualReport
              ? 'تم إرسال بلاغ استغاثة يدوي مع موقع المستخدم وبياناته الطبية.'
              : 'تم إرسال بلاغ حادث حرج مع موقع المستخدم وبياناته الطبية.')
        : (isManualReport
              ? 'تم حفظ بلاغ الاستغاثة محلياً وسيتم إرساله عند عودة الاتصال.'
              : 'تم حفظ بلاغ الحادث الحرج محلياً وسيتم إرساله عند عودة الاتصال.');

    await CriticalAlertService.triggerCriticalAlert(
      title: title,
      message: message,
      severityScore: severityScore.clamp(0.0, 100.0).toDouble(),
    );
  }
  // ==========================================
  // 🗺️ Reverse Geocoding
  // ==========================================

  /// Converts [latitude]/[longitude] into a human-readable address string.
  ///
  /// - Runs with a hard 4-second timeout so it NEVER delays an emergency SOS.
  /// - On any failure (no network, permission denied, timeout, empty result)
  ///   it immediately falls back to the raw coordinate string.
  /// - Raw lat/lng fields are never touched — this only produces the
  ///   `locationName` / `locationAddress` supplementary string.
  Future<String?> _reverseGeocode(double latitude, double longitude) async {
    try {
      final placemarks = await geo
          .placemarkFromCoordinates(latitude, longitude)
          .timeout(const Duration(seconds: 4));

      if (placemarks.isEmpty) {
        debugPrint('📍 SOSViewModel: Reverse geocoding returned empty list');
        return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
      }

      final p = placemarks.first;

      // Build a clean, non-null address from available placemark components.
      final parts = <String>[
        if ((p.street ?? '').trim().isNotEmpty) p.street!.trim(),
        if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
        if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
        if ((p.administrativeArea ?? '').trim().isNotEmpty)
          p.administrativeArea!.trim(),
        if ((p.country ?? '').trim().isNotEmpty) p.country!.trim(),
      ];

      final address = parts.join(', ');
      if (address.trim().isEmpty) {
        return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
      }

      debugPrint('📍 SOSViewModel: Reverse geocoded to "$address"');
      return address;
    } on TimeoutException {
      debugPrint('⏱️ SOSViewModel: Reverse geocoding timed out — using coords');
      return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    } catch (e) {
      debugPrint('⚠️ SOSViewModel: Reverse geocoding failed ($e) — using coords');
      return '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
    }
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

  // ==========================================
  // Alert Projection
  // ==========================================

  Future<void> _createAlertProjectionOnce({
    required String accidentId,
    required String userId,
    required double gForce,
    required double rotation,
    required double severityScore,
    required String rawSeverity,
    required String displaySeverity,
    required String detectionReason,
    required double latitude,
    required double longitude,
    required bool autoDetected,
    required String emergencySource,
    String? locationName,
    String? eventId,
  }) async {
    if (_alertProjectionCreatedForAccidentId == accidentId) {
      debugPrint(
        'SOSViewModel: Alert projection already created for $accidentId',
      );
      return;
    }

    final projectionCreated = await _alertService
        .createAlertProjectionFromAccident(
          accidentId: accidentId,
          userId: userId,
          gForce: gForce,
          rotation: rotation,
          severityScore: severityScore,
          rawSeverity: rawSeverity,
          displaySeverity: displaySeverity,
          detectionReason: detectionReason,
          latitude: latitude,
          longitude: longitude,
          autoDetected: autoDetected,
          emergencySource: emergencySource,
          locationName: locationName,
          eventId: eventId,
        );

    if (projectionCreated) {
      _alertProjectionCreatedForAccidentId = accidentId;
    } else {
      debugPrint(
        '⚠️ SOSViewModel: Alert projection failed for accident $accidentId',
      );
    }
  }

  // ==========================================
  // 🔔 In-App Notification Center
  // ==========================================

  Future<void> _createEmergencyReportSentNotificationOnce({
    required String accidentId,
    required String userId,
    required bool isManualReport,
    required String emergencySource,
    required String severityLevel,
    required String severityDisplay,
    required String reason,
    required double latitude,
    required double longitude,
    required String locationSource,
    String? eventId,
  }) async {
    if (_isDisposed) return;

    final safeAccidentId = accidentId.trim();

    if (safeAccidentId.isEmpty) {
      return;
    }

    if (_inAppNotificationCreatedForAccidentId == safeAccidentId) {
      debugPrint(
        'SOSViewModel: In-app notification already created for $safeAccidentId',
      );
      return;
    }

    final normalizedSeverity = AppThresholds.normalizeSeverityLevel(
      severityLevel,
    );

    final isCritical =
        isManualReport ||
        normalizedSeverity == AppThresholds.severityCritical ||
        severityScore >= AppThresholds.severityScoreCritical;

    final titleAr = isManualReport
        ? 'تم إرسال استغاثة يدوية'
        : 'تم إرسال بلاغ طوارئ';

    final titleEn = isManualReport
        ? 'Manual SOS sent'
        : 'Emergency report sent';

    final bodyAr = isManualReport
        ? 'تم إرسال بلاغ الاستغاثة اليدوي مع الموقع والبيانات الطبية بنجاح.'
        : 'تم إرسال بلاغ الطوارئ مع موقع المستخدم وبيانات الحادث بنجاح.';

    final bodyEn = isManualReport
        ? 'Your manual SOS report was sent successfully with location and medical data.'
        : 'Your emergency report was sent successfully with location and incident data.';

    try {
      final created = await _inAppNotificationService
          .createNotification(
            uid: userId,
            type: 'emergency_report_sent',
            titleAr: titleAr,
            titleEn: titleEn,
            bodyAr: bodyAr,
            bodyEn: bodyEn,
            priority: isCritical ? 'critical' : 'high',
            source: 'sos_emergency_action',
            relatedAccidentId: safeAccidentId,
            payload: {
              'accidentId': safeAccidentId,
              'emergencySource': emergencySource,
              'severityLevel': severityLevel,
              'severityDisplay': severityDisplay,
              'triggerReason': reason,
              'isManualSOS': isManualReport,
              'latitude': latitude,
              'longitude': longitude,
              'locationSource': locationSource,
              'sentOnline': true,
              if (eventId != null && eventId.trim().isNotEmpty)
                'eventId': eventId,
            },
          )
          .timeout(_inAppNotificationTimeout);

      if (created) {
        _inAppNotificationCreatedForAccidentId = safeAccidentId;

        debugPrint(
          '✅ SOSViewModel: In-app emergency notification created '
          '(accidentId=$safeAccidentId)',
        );
      } else {
        debugPrint(
          '⚠️ SOSViewModel: In-app emergency notification was not created',
        );
      }
    } on TimeoutException {
      debugPrint('⏱️ SOSViewModel: In-app emergency notification timeout');
    } catch (e, stackTrace) {
      debugPrint(
        '⚠️ SOSViewModel: Failed to create in-app emergency notification - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // 🎙️ Voice Commands
  // ==========================================

  void simulateVoiceCommand(String command) {
    if (_isDisposed) return;

    if (!isEmergencyFlowActive &&
        currentState != SOSState.listening &&
        currentState != SOSState.countingDown) {
      return;
    }

    final normalized = command.trim();

    if (normalized == 'أنا بخير') {
      cancelSOS();
      return;
    }

    if (normalized == 'حادث') {
      executeEmergencyAction(
        _isManualSOSActive ? 'manual_sos' : 'voice_confirmed_accident',
      );
      return;
    }

    if (normalized == 'اتصال') {
      initiateCallFlow();
      return;
    }
  }

  Future<void> initiateCallFlow() async {
    if (_isDisposed) return;
    if (currentState == SOSState.callingContact) return;

    final startedAt = DateTime.now();

    currentState = SOSState.callingContact;
    statusMessage = 'sos.status_opening_call'.tr();
    aiVoiceText = 'sos.ai_opening_call'.tr();
    _safeNotify();

    final contact = await getPrimaryEmergencyContact();

    if (_isDisposed || currentState != SOSState.callingContact) return;

    if (contact != null && (contact['name'] ?? '').trim().isNotEmpty) {
      _activeCallContactName = contact['name'];
      _safeNotify();
    }

    if (contact == null || (contact['phone'] ?? '').trim().isEmpty) {
      currentState = SOSState.error;
      statusMessage = 'sos.call_sheet_no_contact'.tr();
      aiVoiceText = 'sos.call_sheet_no_contact'.tr();
      _safeNotify();

      Future.delayed(const Duration(seconds: 3), () {
        if (!_isDisposed && currentState == SOSState.error) {
          returnToMonitoring();
        }
      });
      return;
    }

    final elapsed = DateTime.now().difference(startedAt);
    final remaining = const Duration(milliseconds: 2500) - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (_isDisposed || currentState != SOSState.callingContact) return;

    final launched = await openEmergencyContactDialer(contact['phone']!);

    if (_isDisposed) return;

    if (launched) {
      cancelSOS();
    } else {
      currentState = SOSState.error;
      statusMessage = 'sos.status_error_generic'.tr();
      aiVoiceText = 'sos.hint_error'.tr();
      _safeNotify();

      Future.delayed(const Duration(seconds: 3), () {
        if (!_isDisposed && currentState == SOSState.error) {
          returnToMonitoring();
        }
      });
    }
  }

  Future<Map<String, String>?> getPrimaryEmergencyContact() async {
    String? primaryPhone;
    String? primaryName;

    try {
      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString('emergency_contacts');
      if (rawJson != null && rawJson.trim().isNotEmpty) {
        final decoded = jsonDecode(rawJson);
        if (decoded is List && decoded.isNotEmpty) {
          final firstContact = decoded.first;
          if (firstContact is Map) {
            primaryPhone = (firstContact['phone'] ??
                    firstContact['phoneNumber'] ??
                    firstContact['mobile'])
                ?.toString();
            primaryName = firstContact['name']?.toString();
          }
        }
      }
    } catch (e) {
      debugPrint('SOSViewModel: Failed to decode local contacts $e');
    }

    if (primaryPhone == null || primaryPhone.trim().isEmpty) {
      debugPrint('SOSViewModel: Local cache missing, trying Firestore fallback');
      try {
        final user = _authService.currentUser;
        if (user != null) {
          final userDoc = await _firebaseService.getUser(user.uid);
          if (userDoc.isSuccess && userDoc.data != null) {
            final primaryData = userDoc.data!['primaryEmergencyContact'];
            if (primaryData is Map) {
              primaryPhone = (primaryData['phone'] ??
                      primaryData['phoneNumber'] ??
                      primaryData['mobile'])
                  ?.toString();
              primaryName = primaryData['name']?.toString();
            }
          }
        }
      } catch (e) {
        debugPrint('SOSViewModel: Failed to fetch from Firestore $e');
      }
    }

    if (primaryPhone != null && primaryPhone.trim().isNotEmpty) {
      return {
        'phone': primaryPhone.trim(),
        'name': primaryName?.trim().isNotEmpty == true
            ? primaryName!.trim()
            : 'sos.call_sheet_unknown_contact'.tr(),
      };
    }

    return null;
  }

  Future<bool> openEmergencyContactDialer(String phone) async {
    final cleanPhone = phone.trim();
    if (cleanPhone.isEmpty) return false;

    final callUri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      return await launchUrl(callUri);
    } catch (e) {
      debugPrint('SOSViewModel: Launch failed $e');
      return false;
    }
  }

  // ==========================================
  // 🔄 Reset
  // ==========================================

  void _resetToMonitoringState({bool notify = false}) {
    currentState = SOSState.monitoring;

    statusMessage = 'sos.status_monitoring'.tr();
    aiVoiceText = 'sos.ai_monitoring'.tr();
    detectedSeverity = 'sos.severity_none'.tr();
    lastTriggerReason = '';

    countdown = 10;
    initialCountdown = 10;

    severityScore = 0.0;
    lastImpact = 0.0;
    lastRotation = 0.0;

    lastLatitude = null;
    lastLongitude = null;

    _isHandlingEmergency = false;
    _isEmergencyActionInFlight = false;
    _isManualSOSActive = false;
    _manualEmergencyExecuted = false;
    _alertProjectionCreatedForAccidentId = null;
    _inAppNotificationCreatedForAccidentId = null;
    _boundEvent = null;
    _activeCallContactName = null;

    if (notify) {
      _safeNotify();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    _timer?.cancel();
    _timer = null;

    if (_isMonitorListenerAttached) {
      _accidentMonitor.removeListener(_handleMonitorChanged);
      _isMonitorListenerAttached = false;
    }

    if (_ownsAccidentMonitor) {
      _accidentMonitor.dispose();
    }

    if (_ownsOfflineSyncService) {
      unawaited(_offlineSyncService.dispose());
    }

    super.dispose();
  }
}

class _ResolvedEmergencyLocation {
  final double latitude;
  final double longitude;
  final String source;

  const _ResolvedEmergencyLocation({
    required this.latitude,
    required this.longitude,
    required this.source,
  });
}
