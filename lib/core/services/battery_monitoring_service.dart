import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

/// ==========================================
/// 🔋 Battery Monitoring Service - Guardian 360
/// ==========================================
/// خدمة مراقبة البطارية وإرسال تنبيه عند انخفاض الشحن.
///
/// مهم:
/// - لا تنشئ accidents.
/// - لا تنشئ alerts.
/// - لا تستخدم قناة الحوادث.
/// - ترسل تنبيه بطارية عادي عبر NotificationService.
/// - NotificationService هو المسؤول عن إظهار إشعار النظام
///   وحفظ نسخة داخل users/{uid}/notifications.
class BatteryMonitoringService {
  // ==========================================
  // 🔧 CENTRALIZED CONFIGURATION
  // ==========================================

  /// How often to check battery level.
  static const Duration checkInterval = Duration(minutes: 5);

  /// Battery level thresholds.
  static const int threshold20 = 20;
  static const int threshold15 = 15;
  static const int threshold10 = 10;
  static const int threshold5 = 5;

  /// Prevent too frequent checks/notifications.
  static const Duration cooldownPeriod = Duration(minutes: 10);

  /// SharedPreferences key for toggle state.
  static const String settingKey = 'setting_battery_alert';

  static const Duration _batteryReadTimeout = Duration(seconds: 4);
  static const Duration _notificationTimeout = Duration(seconds: 8);

  // ==========================================
  // 🏗️ SINGLETON PATTERN
  // ==========================================

  static final BatteryMonitoringService _instance =
      BatteryMonitoringService._internal();

  factory BatteryMonitoringService() => _instance;

  BatteryMonitoringService._internal();

  // ==========================================
  // 📦 DEPENDENCIES
  // ==========================================

  final Battery _battery = Battery();
  final NotificationService _notificationService = NotificationService();

  // ==========================================
  // 🔄 STATE
  // ==========================================

  Timer? _monitoringTimer;

  int? _lastNotifiedThreshold;
  DateTime? _lastNotificationTime;

  bool _isMonitoring = false;
  bool _isInitialized = false;
  bool _isChecking = false;

  bool get isMonitoring => _isMonitoring;
  bool get isInitialized => _isInitialized;

  // ==========================================
  // 🚀 PUBLIC METHODS
  // ==========================================

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('ℹ️ BatteryMonitoringService: Already initialized');
      return;
    }

    try {
      final level = await _battery.batteryLevel.timeout(_batteryReadTimeout);

      _isInitialized = true;

      debugPrint(
        '✅ BatteryMonitoringService: Initialized successfully '
        '(battery=$level%)',
      );
    } on TimeoutException {
      _isInitialized = false;
      debugPrint('⏱️ BatteryMonitoringService: Initialization timeout');
    } catch (e, stackTrace) {
      _isInitialized = false;
      debugPrint('❌ BatteryMonitoringService: Initialization failed - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> startMonitoring() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isInitialized) {
      debugPrint(
        '⚠️ BatteryMonitoringService: Monitoring skipped because initialization failed',
      );
      return;
    }

    if (_isMonitoring) {
      debugPrint('ℹ️ BatteryMonitoringService: Already monitoring');
      unawaited(_checkBatteryLevel());
      return;
    }

    try {
      final enabled = await _isEnabled();

      if (!enabled) {
        debugPrint(
          'ℹ️ BatteryMonitoringService: Monitoring disabled in settings',
        );
        await stopMonitoring();
        return;
      }

      _monitoringTimer?.cancel();

      _monitoringTimer = Timer.periodic(checkInterval, (_) {
        unawaited(_checkBatteryLevel());
      });

      _isMonitoring = true;

      await _checkBatteryLevel();

      debugPrint('✅ BatteryMonitoringService: Monitoring started');
    } catch (e, stackTrace) {
      _isMonitoring = false;
      _monitoringTimer?.cancel();
      _monitoringTimer = null;

      debugPrint('❌ BatteryMonitoringService: Failed to start monitoring - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> stopMonitoring() async {
    try {
      _monitoringTimer?.cancel();
      _monitoringTimer = null;
      _isMonitoring = false;

      debugPrint('✅ BatteryMonitoringService: Monitoring stopped');
    } catch (e, stackTrace) {
      debugPrint('❌ BatteryMonitoringService: Failed to stop monitoring - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Manual check helper, useful from settings/testing without exposing internals.
  Future<void> checkNow() async {
    await _checkBatteryLevel();
  }

  // ==========================================
  // 🔒 PRIVATE METHODS
  // ==========================================

  Future<void> _checkBatteryLevel() async {
    if (_isChecking) {
      debugPrint('ℹ️ BatteryMonitoringService: Battery check already running');
      return;
    }

    _isChecking = true;

    try {
      final enabled = await _isEnabled();

      if (!enabled) {
        debugPrint(
          'ℹ️ BatteryMonitoringService: Disabled in settings, stopping monitoring',
        );
        await stopMonitoring();
        return;
      }

      final level = await _battery.batteryLevel.timeout(_batteryReadTimeout);
      final state = await _battery.batteryState.timeout(_batteryReadTimeout);

      debugPrint(
        '🔋 BatteryMonitoringService: Battery check '
        '(level=$level%, state=$state)',
      );

      final threshold = _currentThresholdForLevel(level);

      if (threshold == null) {
        _resetNotificationTrackingIfRecovered(level);
        return;
      }

      if (_shouldNotify(level: level, state: state, threshold: threshold)) {
        await _showBatteryNotification(level: level, threshold: threshold);
      }
    } on TimeoutException {
      debugPrint('⏱️ BatteryMonitoringService: Battery check timeout');
    } catch (e, stackTrace) {
      debugPrint('❌ BatteryMonitoringService: Battery check failed - $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isChecking = false;
    }
  }

  int? _currentThresholdForLevel(int level) {
    if (level <= threshold5) return threshold5;
    if (level <= threshold10) return threshold10;
    if (level <= threshold15) return threshold15;
    if (level <= threshold20) return threshold20;

    return null;
  }

  bool _shouldNotify({
    required int level,
    required BatteryState state,
    required int threshold,
  }) {
    if (state != BatteryState.discharging) {
      return false;
    }

    if (level > threshold20) {
      _resetNotificationTrackingIfRecovered(level);
      return false;
    }

    // One notification per threshold until battery recovers above 20%.
    if (_lastNotifiedThreshold == threshold) {
      return false;
    }

    final now = DateTime.now();

    final isMoreCritical =
        _lastNotifiedThreshold == null || threshold < _lastNotifiedThreshold!;

    if (!isMoreCritical && _lastNotificationTime != null) {
      final elapsed = now.difference(_lastNotificationTime!);

      if (elapsed < cooldownPeriod) {
        return false;
      }
    }

    return true;
  }

  Future<void> _showBatteryNotification({
    required int level,
    required int threshold,
  }) async {
    try {
      await _notificationService.initialize().timeout(_notificationTimeout);

      await _notificationService.sendBatteryLowNotification().timeout(
        _notificationTimeout,
      );

      _lastNotifiedThreshold = threshold;
      _lastNotificationTime = DateTime.now();

      debugPrint(
        '✅ BatteryMonitoringService: Battery notification requested '
        '(level=$level%, threshold=$threshold%)',
      );
    } on TimeoutException {
      debugPrint('⏱️ BatteryMonitoringService: Battery notification timeout');
    } catch (e, stackTrace) {
      debugPrint(
        '❌ BatteryMonitoringService: Failed to request battery notification - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _resetNotificationTrackingIfRecovered(int level) {
    if (level <= threshold20) return;

    if (_lastNotifiedThreshold != null || _lastNotificationTime != null) {
      debugPrint(
        '🔋 BatteryMonitoringService: Battery recovered above threshold, reset notification tracking',
      );
    }

    _lastNotifiedThreshold = null;
    _lastNotificationTime = null;
  }

  Future<bool> _isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(settingKey) ?? true;
    } catch (e, stackTrace) {
      debugPrint('❌ BatteryMonitoringService: Failed to check settings - $e');
      debugPrintStack(stackTrace: stackTrace);
      return true;
    }
  }
}
