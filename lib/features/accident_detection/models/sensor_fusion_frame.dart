import '../../../core/constants/app_thresholds.dart';

/// ==========================================
/// 🔬 Sensor Fusion Frame Model - Guardian 360
/// ==========================================
/// Unified immutable data structure combining:
/// - Linear acceleration from userAccelerometer.
/// - Gyroscope rotation.
/// - GPS speed/location context.
/// - Derived speed delta.
///
/// This model is part of the advanced accident detection architecture:
/// SensorFusionService
///   → EventWindowAnalyzer
///   → PostImpactMonitor
///   → AccidentDetectionEngine
class SensorFusionFrame {
  static const Object _unset = Object();

  static const double maxAcceptedLinearG = 50.0;
  static const double maxAcceptedRotation = 30.0;
  static const double usableGpsAccuracyMeters = 50.0;

  /// Timestamp when this frame was created.
  final DateTime timestamp;

  // ==========================================
  // 📊 Accelerometer / Linear Acceleration
  // ==========================================

  /// Linear acceleration magnitude in G units.
  ///
  /// Important:
  /// SensorFusionService uses userAccelerometerEventStream(),
  /// which excludes gravity, then converts m/s² to G.
  final double gForce;

  /// Raw linear acceleration values.
  final double accelX;
  final double accelY;
  final double accelZ;

  // ==========================================
  // 🔄 Gyroscope Data
  // ==========================================

  /// Rotation magnitude in rad/s.
  final double rotation;

  /// Raw gyroscope values in rad/s.
  final double gyroX;
  final double gyroY;
  final double gyroZ;

  // ==========================================
  // 🌍 GPS / Location Data
  // ==========================================

  /// Current speed in km/h.
  final double speedKmh;

  /// GPS coordinates.
  final double? latitude;
  final double? longitude;

  /// GPS accuracy in meters.
  final double? accuracy;

  /// GPS altitude in meters.
  final double? altitude;

  // ==========================================
  // 📈 Derived Metrics
  // ==========================================

  /// Signed speed delta from the previous frame in km/h.
  ///
  /// Positive => deceleration / speed drop.
  /// Negative => acceleration / speed gain.
  final double speedDelta;

  /// Time delta from previous frame in milliseconds.
  final int timeDeltaMs;

  /// Whether this frame passed validation inside the fusion pipeline.
  final bool isValid;

  const SensorFusionFrame({
    required this.timestamp,
    required this.gForce,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.rotation,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.speedKmh,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.altitude,
    this.speedDelta = 0.0,
    this.timeDeltaMs = 0,
    this.isValid = true,
  });

  /// Create an invalid / empty frame.
  factory SensorFusionFrame.invalid() {
    return SensorFusionFrame(
      timestamp: DateTime.now(),
      gForce: 0.0,
      accelX: 0.0,
      accelY: 0.0,
      accelZ: 0.0,
      rotation: 0.0,
      gyroX: 0.0,
      gyroY: 0.0,
      gyroZ: 0.0,
      speedKmh: 0.0,
      speedDelta: 0.0,
      timeDeltaMs: 0,
      isValid: false,
    );
  }

  /// Copy with updated fields.
  ///
  /// Nullable GPS fields support explicit clearing:
  /// frame.copyWith(latitude: null, longitude: null)
  SensorFusionFrame copyWith({
    DateTime? timestamp,
    double? gForce,
    double? accelX,
    double? accelY,
    double? accelZ,
    double? rotation,
    double? gyroX,
    double? gyroY,
    double? gyroZ,
    double? speedKmh,
    Object? latitude = _unset,
    Object? longitude = _unset,
    Object? accuracy = _unset,
    Object? altitude = _unset,
    double? speedDelta,
    int? timeDeltaMs,
    bool? isValid,
  }) {
    return SensorFusionFrame(
      timestamp: timestamp ?? this.timestamp,
      gForce: gForce ?? this.gForce,
      accelX: accelX ?? this.accelX,
      accelY: accelY ?? this.accelY,
      accelZ: accelZ ?? this.accelZ,
      rotation: rotation ?? this.rotation,
      gyroX: gyroX ?? this.gyroX,
      gyroY: gyroY ?? this.gyroY,
      gyroZ: gyroZ ?? this.gyroZ,
      speedKmh: speedKmh ?? this.speedKmh,
      latitude: identical(latitude, _unset)
          ? this.latitude
          : latitude as double?,
      longitude: identical(longitude, _unset)
          ? this.longitude
          : longitude as double?,
      accuracy: identical(accuracy, _unset)
          ? this.accuracy
          : accuracy as double?,
      altitude: identical(altitude, _unset)
          ? this.altitude
          : altitude as double?,
      speedDelta: speedDelta ?? this.speedDelta,
      timeDeltaMs: timeDeltaMs ?? this.timeDeltaMs,
      isValid: isValid ?? this.isValid,
    );
  }

  // ==========================================
  // ✅ Validation Helpers
  // ==========================================

  /// Whether core sensor values are numerically valid.
  bool get hasValidSensorData {
    return _isFiniteInRange(gForce, min: 0.0, max: maxAcceptedLinearG) &&
        _isFiniteInRange(rotation, min: 0.0, max: maxAcceptedRotation) &&
        _isFiniteInRange(
          speedKmh,
          min: 0.0,
          max: AppThresholds.maxReasonableSpeedKmh,
        ) &&
        _isFiniteInRange(
          speedDelta,
          min: -AppThresholds.maxReasonableSpeedKmh,
          max: AppThresholds.maxReasonableSpeedKmh,
        );
  }

  /// Whether raw acceleration components are finite.
  bool get hasValidAccelerationAxes {
    return _isFinite(accelX) && _isFinite(accelY) && _isFinite(accelZ);
  }

  /// Whether raw gyroscope components are finite.
  bool get hasValidGyroscopeAxes {
    return _isFinite(gyroX) && _isFinite(gyroY) && _isFinite(gyroZ);
  }

  /// Whether GPS coordinates are present and physically valid.
  ///
  /// This intentionally rejects:
  /// - null coordinates
  /// - NaN / infinite values
  /// - out-of-range coordinates
  /// - 0,0 placeholder coordinates
  bool get hasGPSData {
    return hasValidCoordinates;
  }

  /// Whether GPS coordinates are valid.
  bool get hasValidCoordinates {
    return _hasValidCoordinatePair(latitude, longitude);
  }

  /// Whether GPS accuracy is numerically valid.
  bool get hasValidAccuracy {
    if (accuracy == null) return true;
    return _isFiniteInRange(accuracy!, min: 0.0, max: 10000.0);
  }

  /// Whether GPS accuracy is considered useful for emergency context.
  bool get hasUsableGPSAccuracy {
    return hasValidCoordinates &&
        accuracy != null &&
        _isFiniteInRange(accuracy!, min: 0.0, max: usableGpsAccuracyMeters);
  }

  /// Whether altitude is valid if present.
  bool get hasValidAltitude {
    return altitude == null || _isFinite(altitude!);
  }

  /// Whether this frame looks structurally solid enough for advanced analysis.
  bool get isStructurallyValid {
    return isValid &&
        hasValidSensorData &&
        hasValidAccelerationAxes &&
        hasValidGyroscopeAxes &&
        hasValidAccuracy &&
        hasValidAltitude &&
        timeDeltaMs >= 0 &&
        (latitude == null && longitude == null || hasValidCoordinates);
  }

  // ==========================================
  // 📊 Derived Convenience Metrics
  // ==========================================

  /// Positive speed drop between frames in km/h.
  double get speedDropKmh {
    return speedDelta > 0 ? speedDelta : 0.0;
  }

  /// Positive speed gain between frames in km/h.
  double get speedGainKmh {
    return speedDelta < 0 ? speedDelta.abs() : 0.0;
  }

  /// Whether the frame carries meaningful physical movement.
  ///
  /// Uses small noise floors instead of checking > 0.0,
  /// because tiny sensor noise should not be treated as meaningful motion.
  bool get hasMeaningfulMotion {
    return gForce > AppThresholds.impactNoiseFloor ||
        rotation > AppThresholds.rotationNoiseFloor ||
        speedKmh >= AppThresholds.minActiveSpeedKmh;
  }

  bool get hasImpactSignal {
    return gForce >= AppThresholds.advancedMinAccidentThreshold;
  }

  bool get hasRotationSignal {
    return rotation >= AppThresholds.advancedRotationThresholdHigh;
  }

  bool get hasSpeedDropSignal {
    return AppThresholds.isSignificantSpeedDrop(speedDropKmh);
  }

  bool get isStationaryBySpeed {
    return speedKmh < AppThresholds.minActiveSpeedKmh;
  }

  bool get isLowSpeedContext {
    return speedKmh < AppThresholds.minActiveSpeedKmh;
  }

  // ==========================================
  // 📦 Serialization / Debugging
  // ==========================================

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'gForce': gForce,
      'accelX': accelX,
      'accelY': accelY,
      'accelZ': accelZ,
      'rotation': rotation,
      'gyroX': gyroX,
      'gyroY': gyroY,
      'gyroZ': gyroZ,
      'speedKmh': speedKmh,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speedDelta': speedDelta,
      'speedDropKmh': speedDropKmh,
      'speedGainKmh': speedGainKmh,
      'timeDeltaMs': timeDeltaMs,
      'isValid': isValid,
      'hasGPSData': hasGPSData,
      'hasUsableGPSAccuracy': hasUsableGPSAccuracy,
      'hasMeaningfulMotion': hasMeaningfulMotion,
      'isStructurallyValid': isStructurallyValid,
    };
  }

  Map<String, dynamic> toDebugMap() => toMap();

  // ==========================================
  // Private Helpers
  // ==========================================

  static bool _isFinite(double value) {
    return !value.isNaN && !value.isInfinite;
  }

  static bool _isFiniteInRange(
    double value, {
    required double min,
    required double max,
  }) {
    return _isFinite(value) && value >= min && value <= max;
  }

  static bool _hasValidCoordinatePair(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;

    return _isFiniteInRange(latitude, min: -90.0, max: 90.0) &&
        _isFiniteInRange(longitude, min: -180.0, max: 180.0) &&
        !(latitude == 0.0 && longitude == 0.0);
  }

  @override
  String toString() {
    return 'SensorFusionFrame('
        'timestamp: $timestamp, '
        'gForce: ${gForce.toStringAsFixed(2)}, '
        'rotation: ${rotation.toStringAsFixed(2)}, '
        'speed: ${speedKmh.toStringAsFixed(1)} km/h, '
        'speedDelta: ${speedDelta.toStringAsFixed(1)} km/h, '
        'gps: ${hasGPSData ? "yes" : "no"}, '
        'accuracy: ${accuracy?.toStringAsFixed(1) ?? "n/a"}, '
        'valid: $isValid'
        ')';
  }
}
