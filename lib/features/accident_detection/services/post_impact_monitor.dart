import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_thresholds.dart';
import '../models/detection_config.dart';
import '../models/sensor_fusion_frame.dart';

/// ==========================================
/// 🛑 Post-Impact Monitor - Guardian 360
/// ==========================================
/// Monitors motion after a potential impact to distinguish real accidents
/// from bumps, shakes, phone drops, and false positives.
///
/// Responsibilities:
/// - Analyze post-impact stillness.
/// - Analyze continued movement after impact.
/// - Produce stillness confidence score.
/// - Provide diagnostics for AccidentDetectionEngine.
///
/// Not responsible for:
/// - Triggering accidents.
/// - Classifying final severity.
/// - Writing Firestore.
/// - Starting SOS.
///
/// Pipeline:
/// SensorFusionService
///   → EventWindowAnalyzer
///   → PostImpactMonitor
///   → AccidentDetectionEngine
class PostImpactMonitor {
  DetectionConfig _config;

  PostImpactMonitor({DetectionConfig? config}) : _config = _safeConfig(config);

  static DetectionConfig _safeConfig(DetectionConfig? config) {
    if (config != null && config.isStructurallyValid) {
      return config;
    }

    if (config != null) {
      debugPrint(
        '⚠️ PostImpactMonitor: Invalid config received, using medium config',
      );
    }

    return DetectionConfig.medium();
  }

  // ==========================================
  // 📊 Monitoring State
  // ==========================================

  bool _isMonitoring = false;
  DateTime? _monitoringStartTime;
  DateTime? _lastProcessedFrameTimestamp;

  int _stillnessDurationMs = 0;
  int _movementDurationMs = 0;

  // ==========================================
  // 📈 Statistics
  // ==========================================

  double _averageGForce = 0.0;
  double _averageSpeed = 0.0;
  double _peakGForce = 0.0;

  int _frameCount = 0;
  int _gpsFrameCount = 0;

  double _gForceSum = 0.0;
  double _speedSum = 0.0;

  final List<double> _gForceHistory = <double>[];
  final List<double> _speedHistory = <double>[];

  // ==========================================
  // 🚀 Start Monitoring
  // ==========================================

  void startMonitoring({DateTime? startTime}) {
    if (_isMonitoring) {
      debugPrint('⚠️ PostImpactMonitor: Already monitoring');
      return;
    }

    _resetInternalStats();

    _isMonitoring = true;
    _monitoringStartTime = startTime ?? DateTime.now();

    debugPrint('🛑 PostImpactMonitor: Started');
  }

  // ==========================================
  // 🛑 Stop Monitoring
  // ==========================================

  void stopMonitoring() {
    if (!_isMonitoring) return;

    debugPrint('✅ PostImpactMonitor: Stopped');
    debugPrint('   stillness=${_stillnessDurationMs}ms');
    debugPrint('   movement=${_movementDurationMs}ms');
    debugPrint('   avgGForce=${_averageGForce.toStringAsFixed(2)}');
    debugPrint('   avgSpeed=${_averageSpeed.toStringAsFixed(1)} km/h');
    debugPrint('   confidence=${getStillnessConfidence().toStringAsFixed(1)}%');

    _isMonitoring = false;
    _monitoringStartTime = null;
    _lastProcessedFrameTimestamp = null;
  }

  // ==========================================
  // 📥 Process Frame
  // ==========================================

  void processFrame(SensorFusionFrame frame) {
    if (!_isMonitoring) return;
    if (!frame.isStructurallyValid || !frame.hasValidSensorData) return;

    final elapsedFromStart = _elapsedFromMonitoringStartMs(frame.timestamp);

    // Ignore the immediate impact tail. The first part after trigger can still
    // belong to the collision spike, not true post-impact behavior.
    if (elapsedFromStart < _impactTailIgnoreMs) {
      _lastProcessedFrameTimestamp = frame.timestamp;
      return;
    }

    final deltaMs = _resolveFrameDeltaMs(frame);

    _updateStats(frame);

    if (deltaMs <= 0) {
      _lastProcessedFrameTimestamp = frame.timestamp;
      return;
    }

    final isStill = _isFrameStill(frame);

    if (isStill) {
      _stillnessDurationMs += deltaMs;
    } else {
      _movementDurationMs += deltaMs;
    }

    _lastProcessedFrameTimestamp = frame.timestamp;
  }

  int _resolveFrameDeltaMs(SensorFusionFrame frame) {
    final lastTimestamp = _lastProcessedFrameTimestamp;

    int rawDeltaMs = 0;

    if (lastTimestamp != null && !frame.timestamp.isBefore(lastTimestamp)) {
      rawDeltaMs = frame.timestamp.difference(lastTimestamp).inMilliseconds;
    }

    if (rawDeltaMs <= 0 && frame.timeDeltaMs > 0) {
      rawDeltaMs = frame.timeDeltaMs;
    }

    if (rawDeltaMs <= 0) return 0;

    // Prevent a delayed frame from inflating stillness/movement duration.
    final maxContribution = _maxFrameDurationContributionMs;

    if (rawDeltaMs > maxContribution) {
      return maxContribution;
    }

    return rawDeltaMs;
  }

  void _updateStats(SensorFusionFrame frame) {
    final gForce = _sanitizeNonNegative(frame.gForce);
    final speed = _sanitizeNonNegative(frame.speedKmh);

    _frameCount++;

    _gForceSum += gForce;
    _averageGForce = _gForceSum / _frameCount;

    if (frame.hasGPSData && AppThresholds.isValidSpeed(speed)) {
      _gpsFrameCount++;
      _speedSum += speed;
      _averageSpeed = _speedSum / _gpsFrameCount;
      _speedHistory.add(speed);
    }

    _gForceHistory.add(gForce);

    if (gForce > _peakGForce) {
      _peakGForce = gForce;
    }

    _trimHistory();
  }

  void _trimHistory() {
    final maxSize = max(20, _config.sensorBufferSize);

    while (_gForceHistory.length > maxSize) {
      _gForceHistory.removeAt(0);
    }

    while (_speedHistory.length > maxSize) {
      _speedHistory.removeAt(0);
    }
  }

  // ==========================================
  // 🔍 Motion / Stillness Logic
  // ==========================================

  bool _isFrameStill(SensorFusionFrame frame) {
    final gForce = _sanitizeNonNegative(frame.gForce);
    final speed = _sanitizeNonNegative(frame.speedKmh);

    final isGForceStill = gForce <= _config.stillnessThresholdG;

    // GPS may be unavailable. In that case, do not block stillness detection.
    final isSpeedStill = frame.hasGPSData
        ? speed < _config.minActiveSpeedKmh
        : true;

    return isGForceStill && isSpeedStill;
  }

  /// Whether post-impact stillness reached the required confirmation duration.
  bool hasConfirmedStillness() {
    return _stillnessDurationMs >= _config.stillnessDurationMs;
  }

  /// Whether post-impact movement clearly dominates over stillness.
  bool hasSignificantMovement() {
    return _movementDurationMs >= 800 &&
        _movementDurationMs > (_stillnessDurationMs * 2);
  }

  /// Detect micro-movements that may indicate continued vibration after impact.
  bool hasMicroMovements() {
    if (_gForceHistory.length < 5) return false;

    var microMovementCount = 0;

    for (final gForce in _gForceHistory) {
      if (AppThresholds.isMicroMovement(gForce)) {
        microMovementCount++;
      }
    }

    final ratio = microMovementCount / _gForceHistory.length;
    return ratio > 0.3;
  }

  /// Whether the device/vehicle appears nearly stationary.
  bool isCompletelyStationary() {
    final speedLooksStationary = _gpsFrameCount == 0 || _averageSpeed < 1.0;

    return _averageGForce < AppThresholds.microMovementThresholdG &&
        speedLooksStationary;
  }

  /// Stillness confidence on 0-100 scale.
  double getStillnessConfidence() {
    if (_frameCount == 0) return 0.0;

    final observedDurationMs = effectiveObservedDurationMs;
    if (observedDurationMs <= 0) return 0.0;

    final stillnessRatio = (_stillnessDurationMs / observedDurationMs).clamp(
      0.0,
      1.0,
    );

    final gForceScore =
        1.0 - (_averageGForce / _config.stillnessThresholdG).clamp(0.0, 1.0);

    // If GPS is unavailable, use neutral speed confidence instead of treating
    // missing GPS as perfect zero-speed evidence.
    final speedScore = _gpsFrameCount > 0
        ? 1.0 - (_averageSpeed / _config.minActiveSpeedKmh).clamp(0.0, 1.0)
        : 0.5;

    var confidence =
        (stillnessRatio * 0.55) + (gForceScore * 0.30) + (speedScore * 0.15);

    if (hasMicroMovements()) {
      confidence -= 0.08;
    }

    if (isCompletelyStationary()) {
      confidence += 0.08;
    }

    if (hasSignificantMovement()) {
      confidence -= 0.12;
    }

    return (confidence * 100).clamp(0.0, 100.0);
  }

  // ==========================================
  // 📊 Analysis
  // ==========================================

  Map<String, dynamic> getAnalysis() {
    return {
      'isMonitoring': _isMonitoring,
      'stillnessDurationMs': _stillnessDurationMs,
      'movementDurationMs': _movementDurationMs,
      'effectiveObservedDurationMs': effectiveObservedDurationMs,
      'averageGForce': _averageGForce,
      'averageSpeed': _averageSpeed,
      'peakGForce': _peakGForce,
      'frameCount': _frameCount,
      'gpsFrameCount': _gpsFrameCount,
      'hasConfirmedStillness': hasConfirmedStillness(),
      'hasSignificantMovement': hasSignificantMovement(),
      'hasMicroMovements': hasMicroMovements(),
      'isCompletelyStationary': isCompletelyStationary(),
      'stillnessConfidence': getStillnessConfidence(),
      'monitoringDurationMs': monitoringDurationMs,
      'impactTailIgnoreMs': _impactTailIgnoreMs,
    };
  }

  bool isMonitoringComplete() {
    if (!_isMonitoring || _monitoringStartTime == null) return false;

    final targetObservedDuration = max(
      0,
      _config.postImpactWindowMs - _impactTailIgnoreMs,
    );

    return effectiveObservedDurationMs >= targetObservedDuration ||
        monitoringDurationMs >= _config.postImpactWindowMs;
  }

  int get monitoringDurationMs {
    final start = _monitoringStartTime;
    if (start == null) return 0;

    return DateTime.now().difference(start).inMilliseconds;
  }

  int get effectiveObservedDurationMs {
    return _stillnessDurationMs + _movementDurationMs;
  }

  int get _impactTailIgnoreMs {
    final halfImpactWindow = _config.impactWindowMs ~/ 2;
    return halfImpactWindow.clamp(100, 600);
  }

  int get _maxFrameDurationContributionMs {
    final derived = _config.maxSensorTimeDeltaMs * 5;
    return derived.clamp(100, 500);
  }

  int _elapsedFromMonitoringStartMs(DateTime timestamp) {
    final start = _monitoringStartTime;
    if (start == null) return 0;

    return timestamp.difference(start).inMilliseconds;
  }

  double _sanitizeNonNegative(double value) {
    if (value.isNaN || value.isInfinite || value < 0.0) {
      return 0.0;
    }

    return value;
  }

  // ==========================================
  // ⚙️ Configuration
  // ==========================================

  void updateConfig(DetectionConfig config) {
    if (!config.isStructurallyValid) {
      debugPrint(
        '⚠️ PostImpactMonitor: Ignored invalid config update: $config',
      );
      return;
    }

    _config = config;
    debugPrint('🔧 PostImpactMonitor: Configuration updated');
  }

  // ==========================================
  // 🧹 Reset & Cleanup
  // ==========================================

  void _resetInternalStats() {
    _stillnessDurationMs = 0;
    _movementDurationMs = 0;

    _averageGForce = 0.0;
    _averageSpeed = 0.0;
    _peakGForce = 0.0;

    _frameCount = 0;
    _gpsFrameCount = 0;

    _gForceSum = 0.0;
    _speedSum = 0.0;

    _gForceHistory.clear();
    _speedHistory.clear();

    _lastProcessedFrameTimestamp = null;
  }

  void reset() {
    _isMonitoring = false;
    _monitoringStartTime = null;
    _lastProcessedFrameTimestamp = null;
    _resetInternalStats();

    debugPrint('🔄 PostImpactMonitor: Reset complete');
  }

  // ==========================================
  // 📖 Getters
  // ==========================================

  bool get isMonitoring => _isMonitoring;
  int get stillnessDurationMs => _stillnessDurationMs;
  int get movementDurationMs => _movementDurationMs;
  double get averageGForce => _averageGForce;
  double get averageSpeed => _averageSpeed;
  double get peakGForce => _peakGForce;
  int get frameCount => _frameCount;
  int get gpsFrameCount => _gpsFrameCount;

  @override
  String toString() {
    return 'PostImpactMonitor('
        'monitoring: $_isMonitoring, '
        'stillness: ${_stillnessDurationMs}ms, '
        'movement: ${_movementDurationMs}ms, '
        'observed: ${effectiveObservedDurationMs}ms, '
        'avgGForce: ${_averageGForce.toStringAsFixed(2)}, '
        'avgSpeed: ${_averageSpeed.toStringAsFixed(1)} km/h, '
        'confidence: ${getStillnessConfidence().toStringAsFixed(1)}%'
        ')';
  }
}
