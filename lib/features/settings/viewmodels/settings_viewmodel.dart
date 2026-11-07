import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/battery_monitoring_service.dart';
import '../../../core/services/sensor_service.dart';
import '../../auth/services/firebase_auth_service.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({
    FirebaseAuthService? authService,
    SensorService? sensorService,
    BatteryMonitoringService? batteryMonitoringService,
  }) : _authService = authService ?? FirebaseAuthService(),
       _sensorService = sensorService ?? SensorService(),
       _batteryMonitoringService =
           batteryMonitoringService ?? BatteryMonitoringService() {
    unawaited(_initializeSettings());
  }

  final FirebaseAuthService _authService;
  final SensorService _sensorService;
  final BatteryMonitoringService _batteryMonitoringService;

  SharedPreferences? _prefs;

  bool _isDisposed = false;
  bool _isSyncingBatteryMonitoring = false;

  // ==========================================
  // 👤 User info
  // ==========================================

  String userName = '';
  String userEmail = '';

  // ==========================================
  // ⚙️ Toggles
  // ==========================================

  bool isLiveLocationOn = false;
  bool isBatteryAlertOn = true;
  bool isSoundEnabled = true;
  bool isBiometricOn = false;
  bool isShakeToSosOn = true;

  // ==========================================
  // 💥 Detection sensitivity (0 → 100)
  // ==========================================

  double sensitivity = 70.0;

  // ==========================================
  // 📡 Device state
  // ==========================================

  bool isDeviceConnected = false;
  String deviceName = '';
  String deviceStatus = '';

  bool isLoading = true;

  // ==========================================
  // 🗝️ SharedPreferences keys
  // ==========================================

  static const String _keyLiveLocation = 'setting_live_location';
  static const String _keyBatteryAlert = 'setting_battery_alert';
  static const String _keySound = 'setting_sound';
  static const String _keyBiometric = 'setting_biometric';
  static const String _keyShakeSos = 'setting_shake_sos';
  static const String _keySensitivity = 'setting_sensitivity';
  static const String _keyConnectedDeviceName = 'connected_device_name';
  static const String _keyDeviceConnected = 'device_connected';

  // ==========================================
  // 🚀 Init
  // ==========================================

  Future<void> _initializeSettings() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      if (_isDisposed) return;

      _loadUserData();
      _loadSavedPreferences();
      _loadDeviceState();
      _applySensitivityToSensors(sensitivity);

      // مهم جدًا:
      // إذا كان Battery Alert محفوظ ON، نبدأ المراقبة تلقائيًا.
      // سابقًا كان السويتش يظهر ON لكن الخدمة لا تبدأ إلا بعد ضغط المستخدم.
      unawaited(_syncBatteryMonitoringWithPreference());

      isLoading = false;
      _safeNotify();
    } catch (e, stackTrace) {
      debugPrint('❌ SettingsViewModel: initialization failed - $e');
      debugPrintStack(stackTrace: stackTrace);

      isLoading = false;
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _loadUserData() {
    final currentUser = _authService.currentUser;

    if (currentUser != null) {
      final displayName = currentUser.displayName?.trim() ?? '';
      final email = currentUser.email?.trim() ?? '';

      userName = displayName.isNotEmpty ? displayName : 'Guardian User';
      userEmail = email.isNotEmpty ? email : 'user@guardian360.com';
      return;
    }

    userName = 'Guardian User';
    userEmail = 'guest@guardian360.com';
  }

  void _loadSavedPreferences() {
    final prefs = _prefs;

    if (prefs == null) return;

    isLiveLocationOn = prefs.getBool(_keyLiveLocation) ?? false;
    isBatteryAlertOn = prefs.getBool(_keyBatteryAlert) ?? true;
    isSoundEnabled = prefs.getBool(_keySound) ?? true;
    isBiometricOn = prefs.getBool(_keyBiometric) ?? false;
    isShakeToSosOn = prefs.getBool(_keyShakeSos) ?? true;

    final storedSensitivity = prefs.getDouble(_keySensitivity) ?? 70.0;
    sensitivity = _sanitizeSensitivity(storedSensitivity);
  }

  void _loadDeviceState() {
    final prefs = _prefs;

    if (prefs == null) {
      _setDeviceDisconnected();
      return;
    }

    final savedDeviceName = prefs.getString(_keyConnectedDeviceName)?.trim();
    final savedDeviceConnected = prefs.getBool(_keyDeviceConnected) ?? false;

    if (savedDeviceConnected &&
        savedDeviceName != null &&
        savedDeviceName.isNotEmpty) {
      isDeviceConnected = true;
      deviceName = savedDeviceName;
      deviceStatus = 'Connected';
      return;
    }

    _setDeviceDisconnected();
  }

  void _setDeviceDisconnected() {
    isDeviceConnected = false;
    deviceName = '';
    deviceStatus = 'Disconnected';
  }

  // ==========================================
  // 📡 Device UI helpers
  // ==========================================

  String get deviceStatusText {
    if (isDeviceConnected && deviceName.isNotEmpty) {
      return '$deviceName • $deviceStatus';
    }

    return deviceStatus.isNotEmpty ? deviceStatus : 'Disconnected';
  }

  // ==========================================
  // 🔁 Toggle handlers
  // ==========================================

  Future<void> toggleLiveLocation(bool value) async {
    if (_isDisposed) return;

    isLiveLocationOn = value;
    _safeNotify();

    await _saveBool(_keyLiveLocation, value);

    debugPrint(
      '📍 SettingsViewModel: Live location ${value ? "enabled" : "disabled"}',
    );
  }

  Future<void> toggleShakeToSos(bool value) async {
    if (_isDisposed) return;

    isShakeToSosOn = value;
    _safeNotify();

    await _saveBool(_keyShakeSos, value);

    debugPrint(
      '🚨 SettingsViewModel: Shake to SOS ${value ? "enabled" : "disabled"}',
    );
  }

  Future<void> toggleBatteryAlert(bool value) async {
    if (_isDisposed) return;

    isBatteryAlertOn = value;
    _safeNotify();

    await _saveBool(_keyBatteryAlert, value);
    await _syncBatteryMonitoringWithPreference();
  }

  Future<void> toggleSound(bool value) async {
    if (_isDisposed) return;

    isSoundEnabled = value;
    _safeNotify();

    await _saveBool(_keySound, value);

    debugPrint(
      '🔊 SettingsViewModel: Voice feedback ${value ? "enabled" : "disabled"}',
    );
  }

  Future<void> toggleBiometric(bool value) async {
    if (_isDisposed) return;

    isBiometricOn = value;
    _safeNotify();

    await _saveBool(_keyBiometric, value);

    debugPrint(
      '🛡️ SettingsViewModel: Biometric auth ${value ? "enabled" : "disabled"}',
    );
  }

  // ==========================================
  // 🔋 Battery monitoring sync
  // ==========================================

  Future<void> _syncBatteryMonitoringWithPreference() async {
    if (_isDisposed) return;

    if (_isSyncingBatteryMonitoring) {
      debugPrint(
        'ℹ️ SettingsViewModel: Battery monitoring sync already running',
      );
      return;
    }

    _isSyncingBatteryMonitoring = true;

    try {
      if (isBatteryAlertOn) {
        await _batteryMonitoringService.startMonitoring();

        debugPrint('🔋 SettingsViewModel: Battery monitoring synced ON');
        return;
      }

      await _batteryMonitoringService.stopMonitoring();

      debugPrint('🔋 SettingsViewModel: Battery monitoring synced OFF');
    } catch (e, stackTrace) {
      debugPrint(
        '❌ SettingsViewModel: Failed to sync battery monitoring preference - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isSyncingBatteryMonitoring = false;
    }
  }

  // ==========================================
  // 💥 Sensitivity logic
  // ==========================================

  Future<void> changeSensitivity(double value) async {
    if (_isDisposed) return;

    final safeValue = _sanitizeSensitivity(value);

    sensitivity = safeValue;
    _safeNotify();

    await _saveDouble(_keySensitivity, safeValue);
    _applySensitivityToSensors(safeValue);

    debugPrint(
      '⚙️ SettingsViewModel: Sensitivity changed to ${safeValue.toStringAsFixed(0)}%',
    );
  }

  double _sanitizeSensitivity(double value) {
    if (value.isNaN || value.isInfinite) {
      return 70.0;
    }

    return value.clamp(0.0, 100.0).toDouble();
  }

  void _applySensitivityToSensors(double uiValue) {
    final safeValue = _sanitizeSensitivity(uiValue);

    // 0 - 34  => Low sensitivity
    // 35 - 74 => Medium sensitivity
    // 75 -100 => High sensitivity
    if (safeValue < 35) {
      _sensorService.setSensitivity('low');
      return;
    }

    if (safeValue < 75) {
      _sensorService.setSensitivity('medium');
      return;
    }

    _sensorService.setSensitivity('high');
  }

  // ==========================================
  // 🎨 UI helpers
  // ==========================================

  String get sensitivityLabel {
    final value = _sanitizeSensitivity(sensitivity);

    if (value < 35) {
      return 'Low sensitivity • Fewer false alarms';
    }

    if (value < 75) {
      return 'Balanced sensitivity • Recommended';
    }

    return 'High sensitivity • Detects smaller impacts';
  }

  String get sensitivityLabelKey {
    final value = _sanitizeSensitivity(sensitivity);

    if (value < 35) {
      return 'settings.detection.sensitivity_low';
    }

    if (value < 75) {
      return 'settings.detection.sensitivity_medium';
    }

    return 'settings.detection.sensitivity_high';
  }

  Color get sensitivityColor {
    final value = _sanitizeSensitivity(sensitivity);

    if (value < 35) return Colors.green;
    if (value < 75) return Colors.orange;
    return AppColors.primaryRed;
  }

  String get deviceStatusKey {
    return isDeviceConnected
        ? 'settings.devices.connected'
        : 'settings.devices.disconnected';
  }

  // ==========================================
  // 💾 Persistence helpers
  // ==========================================

  Future<void> _saveBool(String key, bool value) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs ??= prefs;

      await prefs.setBool(key, value);
    } catch (e, stackTrace) {
      debugPrint('❌ SettingsViewModel: failed saving bool "$key" - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _saveDouble(String key, double value) async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs ??= prefs;

      await prefs.setDouble(key, value);
    } catch (e, stackTrace) {
      debugPrint('❌ SettingsViewModel: failed saving double "$key" - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
