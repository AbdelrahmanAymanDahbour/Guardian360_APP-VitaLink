import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/constants/app_thresholds.dart';
import '../models/detection_config.dart';
import '../models/sensor_fusion_frame.dart';

/// ==========================================
/// 🔬 Sensor Fusion Service - Guardian 360
/// ==========================================
/// Combines user accelerometer, gyroscope, and GPS data into unified
/// SensorFusionFrame objects for the advanced accident detection pipeline.
///
/// Important:
/// - userAccelerometerEventStream() excludes gravity.
/// - gForce here means linear acceleration magnitude in G units.
/// - GPS is supportive/contextual and must not block accel/gyro fusion.
///
/// Pipeline:
/// SensorFusionService
///   → EventWindowAnalyzer
///   → PostImpactMonitor
///   → AccidentDetectionEngine
class SensorFusionService {
  // ==========================================
  // 📡 Sensor Streams
  // ==========================================

  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<Position>? _gpsSubscription;

  // ==========================================
  // 📊 Latest Sensor Data
  // ==========================================

  double _latestAccelX = 0.0;
  double _latestAccelY = 0.0;
  double _latestAccelZ = 0.0;
  double _latestGForce = 0.0;
  DateTime? _latestAccelTimestamp;

  double _latestGyroX = 0.0;
  double _latestGyroY = 0.0;
  double _latestGyroZ = 0.0;
  double _latestRotation = 0.0;
  DateTime? _latestGyroTimestamp;

  double _latestSpeedKmh = 0.0;
  double? _latestLatitude;
  double? _latestLongitude;
  double? _latestAccuracy;
  double? _latestAltitude;

  // ==========================================
  // 🔄 Frame Generation
  // ==========================================

  final StreamController<SensorFusionFrame> _frameController =
      StreamController<SensorFusionFrame>.broadcast();

  Stream<SensorFusionFrame> get fusionStream => _frameController.stream;

  Timer? _fusionTimer;
  DetectionConfig _config = DetectionConfig.medium();

  SensorFusionFrame? _previousFrame;

  bool _isRunning = false;
  bool _isDisposed = false;

  bool get isRunning => _isRunning;
  DetectionConfig get currentConfig => _config;
  SensorFusionFrame? get previousFrame => _previousFrame;

  static const double _gravityMetersPerSecondSquared = 9.80665;
  static const double _maxAcceptedLinearG = 50.0;
  static const double _maxAcceptedRotation = 30.0;

  // ==========================================
  // 🚀 Start Sensor Fusion
  // ==========================================

  Future<void> startFusion({DetectionConfig? config}) async {
    if (_isDisposed) {
      debugPrint('⚠️ SensorFusionService: startFusion ignored after dispose');
      return;
    }

    if (_isRunning) {
      debugPrint('⚠️ SensorFusionService: Already running');
      return;
    }

    _config = _safeConfig(config ?? _config);
    _resetRuntimeState();
    _isRunning = true;

    debugPrint('🔬 SensorFusionService: Starting sensor fusion...');
    debugPrint('   Config: $_config');

    try {
      _accelSubscription = userAccelerometerEventStream().listen(
        _handleAccelerometerEvent,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('❌ SensorFusionService: Accelerometer error - $error');
          debugPrintStack(stackTrace: stackTrace);
        },
        cancelOnError: false,
      );

      _gyroSubscription = gyroscopeEventStream().listen(
        _handleGyroscopeEvent,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('❌ SensorFusionService: Gyroscope error - $error');
          debugPrintStack(stackTrace: stackTrace);
        },
        cancelOnError: false,
      );

      await _startGPSStreamSoftly();
      _startFusionTimer();

      debugPrint('✅ SensorFusionService: Sensor fusion started successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ SensorFusionService: Failed to start - $e');
      debugPrintStack(stackTrace: stackTrace);

      await _cancelSubscriptions();
      _fusionTimer?.cancel();
      _fusionTimer = null;
      _isRunning = false;
      _resetRuntimeState();

      rethrow;
    }
  }

  // ==========================================
  // 🛑 Stop Sensor Fusion
  // ==========================================

  Future<void> stopFusion() async {
    if (!_isRunning &&
        _accelSubscription == null &&
        _gyroSubscription == null &&
        _gpsSubscription == null &&
        _fusionTimer == null) {
      return;
    }

    debugPrint('🛑 SensorFusionService: Stopping sensor fusion...');

    await _cancelSubscriptions();

    _fusionTimer?.cancel();
    _fusionTimer = null;

    _isRunning = false;
    _resetRuntimeState();

    debugPrint('✅ SensorFusionService: Sensor fusion stopped');
  }

  Future<void> _cancelSubscriptions() async {
    try {
      await _accelSubscription?.cancel();
    } catch (e, stackTrace) {
      debugPrint('❌ SensorFusionService: Accelerometer cancel failed - $e');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      await _gyroSubscription?.cancel();
    } catch (e, stackTrace) {
      debugPrint('❌ SensorFusionService: Gyroscope cancel failed - $e');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      await _gpsSubscription?.cancel();
    } catch (e, stackTrace) {
      debugPrint('❌ SensorFusionService: GPS cancel failed - $e');
      debugPrintStack(stackTrace: stackTrace);
    }

    _accelSubscription = null;
    _gyroSubscription = null;
    _gpsSubscription = null;
  }

  // ==========================================
  // 📊 Sensor Event Handlers
  // ==========================================

  void _handleAccelerometerEvent(UserAccelerometerEvent event) {
    if (_isDisposed || !_isRunning) return;

    try {
      _latestAccelX = _safeNumber(event.x);
      _latestAccelY = _safeNumber(event.y);
      _latestAccelZ = _safeNumber(event.z);
      _latestAccelTimestamp = DateTime.now();

      // userAccelerometerEventStream() excludes gravity.
      // Convert linear acceleration magnitude from m/s² to G units.
      final vectorMagnitude = sqrt(
        (_latestAccelX * _latestAccelX) +
            (_latestAccelY * _latestAccelY) +
            (_latestAccelZ * _latestAccelZ),
      );

      final gForce = vectorMagnitude / _gravityMetersPerSecondSquared;

      _latestGForce = _sanitizeRange(
        gForce,
        min: 0.0,
        max: _maxAcceptedLinearG,
      );
    } catch (e, stackTrace) {
      debugPrint('⚠️ SensorFusionService: Accelerometer processing error - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _handleGyroscopeEvent(GyroscopeEvent event) {
    if (_isDisposed || !_isRunning) return;

    try {
      _latestGyroX = _safeNumber(event.x);
      _latestGyroY = _safeNumber(event.y);
      _latestGyroZ = _safeNumber(event.z);
      _latestGyroTimestamp = DateTime.now();

      final rotation = sqrt(
        (_latestGyroX * _latestGyroX) +
            (_latestGyroY * _latestGyroY) +
            (_latestGyroZ * _latestGyroZ),
      );

      _latestRotation = _sanitizeRange(
        rotation,
        min: 0.0,
        max: _maxAcceptedRotation,
      );
    } catch (e, stackTrace) {
      debugPrint('⚠️ SensorFusionService: Gyroscope processing error - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _handleGPSEvent(Position position) {
    if (_isDisposed || !_isRunning) return;

    try {
      final latitude = position.latitude;
      final longitude = position.longitude;

      if (_hasValidCoordinates(latitude, longitude)) {
        _latestLatitude = latitude;
        _latestLongitude = longitude;
      } else {
        debugPrint(
          '⚠️ SensorFusionService: Invalid GPS coordinates ignored '
          '($latitude, $longitude)',
        );
      }

      final speedKmh = _safeNumber(position.speed) * 3.6;

      _latestSpeedKmh = _sanitizeRange(
        speedKmh,
        min: 0.0,
        max: AppThresholds.maxReasonableSpeedKmh,
      );

      final accuracy = _safeNullableNumber(position.accuracy);
      _latestAccuracy = accuracy != null && accuracy >= 0 ? accuracy : null;

      final altitude = _safeNullableNumber(position.altitude);
      _latestAltitude = altitude;
    } catch (e, stackTrace) {
      debugPrint('⚠️ SensorFusionService: GPS processing error - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // 🔄 GPS Stream Management
  // ==========================================

  Future<void> _startGPSStreamSoftly() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        debugPrint(
          '⚠️ SensorFusionService: GPS service disabled; continuing without GPS',
        );
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint(
          '⚠️ SensorFusionService: Location permission denied; continuing without GPS',
        );
        return;
      }

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );

      _gpsSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            _handleGPSEvent,
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('❌ SensorFusionService: GPS stream error - $error');
              debugPrintStack(stackTrace: stackTrace);
            },
            cancelOnError: false,
          );

      debugPrint('✅ SensorFusionService: GPS stream started');
    } catch (e, stackTrace) {
      debugPrint(
        '⚠️ SensorFusionService: Failed to start GPS stream; continuing without GPS - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // ⏱️ Fusion Timer
  // ==========================================

  void _startFusionTimer() {
    _fusionTimer?.cancel();

    final sampleRateHz = AppThresholds.targetSampleRateHz <= 0
        ? 50
        : AppThresholds.targetSampleRateHz;

    final intervalMs = max(10, (1000 / sampleRateHz).round());

    _fusionTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (_) => _generateFusionFrame(),
    );

    debugPrint(
      '⏱️ SensorFusionService: Fusion timer started (${intervalMs}ms interval)',
    );
  }

  void _generateFusionFrame() {
    if (_isDisposed || !_isRunning || _frameController.isClosed) return;

    try {
      final now = DateTime.now();

      if (!_hasFreshSensorData(now)) {
        return;
      }

      final speedDelta = _calculateSpeedDelta();
      final timeDeltaMs = _previousFrame != null
          ? now.difference(_previousFrame!.timestamp).inMilliseconds
          : 0;

      final isValid = _validateFrame();

      final frame = SensorFusionFrame(
        timestamp: now,
        gForce: _latestGForce,
        accelX: _latestAccelX,
        accelY: _latestAccelY,
        accelZ: _latestAccelZ,
        rotation: _latestRotation,
        gyroX: _latestGyroX,
        gyroY: _latestGyroY,
        gyroZ: _latestGyroZ,
        speedKmh: _latestSpeedKmh,
        latitude: _latestLatitude,
        longitude: _latestLongitude,
        accuracy: _latestAccuracy,
        altitude: _latestAltitude,
        speedDelta: speedDelta,
        timeDeltaMs: timeDeltaMs,
        isValid: isValid,
      );

      _frameController.add(frame);
      _previousFrame = frame;
    } catch (e, stackTrace) {
      debugPrint('⚠️ SensorFusionService: Frame generation error - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  double _calculateSpeedDelta() {
    final previous = _previousFrame;

    if (previous == null) return 0.0;

    final rawDelta = previous.speedKmh - _latestSpeedKmh;

    // GPS low-speed drift filter:
    // Small speed changes at near-zero speed are usually GPS noise.
    if (previous.speedKmh < 10.0 &&
        _latestSpeedKmh < 10.0 &&
        rawDelta.abs() < 5.0) {
      return 0.0;
    }

    if (rawDelta.isNaN || rawDelta.isInfinite) {
      return 0.0;
    }

    return rawDelta.clamp(
      -AppThresholds.maxReasonableSpeedKmh,
      AppThresholds.maxReasonableSpeedKmh,
    );
  }

  // ==========================================
  // ✅ Validation
  // ==========================================

  bool _hasFreshSensorData(DateTime now) {
    final maxDelta = Duration(milliseconds: _config.maxSensorTimeDeltaMs);

    final accelTimestamp = _latestAccelTimestamp;
    if (accelTimestamp == null || now.difference(accelTimestamp) > maxDelta) {
      return false;
    }

    final gyroTimestamp = _latestGyroTimestamp;
    if (gyroTimestamp == null || now.difference(gyroTimestamp) > maxDelta) {
      return false;
    }

    // GPS may be slower than accel/gyro and should not block frame generation.
    return true;
  }

  bool _validateFrame() {
    if (!_isFiniteInRange(_latestGForce, min: 0.0, max: _maxAcceptedLinearG)) {
      return false;
    }

    if (!_isFiniteInRange(
      _latestRotation,
      min: 0.0,
      max: _maxAcceptedRotation,
    )) {
      return false;
    }

    if (!_isFiniteInRange(
      _latestSpeedKmh,
      min: 0.0,
      max: AppThresholds.maxReasonableSpeedKmh,
    )) {
      return false;
    }

    if (_latestLatitude != null || _latestLongitude != null) {
      if (!_hasValidCoordinates(_latestLatitude, _latestLongitude)) {
        return false;
      }
    }

    final accuracy = _latestAccuracy;
    if (accuracy != null &&
        (accuracy.isNaN || accuracy.isInfinite || accuracy < 0)) {
      return false;
    }

    return true;
  }

  bool _isFiniteInRange(
    double value, {
    required double min,
    required double max,
  }) {
    return !value.isNaN && !value.isInfinite && value >= min && value <= max;
  }

  bool _hasValidCoordinates(double? latitude, double? longitude) {
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

  double _safeNumber(double value, {double fallback = 0.0}) {
    if (value.isNaN || value.isInfinite) {
      return fallback;
    }

    return value;
  }

  double? _safeNullableNumber(double? value) {
    if (value == null || value.isNaN || value.isInfinite) {
      return null;
    }

    return value;
  }

  double _sanitizeRange(
    double value, {
    required double min,
    required double max,
  }) {
    final safe = _safeNumber(value, fallback: min);
    return safe.clamp(min, max);
  }

  // ==========================================
  // ⚙️ Configuration
  // ==========================================

  void updateConfig(DetectionConfig config) {
    if (!config.isStructurallyValid) {
      debugPrint(
        '⚠️ SensorFusionService: Ignored invalid config update: $config',
      );
      return;
    }

    _config = config;

    debugPrint('🔧 SensorFusionService: Configuration updated');
    debugPrint('   Config: $_config');
  }

  DetectionConfig _safeConfig(DetectionConfig config) {
    if (config.isStructurallyValid) {
      return config;
    }

    debugPrint(
      '⚠️ SensorFusionService: Invalid config received, using medium config',
    );

    return DetectionConfig.medium();
  }

  // ==========================================
  // 📊 Debug Helpers
  // ==========================================

  Map<String, dynamic> getDebugSnapshot() {
    return {
      'isRunning': _isRunning,
      'isDisposed': _isDisposed,
      'latestGForce': _latestGForce,
      'latestRotation': _latestRotation,
      'latestSpeedKmh': _latestSpeedKmh,
      'latestLatitude': _latestLatitude,
      'latestLongitude': _latestLongitude,
      'latestAccuracy': _latestAccuracy,
      'hasAccelTimestamp': _latestAccelTimestamp != null,
      'hasGyroTimestamp': _latestGyroTimestamp != null,
      'hasPreviousFrame': _previousFrame != null,
      'config': _config.toString(),
    };
  }

  void _resetRuntimeState() {
    _latestAccelX = 0.0;
    _latestAccelY = 0.0;
    _latestAccelZ = 0.0;
    _latestGForce = 0.0;
    _latestAccelTimestamp = null;

    _latestGyroX = 0.0;
    _latestGyroY = 0.0;
    _latestGyroZ = 0.0;
    _latestRotation = 0.0;
    _latestGyroTimestamp = null;

    _latestSpeedKmh = 0.0;
    _latestLatitude = null;
    _latestLongitude = null;
    _latestAccuracy = null;
    _latestAltitude = null;

    _previousFrame = null;
  }

  // ==========================================
  // 🧹 Cleanup
  // ==========================================

  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    await stopFusion();

    if (!_frameController.isClosed) {
      await _frameController.close();
    }

    debugPrint('🧹 SensorFusionService: Disposed');
  }
}
