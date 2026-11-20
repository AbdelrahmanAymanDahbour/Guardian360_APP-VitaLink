import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_thresholds.dart';
import '../../../core/models/medical_profile_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/in_app_notification_service.dart';
import '../../accident_detection/models/detection_event.dart';
import '../../accident_detection/viewmodels/accident_monitor_viewmodel.dart';
import '../../auth/services/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    FirebaseAuthService? authService,
    FirebaseService? firebaseService,
    AccidentMonitorViewModel? accidentMonitor,
    InAppNotificationService? notificationService,
  }) : _ownsAccidentMonitor = accidentMonitor == null,
       _authService = authService ?? FirebaseAuthService(),
       _firebaseService = firebaseService ?? FirebaseService(),
       _notificationService = notificationService ?? InAppNotificationService(),
       _accidentMonitor = accidentMonitor ?? AccidentMonitorViewModel() {
    _activeUid = _authService.currentUser?.uid;
    unawaited(_initializeHome());
    _listenToAuthChanges();
  }

  final FirebaseAuthService _authService;
  final FirebaseService _firebaseService;
  final InAppNotificationService _notificationService;
  final AccidentMonitorViewModel _accidentMonitor;
  final bool _ownsAccidentMonitor;

  final PageController pageController = PageController();

  static const Duration _userFetchTimeout = Duration(seconds: 8);
  static const Duration _statusRefreshInterval = Duration(seconds: 20);

  bool _isDisposed = false;

  int selectedIndex = 0;

  StreamSubscription<User?>? _authStateSubscription;
  String? _activeUid;

  String userName = '...';
  String greeting = '';

  bool _isInitialized = false;
  bool _isLoading = true;
  bool _isProtectionEnabled = false;
  bool _isSystemHealthy = true;

  String _statusTitle = '';
  String _statusSubtitle = '';

  bool _tripActive = false;
  bool _accidentDetected = false;
  bool _isHandlingAccident = false;

  double _lastDetectedImpact = 0.0;
  double _lastDetectedRotation = 0.0;
  DateTime? _lastAccidentTime;

  String _selectedSensitivity = 'medium';
  DetectionEvent? _lastDetectionEvent;

  bool _isMedicalProfileComplete = false;
  bool _isMedicalCheckLoading = true;
  String _medicalRequirementMessage = '';

  int _unreadNotificationCount = 0;

  Timer? _statusRefreshTimer;
  StreamSubscription<int>? _unreadNotificationSubscription;

  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isProtectionEnabled => _isProtectionEnabled;
  bool get isSystemHealthy => _isSystemHealthy;
  bool get tripActive => _tripActive;
  bool get accidentDetected => _accidentDetected;
  bool get isHandlingAccident => _isHandlingAccident;

  bool get isMedicalProfileComplete => _isMedicalProfileComplete;
  bool get isMedicalCheckLoading => _isMedicalCheckLoading;
  String get medicalRequirementMessage => _medicalRequirementMessage;

  String get statusTitle => _statusTitle;
  String get statusSubtitle => _statusSubtitle;
  String get selectedSensitivity => _selectedSensitivity;

  int get unreadNotificationCount => _unreadNotificationCount;
  bool get hasUnreadNotifications => _unreadNotificationCount > 0;

  double get lastDetectedImpact => _lastDetectedImpact;
  double get lastDetectedRotation => _lastDetectedRotation;
  DateTime? get lastAccidentTime => _lastAccidentTime;

  DetectionEvent? get lastDetectionEvent => _lastDetectionEvent;

  bool get isCountdownActive => _accidentMonitor.isCountdownActive;
  int get countdown => _accidentMonitor.countdown;
  int get initialCountdown => _accidentMonitor.initialCountdown;
  double get countdownProgress => _accidentMonitor.countdownProgress;

  bool get isMonitoringActive =>
      _accidentMonitor.isMonitoring && _isProtectionEnabled && _tripActive;

  String get tripButtonText =>
      _tripActive ? 'home.btn_trip_end'.tr() : 'home.btn_trip_start'.tr();

  String get protectionButtonText => _isProtectionEnabled
      ? 'home.btn_protection_disable'.tr()
      : 'home.btn_protection_enable'.tr();

  String get monitoringStatusText {
    if (!_isMedicalProfileComplete) {
      return 'home.status_medical_required_title'.tr();
    }

    if (_accidentDetected) {
      return 'home.status_accident_detected_title'.tr();
    }

    if (_isProtectionEnabled && _tripActive && isMonitoringActive) {
      return 'home.status_active_monitoring_title'.tr();
    }

    if (_isProtectionEnabled && !_tripActive) {
      return 'home.status_protection_on_title'.tr();
    }

    return 'home.status_default_title'.tr();
  }

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // ==========================================
  // 🚀 Initialization
  // ==========================================

  Future<void> _initializeHome() async {
    // Defer initial string assignment until we have a locale context.
    _statusTitle = 'home.status_initializing'.tr();
    _statusSubtitle = 'home.status_subtitle_initializing'.tr();

    try {
      _isLoading = true;
      _isMedicalCheckLoading = true;

      _setSmartGreeting();
      _fetchDriverName();

      await _refreshMedicalProfileStatus();
      _syncInitialStatus();
      _startStatusRefreshTimer();
      _listenToUnreadNotificationCount();

      _isInitialized = true;
    } catch (e, stackTrace) {
      debugPrint('❌ HomeViewModel: initialization failed - $e');
      debugPrintStack(stackTrace: stackTrace);

      _isInitialized = false;
      _statusTitle = 'home.status_init_failed_title'.tr();
      _statusSubtitle = 'home.status_init_failed_subtitle'.tr();
      _isSystemHealthy = false;
    } finally {
      _isMedicalCheckLoading = false;
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<void> refreshHome() async {
    if (_isDisposed) return;

    _isLoading = true;
    _isMedicalCheckLoading = true;
    _safeNotify();

    try {
      _setSmartGreeting();
      _fetchDriverName();
      await _refreshMedicalProfileStatus();
      _updateStatusForProtectionState();
      _listenToUnreadNotificationCount();
    } finally {
      _isMedicalCheckLoading = false;
      _isLoading = false;
      _safeNotify();
    }
  }

  void _listenToAuthChanges() {
    _authStateSubscription = _authService.authStateChanges.listen((user) async {
      if (_isDisposed) return;
      
      final newUid = user?.uid;
      if (newUid == _activeUid) return;

      if (user == null) {
        _activeUid = null;
        _clearUserData(notify: true);
        return;
      }

      _activeUid = newUid;
      _clearUserData(notify: false);
      
      final uidAtStart = _activeUid;
      await refreshHome();
      if (_activeUid != uidAtStart) return;
    });
  }

  void _clearUserData({required bool notify}) {
    userName = 'Guardian User';
    greeting = '';
    _isMedicalProfileComplete = false;
    _unreadNotificationCount = 0;
    
    _unreadNotificationSubscription?.cancel();
    _unreadNotificationSubscription = null;
    
    _clearAccidentStateOnly();
    _accidentMonitor.clearLastDetectionEvent();
    
    if (notify) {
      _safeNotify();
    }
  }

  // ==========================================
  // 🏥 Medical Readiness Gate
  // ==========================================

  Future<void> _refreshMedicalProfileStatus() async {
    try {
      final user = _authService.currentUser;

      if (user == null) {
        _isMedicalProfileComplete = false;
        _medicalRequirementMessage = 'home.status_no_session_message'.tr();
        return;
      }

      final userResult = await _firebaseService
          .getUser(user.uid)
          .timeout(_userFetchTimeout);

      if (userResult.isSuccess && userResult.data != null) {
        final userData = userResult.data!;

        final profile = MedicalProfileModel.fromMap(userData);
        final modelReady = profile.hasRequiredEmergencyData;

        _isMedicalProfileComplete = modelReady;
      } else {
        _isMedicalProfileComplete = false;
      }

      _medicalRequirementMessage = _isMedicalProfileComplete
          ? ''
          : 'home.status_medical_error_message'.tr();
    } on TimeoutException {
      _isMedicalProfileComplete = false;
      _medicalRequirementMessage = 'home.status_medical_timeout_message'.tr();
      debugPrint('⏱️ HomeViewModel: medical status refresh timeout');
    } catch (e, stackTrace) {
      _isMedicalProfileComplete = false;
      _medicalRequirementMessage = 'home.status_medical_error_message'.tr();
      debugPrint('❌ HomeViewModel _refreshMedicalProfileStatus error: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> refreshMedicalStatusFromServer() async {
    if (_isDisposed) return;

    _isMedicalCheckLoading = true;
    _safeNotify();

    try {
      await _refreshMedicalProfileStatus();
      _updateStatusForProtectionState();
    } finally {
      _isMedicalCheckLoading = false;
      _safeNotify();
    }
  }

  Future<bool> ensureMedicalProfileReadyFromServer() async {
    await _refreshMedicalProfileStatus();

    if (_isMedicalProfileComplete) {
      return true;
    }

    _setMedicalRequiredStatus();
    _safeNotify();
    return false;
  }

  bool ensureMedicalProfileReady() {
    if (_isMedicalProfileComplete) {
      return true;
    }

    _setMedicalRequiredStatus();
    _safeNotify();
    return false;
  }

  void _setMedicalRequiredStatus() {
    _statusTitle = 'home.status_medical_required_title'.tr();
    _statusSubtitle = 'home.status_medical_required_subtitle'.tr();
    _isSystemHealthy = false;
    _medicalRequirementMessage =
        'home.status_medical_required_gate_message'.tr();
  }

  // ==========================================
  // 👤 User / Greeting
  // ==========================================

  void _fetchDriverName() {
    final user = _authService.currentUser;

    final displayName = user?.displayName?.trim();

    if (displayName != null && displayName.isNotEmpty) {
      userName = displayName.split(RegExp(r'\s+')).first;
      return;
    }

    final email = user?.email?.trim();

    if (email != null && email.isNotEmpty) {
      userName = email.split('@').first;
      return;
    }

    userName = 'Guardian User';
  }

  void _setSmartGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      greeting = 'greetings.morning'.tr();
    } else if (hour >= 12 && hour < 17) {
      greeting = 'greetings.afternoon'.tr();
    } else {
      greeting = 'greetings.evening'.tr();
    }
  }

  // ==========================================
  // 🧭 Status
  // ==========================================

  void _syncInitialStatus() {
    _updateStatusForProtectionState();
  }

  void _startStatusRefreshTimer() {
    _statusRefreshTimer?.cancel();

    _statusRefreshTimer = Timer.periodic(_statusRefreshInterval, (_) {
      if (_isDisposed) return;

      _setSmartGreeting();
      _refreshStatusSilently();
    });
  }

  void _refreshStatusSilently() {
    _updateStatusForProtectionState();
    _safeNotify();
  }

  void _updateStatusForProtectionState() {
    if (!_isMedicalProfileComplete) {
      _statusTitle = 'home.status_medical_required_title'.tr();
      _statusSubtitle = 'home.status_medical_required_subtitle'.tr();
      _isSystemHealthy = false;
      return;
    }

    if (_accidentDetected) {
      _statusTitle = 'home.status_accident_detected_title'.tr();
      _statusSubtitle = _buildEventStatusMessage(_lastDetectionEvent);
      _isSystemHealthy = false;
      return;
    }

    if (_isProtectionEnabled && _tripActive && isMonitoringActive) {
      _statusTitle = 'home.status_active_monitoring_title'.tr();
      _statusSubtitle = 'home.status_active_monitoring_subtitle'.tr();
      _isSystemHealthy = true;
      return;
    }

    if (_isProtectionEnabled && _tripActive && !isMonitoringActive) {
      _statusTitle = 'home.status_activating_title'.tr();
      _statusSubtitle = 'home.status_activating_subtitle'.tr();
      _isSystemHealthy = true;
      return;
    }

    if (_isProtectionEnabled && !_tripActive) {
      _statusTitle = 'home.status_protection_on_title'.tr();
      _statusSubtitle = 'home.status_protection_on_subtitle'.tr();
      _isSystemHealthy = true;
      return;
    }

    _statusTitle = 'home.status_default_title'.tr();
    _statusSubtitle = 'home.status_default_subtitle'.tr();
    _isSystemHealthy = true;
  }

  // ==========================================
  // 📄 Navigation Page State
  // ==========================================

  void changePage(int index) {
    if (_isDisposed) return;
    if (selectedIndex == index) return;
    if (!pageController.hasClients) {
      selectedIndex = index;
      _safeNotify();
      return;
    }

    selectedIndex = index;

    pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );

    _safeNotify();
  }

  void updateIndexFromScroll(int index) {
    if (_isDisposed) return;

    if (selectedIndex != index) {
      selectedIndex = index;
      _safeNotify();
    }
  }

  // ==========================================
  // 🛡️ Protection / Trip Control
  // ==========================================

  Future<bool> enableProtection() async {
    if (!await ensureMedicalProfileReadyFromServer()) {
      return false;
    }

    _isProtectionEnabled = true;
    _clearAccidentStateOnly();

    _updateStatusForProtectionState();
    await _tryStartMonitoring();

    _safeNotify();
    return true;
  }

  Future<void> disableProtection() async {
    _isProtectionEnabled = false;
    _clearAccidentStateOnly();

    await _accidentMonitor.stopMonitoring();

    if (_tripActive) {
      _statusTitle = 'home.status_trip_no_protection_title'.tr();
      _statusSubtitle = 'home.status_trip_no_protection_subtitle'.tr();
    } else {
      _statusTitle = 'home.status_system_off_title'.tr();
      _statusSubtitle = 'home.status_system_off_subtitle'.tr();
    }

    _isSystemHealthy = true;
    _safeNotify();
  }

  Future<bool> toggleProtection() async {
    if (_isProtectionEnabled) {
      await disableProtection();
      return true;
    }

    return enableProtection();
  }

  Future<bool> startTrip() async {
    if (!await ensureMedicalProfileReadyFromServer()) {
      return false;
    }

    _tripActive = true;
    _clearAccidentStateOnly();

    if (!_isProtectionEnabled) {
      _isProtectionEnabled = true;
    }

    _updateStatusForProtectionState();
    await _tryStartMonitoring();

    _safeNotify();
    return true;
  }

  Future<void> endTrip() async {
    _tripActive = false;
    _clearAccidentStateOnly();

    await _accidentMonitor.stopMonitoring();

    if (_isProtectionEnabled) {
      _statusTitle = 'home.status_trip_ended_title'.tr();
      _statusSubtitle = 'home.status_trip_ended_subtitle'.tr();
    } else {
      _statusTitle = 'home.status_default_title'.tr();
      _statusSubtitle = 'home.status_default_subtitle'.tr();
    }

    _isSystemHealthy = true;
    _safeNotify();
  }

  Future<bool> toggleTrip() async {
    if (_tripActive) {
      await endTrip();
      return true;
    }

    return startTrip();
  }

  void updateSensitivity(String level) {
    if (_isDisposed) return;

    final normalized = level.trim().toLowerCase();

    if (normalized != 'high' && normalized != 'medium' && normalized != 'low') {
      debugPrint('⚠️ HomeViewModel: Invalid sensitivity level: $level');
      return;
    }

    _selectedSensitivity = normalized;
    _accidentMonitor.setSensitivity(normalized);

    _safeNotify();
  }

  Future<void> _tryStartMonitoring() async {
    debugPrint('🧪 HomeViewModel: _tryStartMonitoring called');
    debugPrint('   protection=$_isProtectionEnabled');
    debugPrint('   trip=$_tripActive');
    debugPrint('   medicalComplete=$_isMedicalProfileComplete');
    debugPrint('   monitorRunning=${_accidentMonitor.isMonitoring}');
    debugPrint('   sensitivity=$_selectedSensitivity');

    if (!_isMedicalProfileComplete) {
      debugPrint('⚠️ HomeViewModel: Monitoring blocked — medical profile incomplete');
      _setMedicalRequiredStatus();
      return;
    }

    if (!_isProtectionEnabled || !_tripActive) {
      debugPrint('⚠️ HomeViewModel: Monitoring blocked — protection/trip not active');
      _updateStatusForProtectionState();
      return;
    }

    if (_accidentMonitor.isMonitoring) {
      debugPrint('ℹ️ HomeViewModel: Monitoring already running');
      _updateStatusForProtectionState();
      return;
    }

    await _accidentMonitor.startMonitoring(
      onAccidentDetected: _handleDetectionEvent,
      onCountdownFinished: _handleCountdownFinished,
      onCountdownCancelled: _handleCountdownCancelled,
    );

    debugPrint('✅ HomeViewModel: Monitoring start requested successfully');

    _updateStatusForProtectionState();
  }

  // ==========================================
  // 🚨 Detection Event Handling
  // ==========================================

  void _handleDetectionEvent(DetectionEvent event) {
    if (_isDisposed) return;

    try {
      if (_isHandlingAccident) return;

      _isHandlingAccident = true;
      _accidentDetected = true;
      _lastDetectionEvent = event;

      _lastDetectedImpact = event.triggerFrame.gForce;
      _lastDetectedRotation = event.triggerFrame.rotation;
      _lastAccidentTime = DateTime.now();

      _statusTitle = 'home.status_accident_detected_title'.tr();
      _statusSubtitle = _buildEventStatusMessage(event);
      _isSystemHealthy = false;

      _safeNotify();
    } catch (e, stackTrace) {
      debugPrint('❌ HomeViewModel _handleDetectionEvent error: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _handleCountdownFinished() {
    if (_isDisposed) return;

    _statusTitle = 'home.status_countdown_finished_title'.tr();
    _statusSubtitle = 'home.status_countdown_finished_subtitle'.tr();
    _isSystemHealthy = false;

    _safeNotify();
  }

  void _handleCountdownCancelled() {
    if (_isDisposed) return;

    _accidentDetected = false;
    _isHandlingAccident = false;

    _statusTitle = 'home.status_cancelled_title'.tr();
    _statusSubtitle = 'home.status_cancelled_subtitle'.tr();
    _isSystemHealthy = true;

    _safeNotify();
  }

  String _buildEventStatusMessage(DetectionEvent? event) {
    if (event == null) {
      return 'home.status_accident_detected_title'.tr();
    }

    final severity = AppThresholds.normalizeSeverityLevel(event.severityLevel);

    switch (severity) {
      case AppThresholds.severityCritical:
        return 'home.status_accident_critical'.tr();
      case AppThresholds.severityHigh:
        return 'home.status_accident_high'.tr();
      case AppThresholds.severityMedium:
        return 'home.status_accident_medium'.tr();
      case AppThresholds.severityLow:
        return 'home.status_accident_low'.tr();
      case AppThresholds.severityIgnored:
      default:
        return event.summary;
    }
  }

  // ==========================================
  // 🔄 Foreground / Background Handoff
  // ==========================================

  Future<void> suspendForegroundMonitoring() async {
    if (_isDisposed) return;

    try {
      if (_accidentMonitor.isMonitoring) {
        await _accidentMonitor.stopMonitoring();
      }

      _updateStatusForProtectionState();
      _safeNotify();
    } catch (e, stackTrace) {
      debugPrint('❌ HomeViewModel suspendForegroundMonitoring error: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> resumeForegroundMonitoringIfNeeded() async {
    if (_isDisposed) return;

    try {
      if (!_isProtectionEnabled || !_tripActive) return;
      if (!_isMedicalProfileComplete) return;
      if (_accidentDetected || _isHandlingAccident) return;
      if (_accidentMonitor.isMonitoring) return;

      await _tryStartMonitoring();
      _safeNotify();
    } catch (e, stackTrace) {
      debugPrint(
        '❌ HomeViewModel resumeForegroundMonitoringIfNeeded error: $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // 🧹 Accident State
  // ==========================================

  void acknowledgeAccidentHandled() {
    if (_isDisposed) return;

    _accidentDetected = false;
    _isHandlingAccident = false;

    _updateStatusForProtectionState();
    _safeNotify();
  }

  void resetAccidentState() {
    if (_isDisposed) return;

    _clearAccidentStateOnly();
    _accidentMonitor.clearLastDetectionEvent();

    _updateStatusForProtectionState();
    _safeNotify();
  }

  void _clearAccidentStateOnly() {
    _accidentDetected = false;
    _isHandlingAccident = false;
    _lastDetectedImpact = 0.0;
    _lastDetectedRotation = 0.0;
    _lastAccidentTime = null;
    _lastDetectionEvent = null;
  }

  // ==========================================
  // 🔔 Notifications Badge
  // ==========================================

  void _listenToUnreadNotificationCount() {
    final user = _authService.currentUser;

    _unreadNotificationSubscription?.cancel();
    _unreadNotificationSubscription = null;

    if (user == null) {
      _unreadNotificationCount = 0;
      return;
    }

    _unreadNotificationSubscription = _notificationService
        .streamUnreadCount(user.uid)
        .listen(
          (count) {
            if (_isDisposed) return;

            final safeCount = count < 0 ? 0 : count;

            if (_unreadNotificationCount == safeCount) {
              return;
            }

            _unreadNotificationCount = safeCount;
            _safeNotify();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_isDisposed) return;

            debugPrint(
              '❌ HomeViewModel: unread notification stream error - $error',
            );
            debugPrintStack(stackTrace: stackTrace);

            _unreadNotificationCount = 0;
            _safeNotify();
          },
        );
  }

  // ==========================================
  // 🗑️ Dispose
  // ==========================================

  @override
  void dispose() {
    _isDisposed = true;

    try {
      _authStateSubscription?.cancel();
      _authStateSubscription = null;

      _unreadNotificationSubscription?.cancel();
      _unreadNotificationSubscription = null;

      _statusRefreshTimer?.cancel();
      _statusRefreshTimer = null;

      pageController.dispose();

      _accidentMonitor.detachUiCallbacks();

      if (_ownsAccidentMonitor) {
        _accidentMonitor.dispose();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ HomeViewModel dispose error: $e');
      debugPrintStack(stackTrace: stackTrace);
    }

    super.dispose();
  }
}
