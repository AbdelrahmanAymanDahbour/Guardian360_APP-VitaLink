import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../constants/app_thresholds.dart';

enum DetectionSensitivity { high, medium, low }

class SensorService {
  SensorService();

  StreamSubscription<UserAccelerometerEvent>? _accelSub;
  StreamSubscription<GyroscopeEvent>? _gyroSub;

  bool _isRunning = false;
  DateTime? _lastDetectionTime;
  DateTime? _lastIntentionalShakeTime;

  Duration detectionCooldown = const Duration(seconds: 8);
  Duration fusionWindow = const Duration(
    milliseconds: AppThresholds.fusionWindowMilliseconds,
  );
  Duration historyWindow = const Duration(
    milliseconds: AppThresholds.historyWindowMilliseconds,
  );

  // نافذة منع قصيرة بعد اكتشاف shake intentional
  final Duration _intentionalShakeSuppressionWindow = const Duration(
    milliseconds: 1800,
  );

  int minImpactSamples = 2;
  int minRotationSamples = 2;

  DetectionSensitivity _sensitivity = DetectionSensitivity.medium;

  double _impactThreshold = 5.0;
  double _rotationThreshold = 4.0;
  double _severeImpactThreshold = 8.5;

  double _impactNoiseFloor = AppThresholds.impactNoiseFloor;
  double _rotationNoiseFloor = AppThresholds.rotationNoiseFloor;

  double _latestImpact = 0.0;
  double _latestRotation = 0.0;

  final List<_TimedSample> _impactHistory = <_TimedSample>[];
  final List<_TimedSample> _rotationHistory = <_TimedSample>[];

  // Shake-pattern tracking
  int _consecutiveShakes = 0;
  DateTime? _lastShakeTime;
  final Duration _shakePatternWindow = const Duration(seconds: 2);
  final int _requiredShakeCount = 3;
  double _shakeThreshold = AppThresholds.impactNoiseFloor;

  bool get isRunning => _isRunning;
  DetectionSensitivity get sensitivity => _sensitivity;

  double get impactThreshold => _impactThreshold;
  double get rotationThreshold => _rotationThreshold;
  double get severeImpactThreshold => _severeImpactThreshold;
  double get latestImpact => _latestImpact;
  double get latestRotation => _latestRotation;

  void startSmartDetection({
    required void Function(double gForce, double rotation) onAccidentDetected,
  }) {
    if (_isRunning) return;

    try {
      _applySensitivity(_sensitivity);
      _clearBuffers();
      _isRunning = true;

      _accelSub = userAccelerometerEventStream().listen(
        (event) {
          try {
            final now = DateTime.now();
            final impact = sqrt(
              (event.x * event.x) + (event.y * event.y) + (event.z * event.z),
            );

            if (impact.isNaN || impact.isInfinite) return;

            _latestImpact = impact;

            if (impact >= _impactNoiseFloor) {
              _impactHistory.add(_TimedSample(value: impact, timestamp: now));
            }

            _detectShakePattern(impact, now);
            _trimOldSamples(now);
            _tryDetectAccident(onAccidentDetected);
          } catch (e) {
            debugPrint('⚠️ SensorService accel event processing error: $e');
          }
        },
        onError: (error, _) {
          debugPrint('❌ SensorService accel stream error: $error');
        },
        cancelOnError: false,
      );

      _gyroSub = gyroscopeEventStream().listen(
        (event) {
          try {
            final now = DateTime.now();
            final rotation = sqrt(
              (event.x * event.x) + (event.y * event.y) + (event.z * event.z),
            );

            if (rotation.isNaN || rotation.isInfinite) return;

            _latestRotation = rotation;

            if (rotation >= _rotationNoiseFloor) {
              _rotationHistory.add(
                _TimedSample(value: rotation, timestamp: now),
              );
            }

            _trimOldSamples(now);
            _tryDetectAccident(onAccidentDetected);
          } catch (e) {
            debugPrint('⚠️ SensorService gyro event processing error: $e');
          }
        },
        onError: (error, _) {
          debugPrint('❌ SensorService gyro stream error: $error');
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('❌ SensorService startSmartDetection critical error: $e');
      _isRunning = false;
    }
  }

  Future<void> stopAllSensors() async {
    await _accelSub?.cancel();
    await _gyroSub?.cancel();

    _accelSub = null;
    _gyroSub = null;
    _isRunning = false;
    _lastDetectionTime = null;
    _lastIntentionalShakeTime = null;

    _clearBuffers();
  }

  void setSensitivity(String level) {
    switch (level.trim().toLowerCase()) {
      case 'high':
        _sensitivity = DetectionSensitivity.high;
        break;
      case 'low':
        _sensitivity = DetectionSensitivity.low;
        break;
      case 'medium':
      default:
        _sensitivity = DetectionSensitivity.medium;
        break;
    }

    _applySensitivity(_sensitivity);
  }

  void setSensitivityLevel(DetectionSensitivity level) {
    _sensitivity = level;
    _applySensitivity(level);
  }

  void _applySensitivity(DetectionSensitivity level) {
    final sensitivityString = level.toString().split('.').last;

    _impactThreshold = AppThresholds.getImpactThreshold(sensitivityString);
    _rotationThreshold = AppThresholds.getRotationThreshold(sensitivityString);
    _severeImpactThreshold = AppThresholds.getSevereImpactThreshold(
      sensitivityString,
    );
    minImpactSamples = AppThresholds.getMinImpactSamples(sensitivityString);
    minRotationSamples = AppThresholds.getMinRotationSamples(sensitivityString);

    _impactNoiseFloor = AppThresholds.impactNoiseFloor;
    _rotationNoiseFloor = AppThresholds.rotationNoiseFloor;
    _shakeThreshold = AppThresholds.impactNoiseFloor;
  }

  void _tryDetectAccident(
    void Function(double gForce, double rotation) onAccidentDetected,
  ) {
    try {
      final now = DateTime.now();

      if (_isInCooldown(now)) return;
      if (_isInIntentionalShakeSuppression(now)) return;

      _trimOldSamples(now);

      if (_impactHistory.isEmpty || _rotationHistory.isEmpty) {
        return;
      }

      final strongImpactSamples = _countAboveThreshold(
        _impactHistory,
        _impactThreshold,
      );

      final strongRotationSamples = _countAboveThreshold(
        _rotationHistory,
        _rotationThreshold,
      );

      final recentImpact = _hasRecentAboveThreshold(
        _impactHistory,
        _impactThreshold,
        now,
        fusionWindow,
      );

      final recentRotation = _hasRecentAboveThreshold(
        _rotationHistory,
        _rotationThreshold,
        now,
        fusionWindow,
      );

      if (!recentImpact || !recentRotation) return;
      if (strongImpactSamples < minImpactSamples) return;
      if (strongRotationSamples < minRotationSamples) return;

      final smoothedImpact = _averageTopSamples(
        _impactHistory,
        _impactThreshold,
        topCount: 3,
      );

      final smoothedRotation = _averageTopSamples(
        _rotationHistory,
        _rotationThreshold,
        topCount: 3,
      );

      if (smoothedImpact.isNaN || smoothedImpact.isInfinite) return;
      if (smoothedRotation.isNaN || smoothedRotation.isInfinite) return;

      // يجب أن تبقى القيم معقولة حتى بعد التنعيم
      if (smoothedImpact < _impactThreshold) return;
      if (smoothedRotation < _rotationThreshold) return;

      _lastDetectionTime = now;
      onAccidentDetected(smoothedImpact, smoothedRotation);
    } catch (e) {
      debugPrint('⚠️ SensorService _tryDetectAccident error: $e');
    }
  }

  bool _isInCooldown(DateTime now) {
    if (_lastDetectionTime == null) return false;
    return now.difference(_lastDetectionTime!) < detectionCooldown;
  }

  bool _isInIntentionalShakeSuppression(DateTime now) {
    if (_lastIntentionalShakeTime == null) return false;
    return now.difference(_lastIntentionalShakeTime!) <
        _intentionalShakeSuppressionWindow;
  }

  void _trimOldSamples(DateTime now) {
    _impactHistory.removeWhere(
      (sample) => now.difference(sample.timestamp) > historyWindow,
    );

    _rotationHistory.removeWhere(
      (sample) => now.difference(sample.timestamp) > historyWindow,
    );
  }

  int _countAboveThreshold(List<_TimedSample> samples, double threshold) {
    int count = 0;
    for (final sample in samples) {
      if (!sample.value.isNaN &&
          !sample.value.isInfinite &&
          sample.value >= threshold) {
        count++;
      }
    }
    return count;
  }

  bool _hasRecentAboveThreshold(
    List<_TimedSample> samples,
    double threshold,
    DateTime now,
    Duration window,
  ) {
    for (final sample in samples.reversed) {
      final isInsideWindow = now.difference(sample.timestamp) <= window;
      if (!isInsideWindow) break;

      if (!sample.value.isNaN &&
          !sample.value.isInfinite &&
          sample.value >= threshold) {
        return true;
      }
    }
    return false;
  }

  double _averageTopSamples(
    List<_TimedSample> samples,
    double threshold, {
    int topCount = 3,
  }) {
    final filtered = samples
        .where(
          (sample) =>
              !sample.value.isNaN &&
              !sample.value.isInfinite &&
              sample.value >= threshold,
        )
        .map((s) => s.value)
        .toList();

    if (filtered.isEmpty) return 0.0;

    filtered.sort((a, b) => b.compareTo(a));

    final takeCount = filtered.length < topCount ? filtered.length : topCount;
    final selected = filtered.take(takeCount).toList();

    final sum = selected.fold<double>(0.0, (prev, value) => prev + value);
    return sum / selected.length;
  }

  void _clearBuffers() {
    _impactHistory.clear();
    _rotationHistory.clear();
    _latestImpact = 0.0;
    _latestRotation = 0.0;
    _consecutiveShakes = 0;
    _lastShakeTime = null;
  }

  void _detectShakePattern(double impact, DateTime now) {
    if (impact < _shakeThreshold || impact > _impactThreshold) {
      return;
    }

    if (_lastShakeTime != null) {
      final timeSinceLastShake = now.difference(_lastShakeTime!);

      if (timeSinceLastShake > _shakePatternWindow) {
        _consecutiveShakes = 1;
        _lastShakeTime = now;
        return;
      }

      _consecutiveShakes++;
      _lastShakeTime = now;

      if (_consecutiveShakes >= _requiredShakeCount) {
        _lastIntentionalShakeTime = now;
        debugPrint(
          '🔍 Intentional shake pattern detected! '
          '($_consecutiveShakes shakes) -> detection temporarily suppressed',
        );
        _consecutiveShakes = 0;
      }
    } else {
      _consecutiveShakes = 1;
      _lastShakeTime = now;
    }
  }
}

class _TimedSample {
  final double value;
  final DateTime timestamp;

  const _TimedSample({required this.value, required this.timestamp});
}
