import '../../../core/constants/app_thresholds.dart';
import 'sensor_fusion_frame.dart';

/// ==========================================
/// 📊 Event Window Model - Guardian 360
/// ==========================================
/// Represents a time-windowed buffer of sensor data for analyzing:
/// - Pre-impact behavior.
/// - Impact spike.
/// - Post-impact behavior.
///
/// This model belongs to the advanced accident detection architecture:
/// SensorFusionService
///   → EventWindowAnalyzer
///   → PostImpactMonitor
///   → AccidentDetectionEngine
class EventWindow {
  /// Pre-impact sensor frames.
  final List<SensorFusionFrame> preImpactFrames;

  /// Impact sensor frames.
  final List<SensorFusionFrame> impactFrames;

  /// Post-impact sensor frames.
  final List<SensorFusionFrame> postImpactFrames;

  /// Timestamp when the impact was detected.
  final DateTime impactTimestamp;

  /// Window start time.
  final DateTime windowStart;

  /// Window end time.
  final DateTime windowEnd;

  const EventWindow({
    required this.preImpactFrames,
    required this.impactFrames,
    required this.postImpactFrames,
    required this.impactTimestamp,
    required this.windowStart,
    required this.windowEnd,
  });

  /// Create an empty event window.
  factory EventWindow.empty() {
    final now = DateTime.now();

    return EventWindow(
      preImpactFrames: const [],
      impactFrames: const [],
      postImpactFrames: const [],
      impactTimestamp: now,
      windowStart: now,
      windowEnd: now,
    );
  }

  // ==========================================
  // 📦 Frame Collections
  // ==========================================

  List<SensorFusionFrame> get allFrames {
    return <SensorFusionFrame>[
      ...preImpactFrames,
      ...impactFrames,
      ...postImpactFrames,
    ];
  }

  List<SensorFusionFrame> get validPreImpactFrames {
    return _validFrames(preImpactFrames);
  }

  List<SensorFusionFrame> get validImpactFrames {
    return _validFrames(impactFrames);
  }

  List<SensorFusionFrame> get validPostImpactFrames {
    return _validFrames(postImpactFrames);
  }

  List<SensorFusionFrame> get validAllFrames {
    return _validFrames(allFrames);
  }

  List<SensorFusionFrame> get gpsPreImpactFrames {
    return _gpsFrames(validPreImpactFrames);
  }

  List<SensorFusionFrame> get gpsImpactFrames {
    return _gpsFrames(validImpactFrames);
  }

  List<SensorFusionFrame> get gpsPostImpactFrames {
    return _gpsFrames(validPostImpactFrames);
  }

  List<SensorFusionFrame> get gpsAllFrames {
    return _gpsFrames(validAllFrames);
  }

  // ==========================================
  // 📈 Pre-Impact Analysis
  // ==========================================

  /// Average speed before impact.
  ///
  /// Uses only valid GPS frames. If GPS is unavailable, returns 0.0.
  double get preImpactAverageSpeed {
    return _averageSpeed(gpsPreImpactFrames);
  }

  /// Peak speed before impact.
  double get peakSpeedBeforeImpact {
    return _peakSpeed(gpsPreImpactFrames);
  }

  /// Peak G-Force before impact.
  double get preImpactPeakGForce {
    return _peakGForce(validPreImpactFrames);
  }

  /// Average G-Force before impact.
  double get preImpactAverageGForce {
    return _averageGForce(validPreImpactFrames);
  }

  /// Whether pre-impact deceleration exists.
  ///
  /// Prefer before/after comparison if post-impact GPS exists.
  /// Fallback to first/last pre-impact GPS frames.
  bool get hasPreImpactDeceleration {
    if (gpsPreImpactFrames.length < 2) return false;

    final firstSpeed = gpsPreImpactFrames.first.speedKmh;
    final lastSpeed = gpsPreImpactFrames.last.speedKmh;
    final speedDrop = firstSpeed - lastSpeed;

    return AppThresholds.isSignificantSpeedDrop(speedDrop);
  }

  // ==========================================
  // 💥 Impact Analysis
  // ==========================================

  /// Peak G-Force during impact.
  double get impactPeakGForce {
    return _peakGForce(validImpactFrames);
  }

  /// Average G-Force during impact.
  double get impactAverageGForce {
    return _averageGForce(validImpactFrames);
  }

  /// Peak rotation during impact.
  double get impactPeakRotation {
    return _peakRotation(validImpactFrames);
  }

  /// Average rotation during impact.
  double get impactAverageRotation {
    return _averageRotation(validImpactFrames);
  }

  /// Maximum speed drop during impact.
  ///
  /// Uses speedDropKmh from GPS-backed frames only.
  double get impactMaxSpeedDrop {
    return _peakSpeedDrop(gpsImpactFrames);
  }

  /// Average speed drop during impact.
  double get impactAverageSpeedDrop {
    return _averageSpeedDrop(gpsImpactFrames);
  }

  // ==========================================
  // 🛑 Post-Impact Analysis
  // ==========================================

  /// Average G-Force after impact.
  double get postImpactAverageGForce {
    return _averageGForce(validPostImpactFrames);
  }

  /// Average speed after impact.
  ///
  /// Uses only valid GPS frames. If GPS is unavailable, returns 0.0.
  double get postImpactAverageSpeed {
    return _averageSpeed(gpsPostImpactFrames);
  }

  /// Peak speed after impact.
  double get peakSpeedAfterImpact {
    return _peakSpeed(gpsPostImpactFrames);
  }

  /// Whether the system appears still after impact.
  ///
  /// If GPS is unavailable, stillness can be inferred from low G-force only,
  /// but with less confidence later in PostImpactMonitor.
  bool get isStillAfterImpact {
    if (validPostImpactFrames.isEmpty) return false;

    final avgGForce = postImpactAverageGForce;

    final gForceLooksStill = AppThresholds.isStillness(avgGForce);

    if (gpsPostImpactFrames.isEmpty) {
      return gForceLooksStill;
    }

    final avgSpeed = postImpactAverageSpeed;
    return gForceLooksStill && avgSpeed < AppThresholds.minActiveSpeedKmh;
  }

  /// Stillness duration in milliseconds.
  ///
  /// Counts all still post-impact frame deltas, not only the first continuous
  /// still segment. This avoids undercounting if one noisy frame appears.
  int get stillnessDurationMs {
    if (validPostImpactFrames.isEmpty) return 0;

    var duration = 0;

    for (final frame in validPostImpactFrames) {
      final isGForceStill = AppThresholds.isStillness(frame.gForce);

      final isSpeedStill = frame.hasGPSData
          ? frame.speedKmh < AppThresholds.minActiveSpeedKmh
          : true;

      if (!isGForceStill || !isSpeedStill) continue;

      duration += _safeFrameDeltaMs(frame);
    }

    return duration;
  }

  /// Movement duration in milliseconds after impact.
  int get movementDurationMs {
    if (validPostImpactFrames.isEmpty) return 0;

    var duration = 0;

    for (final frame in validPostImpactFrames) {
      final isGForceStill = AppThresholds.isStillness(frame.gForce);

      final isSpeedStill = frame.hasGPSData
          ? frame.speedKmh < AppThresholds.minActiveSpeedKmh
          : true;

      if (isGForceStill && isSpeedStill) continue;

      duration += _safeFrameDeltaMs(frame);
    }

    return duration;
  }

  // ==========================================
  // 🚗 Speed / GPS Analysis
  // ==========================================

  /// Total before/after speed drop.
  ///
  /// Uses only GPS-backed frames. If either side has no GPS, returns 0.0.
  double get totalBeforeAfterSpeedDrop {
    if (gpsPreImpactFrames.isEmpty || gpsPostImpactFrames.isEmpty) {
      return 0.0;
    }

    final drop = preImpactAverageSpeed - postImpactAverageSpeed;
    return drop.clamp(0.0, AppThresholds.maxReasonableSpeedKmh).toDouble();
  }

  /// Speed variance across GPS-backed frames only.
  double get speedVariance {
    final frames = gpsAllFrames;

    if (frames.length < 2) return 0.0;

    final speeds = frames.map((frame) => frame.speedKmh).toList();
    final mean = speeds.reduce((a, b) => a + b) / speeds.length;

    final variance =
        speeds.fold<double>(
          0.0,
          (sum, speed) => sum + ((speed - mean) * (speed - mean)),
        ) /
        speeds.length;

    return variance;
  }

  bool get hasGpsContext {
    return gpsAllFrames.isNotEmpty;
  }

  bool get hasPreAndPostGpsContext {
    return gpsPreImpactFrames.isNotEmpty && gpsPostImpactFrames.isNotEmpty;
  }

  int get gpsFrameCount {
    return gpsAllFrames.length;
  }

  // ==========================================
  // 📊 Overall Window Analysis
  // ==========================================

  /// Total number of frames.
  int get totalFrames {
    return preImpactFrames.length +
        impactFrames.length +
        postImpactFrames.length;
  }

  /// Total number of structurally valid frames.
  int get validFrameCount {
    return validAllFrames.length;
  }

  /// Window duration in milliseconds.
  int get windowDurationMs {
    final duration = windowEnd.difference(windowStart).inMilliseconds;
    return duration < 0 ? 0 : duration;
  }

  /// Whether the window contains enough data for advanced analysis.
  ///
  /// Pre/post frames are useful, but the impact frames are the hard requirement.
  bool get hasValidData {
    return validImpactFrames.isNotEmpty && validFrameCount >= 3;
  }

  /// Whether all frames are structurally valid.
  bool get hasStructurallyValidFrames {
    if (allFrames.isEmpty) return false;
    return allFrames.every((frame) => frame.isStructurallyValid);
  }

  /// Most severe frame across the entire window.
  SensorFusionFrame? get mostSevereFrame {
    final frames = validAllFrames;

    if (frames.isEmpty) return null;

    return frames.reduce((a, b) {
      final aScore = _frameSeverityWeight(a);
      final bScore = _frameSeverityWeight(b);

      return aScore >= bScore ? a : b;
    });
  }

  double get impactToRotationRatio {
    final rotation = impactPeakRotation;

    if (rotation <= 0.0) return impactPeakGForce;

    return impactPeakGForce / rotation;
  }

  bool get hasImpactSpike {
    return impactPeakGForce >= AppThresholds.advancedMinAccidentThreshold;
  }

  bool get hasRotationSpike {
    return impactPeakRotation >= AppThresholds.advancedRotationThresholdHigh;
  }

  bool get hasSpeedDrop {
    return AppThresholds.isSignificantSpeedDrop(
      totalBeforeAfterSpeedDrop > 0.0
          ? totalBeforeAfterSpeedDrop
          : impactMaxSpeedDrop,
    );
  }

  bool get hasPostImpactStillnessEvidence {
    return stillnessDurationMs > 0 || isStillAfterImpact;
  }

  /// Create a debugging map.
  Map<String, dynamic> toDebugMap() {
    return {
      'preImpactFrames': preImpactFrames.length,
      'impactFrames': impactFrames.length,
      'postImpactFrames': postImpactFrames.length,
      'validFrameCount': validFrameCount,
      'gpsFrameCount': gpsFrameCount,
      'totalFrames': totalFrames,
      'windowDurationMs': windowDurationMs,

      // Speed / GPS analysis
      'preImpactAverageSpeed': preImpactAverageSpeed,
      'postImpactAverageSpeed': postImpactAverageSpeed,
      'totalBeforeAfterSpeedDrop': totalBeforeAfterSpeedDrop,
      'speedVariance': speedVariance,
      'hasGpsContext': hasGpsContext,
      'hasPreAndPostGpsContext': hasPreAndPostGpsContext,

      // Impact analysis
      'impactPeakGForce': impactPeakGForce,
      'impactAverageGForce': impactAverageGForce,
      'impactPeakRotation': impactPeakRotation,
      'impactAverageRotation': impactAverageRotation,
      'impactMaxSpeedDrop': impactMaxSpeedDrop,
      'impactAverageSpeedDrop': impactAverageSpeedDrop,

      // Post-impact analysis
      'postImpactAverageGForce': postImpactAverageGForce,
      'stillnessDurationMs': stillnessDurationMs,
      'movementDurationMs': movementDurationMs,
      'isStillAfterImpact': isStillAfterImpact,
      'hasPostImpactStillnessEvidence': hasPostImpactStillnessEvidence,

      // Validation / signals
      'hasValidData': hasValidData,
      'hasStructurallyValidFrames': hasStructurallyValidFrames,
      'hasImpactSpike': hasImpactSpike,
      'hasRotationSpike': hasRotationSpike,
      'hasSpeedDrop': hasSpeedDrop,
    };
  }

  // ==========================================
  // Private Helpers
  // ==========================================

  static List<SensorFusionFrame> _validFrames(List<SensorFusionFrame> frames) {
    return frames.where((frame) => frame.isStructurallyValid).toList();
  }

  static List<SensorFusionFrame> _gpsFrames(List<SensorFusionFrame> frames) {
    return frames.where((frame) => frame.hasGPSData).toList();
  }

  static double _averageGForce(List<SensorFusionFrame> frames) {
    if (frames.isEmpty) return 0.0;

    final sum = frames.fold<double>(
      0.0,
      (total, frame) => total + frame.gForce,
    );

    return sum / frames.length;
  }

  static double _averageRotation(List<SensorFusionFrame> frames) {
    if (frames.isEmpty) return 0.0;

    final sum = frames.fold<double>(
      0.0,
      (total, frame) => total + frame.rotation,
    );

    return sum / frames.length;
  }

  static double _averageSpeed(List<SensorFusionFrame> frames) {
    if (frames.isEmpty) return 0.0;

    final sum = frames.fold<double>(
      0.0,
      (total, frame) => total + frame.speedKmh,
    );

    return sum / frames.length;
  }

  static double _averageSpeedDrop(List<SensorFusionFrame> frames) {
    if (frames.isEmpty) return 0.0;

    final sum = frames.fold<double>(
      0.0,
      (total, frame) => total + frame.speedDropKmh,
    );

    return sum / frames.length;
  }

  static double _peakGForce(List<SensorFusionFrame> frames) {
    var peak = 0.0;

    for (final frame in frames) {
      if (frame.gForce > peak) peak = frame.gForce;
    }

    return peak;
  }

  static double _peakRotation(List<SensorFusionFrame> frames) {
    var peak = 0.0;

    for (final frame in frames) {
      if (frame.rotation > peak) peak = frame.rotation;
    }

    return peak;
  }

  static double _peakSpeed(List<SensorFusionFrame> frames) {
    var peak = 0.0;

    for (final frame in frames) {
      if (frame.speedKmh > peak) peak = frame.speedKmh;
    }

    return peak;
  }

  static double _peakSpeedDrop(List<SensorFusionFrame> frames) {
    var peak = 0.0;

    for (final frame in frames) {
      if (frame.speedDropKmh > peak) peak = frame.speedDropKmh;
    }

    return peak;
  }

  static int _safeFrameDeltaMs(SensorFusionFrame frame) {
    if (frame.timeDeltaMs <= 0) return 0;

    // Prevent delayed frames from exaggerating stillness/movement.
    return frame.timeDeltaMs.clamp(0, 500);
  }

  static double _frameSeverityWeight(SensorFusionFrame frame) {
    return (frame.gForce * 0.65) +
        (frame.rotation * 0.25) +
        (frame.speedDropKmh * 0.10);
  }

  @override
  String toString() {
    return 'EventWindow('
        'preImpact: ${preImpactFrames.length} frames, '
        'impact: ${impactFrames.length} frames, '
        'postImpact: ${postImpactFrames.length} frames, '
        'valid: $validFrameCount/$totalFrames, '
        'gps: $gpsFrameCount, '
        'peakGForce: ${impactPeakGForce.toStringAsFixed(2)}, '
        'peakRotation: ${impactPeakRotation.toStringAsFixed(2)}, '
        'speedDrop: ${totalBeforeAfterSpeedDrop.toStringAsFixed(1)}, '
        'stillness: $isStillAfterImpact, '
        'duration: ${windowDurationMs}ms'
        ')';
  }
}
