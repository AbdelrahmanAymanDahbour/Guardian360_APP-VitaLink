import '../../../core/constants/app_thresholds.dart';

/// ==========================================
/// ⚙️ Detection Configuration Model - Guardian 360
/// ==========================================
/// Central configuration for the advanced accident detection engine.
///
/// Used by:
/// - SensorFusionService
/// - EventWindowAnalyzer
/// - PostImpactMonitor
/// - AccidentDetectionEngine
///
/// This config is dedicated to the advanced architecture:
/// SensorFusionService
///   → EventWindowAnalyzer
///   → PostImpactMonitor
///   → AccidentDetectionEngine
class DetectionConfig {
  /// Detection sensitivity level:
  /// high / medium / low
  final String sensitivityLevel;

  // ==========================================
  // 💥 Impact Thresholds
  // ==========================================

  /// G-force threshold required to open an event window.
  final double impactThreshold;

  /// Strong/severe G-force threshold that can open an event window immediately.
  final double severeImpactThreshold;

  /// Rotation threshold in rad/s.
  final double rotationThreshold;

  /// Minimum impact samples expected for stable analysis.
  final int minImpactSamples;

  /// Minimum rotation samples expected for stable analysis.
  final int minRotationSamples;

  // ==========================================
  // ⏱️ Time Windows
  // ==========================================

  /// Pre-impact window duration in milliseconds.
  final int preImpactWindowMs;

  /// Impact window duration in milliseconds.
  final int impactWindowMs;

  /// Post-impact window duration in milliseconds.
  final int postImpactWindowMs;

  /// Detection cooldown period in seconds.
  final int detectionCooldownSeconds;

  // ==========================================
  // 🚗 Speed Thresholds
  // ==========================================

  /// Minimum speed drop to consider in km/h.
  final double minSpeedDropKmh;

  /// Critical speed drop threshold in km/h.
  final double criticalSpeedDropKmh;

  /// Minimum active speed in km/h.
  final double minActiveSpeedKmh;

  // ==========================================
  // 🛑 Stillness Detection
  // ==========================================

  /// G-force threshold for post-impact stillness.
  final double stillnessThresholdG;

  /// Required stillness duration in milliseconds.
  final int stillnessDurationMs;

  // ==========================================
  // ⚖️ Weighted Scoring
  // ==========================================

  final double weightImpact;
  final double weightRotation;
  final double weightSpeed;
  final double weightStillness;
  final double weightContext;

  /// Reference confidence threshold from 0 to 100.
  ///
  /// Final severity decisions are handled inside AccidentDetectionEngine.
  final double minConfidenceThreshold;

  // ==========================================
  // 🌍 Context Factors
  // ==========================================

  /// Speed threshold for highway vs city context.
  final double cityHighwaySpeedThresholdKmh;

  /// Highway context multiplier.
  final double highwayContextMultiplier;

  /// City context multiplier.
  final double cityContextMultiplier;

  // ==========================================
  // 📊 Sensor Fusion
  // ==========================================

  /// Maximum allowed time delta between accel/gyro sensor readings.
  final int maxSensorTimeDeltaMs;

  /// Sensor buffer size.
  final int sensorBufferSize;

  const DetectionConfig({
    required this.sensitivityLevel,
    required this.impactThreshold,
    required this.severeImpactThreshold,
    required this.rotationThreshold,
    this.minImpactSamples = AppThresholds.advancedMinImpactSamplesMedium,
    this.minRotationSamples = AppThresholds.advancedMinRotationSamplesMedium,
    required this.preImpactWindowMs,
    required this.impactWindowMs,
    required this.postImpactWindowMs,
    required this.detectionCooldownSeconds,
    required this.minSpeedDropKmh,
    required this.criticalSpeedDropKmh,
    required this.minActiveSpeedKmh,
    required this.stillnessThresholdG,
    required this.stillnessDurationMs,
    required this.weightImpact,
    required this.weightRotation,
    required this.weightSpeed,
    required this.weightStillness,
    required this.weightContext,
    required this.minConfidenceThreshold,
    required this.cityHighwaySpeedThresholdKmh,
    required this.highwayContextMultiplier,
    required this.cityContextMultiplier,
    required this.maxSensorTimeDeltaMs,
    required this.sensorBufferSize,
  });

  /// ==========================================
  /// 🏗️ Factory: Build config from sensitivity
  /// ==========================================
  /// Uses advanced thresholds only.
  factory DetectionConfig.fromSensitivity(String sensitivity) {
    final normalizedSensitivity = AppThresholds.normalizeSensitivity(
      sensitivity,
    );

    return DetectionConfig(
      sensitivityLevel: normalizedSensitivity,
      impactThreshold: AppThresholds.getAdvancedImpactThreshold(
        normalizedSensitivity,
      ),
      severeImpactThreshold: AppThresholds.getAdvancedSevereImpactThreshold(
        normalizedSensitivity,
      ),
      rotationThreshold: AppThresholds.getAdvancedRotationThreshold(
        normalizedSensitivity,
      ),
      minImpactSamples: AppThresholds.getAdvancedMinImpactSamples(
        normalizedSensitivity,
      ),
      minRotationSamples: AppThresholds.getAdvancedMinRotationSamples(
        normalizedSensitivity,
      ),
      preImpactWindowMs: AppThresholds.preImpactWindowMs,
      impactWindowMs: AppThresholds.impactWindowMs,
      postImpactWindowMs: AppThresholds.postImpactWindowMs,
      detectionCooldownSeconds: AppThresholds.advancedDetectionCooldownSeconds,
      minSpeedDropKmh: AppThresholds.minSpeedDropKmh,
      criticalSpeedDropKmh: AppThresholds.criticalSpeedDropKmh,
      minActiveSpeedKmh: AppThresholds.minActiveSpeedKmh,
      stillnessThresholdG: AppThresholds.stillnessThresholdG,
      stillnessDurationMs: AppThresholds.stillnessDurationMs,
      weightImpact: AppThresholds.weightImpact,
      weightRotation: AppThresholds.weightRotation,
      weightSpeed: AppThresholds.weightSpeed,
      weightStillness: AppThresholds.weightStillness,
      weightContext: AppThresholds.weightContext,
      minConfidenceThreshold: AppThresholds.minConfidenceThreshold,
      cityHighwaySpeedThresholdKmh: AppThresholds.cityHighwaySpeedThresholdKmh,
      highwayContextMultiplier: AppThresholds.highwayContextMultiplier,
      cityContextMultiplier: AppThresholds.cityContextMultiplier,
      maxSensorTimeDeltaMs: AppThresholds.maxSensorTimeDeltaMs,
      sensorBufferSize: AppThresholds.sensorBufferSize,
    );
  }

  /// Default medium sensitivity.
  factory DetectionConfig.medium() {
    return DetectionConfig.fromSensitivity(AppThresholds.sensitivityMedium);
  }

  /// High sensitivity.
  factory DetectionConfig.high() {
    return DetectionConfig.fromSensitivity(AppThresholds.sensitivityHigh);
  }

  /// Low sensitivity.
  factory DetectionConfig.low() {
    return DetectionConfig.fromSensitivity(AppThresholds.sensitivityLow);
  }

  /// ==========================================
  /// 🔄 Runtime Adjustment
  /// ==========================================

  DetectionConfig copyWith({
    String? sensitivityLevel,
    double? impactThreshold,
    double? severeImpactThreshold,
    double? rotationThreshold,
    int? minImpactSamples,
    int? minRotationSamples,
    int? preImpactWindowMs,
    int? impactWindowMs,
    int? postImpactWindowMs,
    int? detectionCooldownSeconds,
    double? minSpeedDropKmh,
    double? criticalSpeedDropKmh,
    double? minActiveSpeedKmh,
    double? stillnessThresholdG,
    int? stillnessDurationMs,
    double? weightImpact,
    double? weightRotation,
    double? weightSpeed,
    double? weightStillness,
    double? weightContext,
    double? minConfidenceThreshold,
    double? cityHighwaySpeedThresholdKmh,
    double? highwayContextMultiplier,
    double? cityContextMultiplier,
    int? maxSensorTimeDeltaMs,
    int? sensorBufferSize,
  }) {
    final resolvedSensitivity = sensitivityLevel == null
        ? this.sensitivityLevel
        : AppThresholds.normalizeSensitivity(sensitivityLevel);

    return DetectionConfig(
      sensitivityLevel: resolvedSensitivity,
      impactThreshold: impactThreshold ?? this.impactThreshold,
      severeImpactThreshold:
          severeImpactThreshold ?? this.severeImpactThreshold,
      rotationThreshold: rotationThreshold ?? this.rotationThreshold,
      minImpactSamples: minImpactSamples ?? this.minImpactSamples,
      minRotationSamples: minRotationSamples ?? this.minRotationSamples,
      preImpactWindowMs: preImpactWindowMs ?? this.preImpactWindowMs,
      impactWindowMs: impactWindowMs ?? this.impactWindowMs,
      postImpactWindowMs: postImpactWindowMs ?? this.postImpactWindowMs,
      detectionCooldownSeconds:
          detectionCooldownSeconds ?? this.detectionCooldownSeconds,
      minSpeedDropKmh: minSpeedDropKmh ?? this.minSpeedDropKmh,
      criticalSpeedDropKmh: criticalSpeedDropKmh ?? this.criticalSpeedDropKmh,
      minActiveSpeedKmh: minActiveSpeedKmh ?? this.minActiveSpeedKmh,
      stillnessThresholdG: stillnessThresholdG ?? this.stillnessThresholdG,
      stillnessDurationMs: stillnessDurationMs ?? this.stillnessDurationMs,
      weightImpact: weightImpact ?? this.weightImpact,
      weightRotation: weightRotation ?? this.weightRotation,
      weightSpeed: weightSpeed ?? this.weightSpeed,
      weightStillness: weightStillness ?? this.weightStillness,
      weightContext: weightContext ?? this.weightContext,
      minConfidenceThreshold:
          minConfidenceThreshold ?? this.minConfidenceThreshold,
      cityHighwaySpeedThresholdKmh:
          cityHighwaySpeedThresholdKmh ?? this.cityHighwaySpeedThresholdKmh,
      highwayContextMultiplier:
          highwayContextMultiplier ?? this.highwayContextMultiplier,
      cityContextMultiplier:
          cityContextMultiplier ?? this.cityContextMultiplier,
      maxSensorTimeDeltaMs: maxSensorTimeDeltaMs ?? this.maxSensorTimeDeltaMs,
      sensorBufferSize: sensorBufferSize ?? this.sensorBufferSize,
    );
  }

  // ==========================================
  // ✅ Validation Helpers
  // ==========================================

  bool get isHighSensitivity {
    return sensitivityLevel == AppThresholds.sensitivityHigh;
  }

  bool get isMediumSensitivity {
    return sensitivityLevel == AppThresholds.sensitivityMedium;
  }

  bool get isLowSensitivity {
    return sensitivityLevel == AppThresholds.sensitivityLow;
  }

  /// Validate that all weights are in range and sum to approximately 1.0.
  bool get hasValidWeights {
    final totalWeight =
        weightImpact +
        weightRotation +
        weightSpeed +
        weightStillness +
        weightContext;

    return _isWeight(weightImpact) &&
        _isWeight(weightRotation) &&
        _isWeight(weightSpeed) &&
        _isWeight(weightStillness) &&
        _isWeight(weightContext) &&
        (totalWeight - 1.0).abs() < 0.01;
  }

  bool get hasValidSensitivity {
    return AppThresholds.isKnownSensitivity(sensitivityLevel);
  }

  bool get hasValidImpactThresholds {
    return _isPositiveFinite(impactThreshold) &&
        _isPositiveFinite(severeImpactThreshold) &&
        severeImpactThreshold >= impactThreshold &&
        _isPositiveFinite(rotationThreshold);
  }

  bool get hasValidSampleRequirements {
    return minImpactSamples > 0 && minRotationSamples > 0;
  }

  bool get hasValidWindows {
    return preImpactWindowMs > 0 &&
        impactWindowMs > 0 &&
        postImpactWindowMs > 0 &&
        totalEventWindowMs > impactWindowMs &&
        totalEventWindowMs <= 15000;
  }

  bool get hasValidCooldown {
    return detectionCooldownSeconds > 0 && detectionCooldownSeconds <= 120;
  }

  bool get hasValidSpeedThresholds {
    return _isFiniteNonNegative(minSpeedDropKmh) &&
        _isFiniteNonNegative(criticalSpeedDropKmh) &&
        criticalSpeedDropKmh >= minSpeedDropKmh &&
        _isFiniteNonNegative(minActiveSpeedKmh) &&
        AppThresholds.isValidSpeed(minActiveSpeedKmh);
  }

  bool get hasValidStillnessConfig {
    return _isFiniteNonNegative(stillnessThresholdG) &&
        stillnessThresholdG <= 2.0 &&
        stillnessDurationMs > 0 &&
        stillnessDurationMs <= postImpactWindowMs;
  }

  bool get hasValidConfidenceThreshold {
    return _isFiniteInRange(minConfidenceThreshold, min: 0.0, max: 100.0);
  }

  bool get hasValidContextConfig {
    return _isPositiveFinite(cityHighwaySpeedThresholdKmh) &&
        cityHighwaySpeedThresholdKmh <= AppThresholds.maxReasonableSpeedKmh &&
        _isPositiveFinite(highwayContextMultiplier) &&
        _isPositiveFinite(cityContextMultiplier) &&
        highwayContextMultiplier <= 3.0 &&
        cityContextMultiplier <= 3.0;
  }

  bool get hasValidSensorFusionConfig {
    return maxSensorTimeDeltaMs > 0 &&
        maxSensorTimeDeltaMs <= 1000 &&
        sensorBufferSize > 0 &&
        sensorBufferSize <= 1000;
  }

  /// Total event window duration.
  int get totalEventWindowMs {
    return preImpactWindowMs + impactWindowMs + postImpactWindowMs;
  }

  /// Whether the config is structurally valid.
  bool get isStructurallyValid {
    return hasValidSensitivity &&
        hasValidImpactThresholds &&
        hasValidSampleRequirements &&
        hasValidWindows &&
        hasValidCooldown &&
        hasValidSpeedThresholds &&
        hasValidStillnessConfig &&
        hasValidWeights &&
        hasValidConfidenceThreshold &&
        hasValidContextConfig &&
        hasValidSensorFusionConfig;
  }

  Map<String, dynamic> toMap() {
    return {
      'sensitivityLevel': sensitivityLevel,
      'impactThreshold': impactThreshold,
      'severeImpactThreshold': severeImpactThreshold,
      'rotationThreshold': rotationThreshold,
      'minImpactSamples': minImpactSamples,
      'minRotationSamples': minRotationSamples,
      'preImpactWindowMs': preImpactWindowMs,
      'impactWindowMs': impactWindowMs,
      'postImpactWindowMs': postImpactWindowMs,
      'totalEventWindowMs': totalEventWindowMs,
      'detectionCooldownSeconds': detectionCooldownSeconds,
      'minSpeedDropKmh': minSpeedDropKmh,
      'criticalSpeedDropKmh': criticalSpeedDropKmh,
      'minActiveSpeedKmh': minActiveSpeedKmh,
      'stillnessThresholdG': stillnessThresholdG,
      'stillnessDurationMs': stillnessDurationMs,
      'weightImpact': weightImpact,
      'weightRotation': weightRotation,
      'weightSpeed': weightSpeed,
      'weightStillness': weightStillness,
      'weightContext': weightContext,
      'minConfidenceThreshold': minConfidenceThreshold,
      'cityHighwaySpeedThresholdKmh': cityHighwaySpeedThresholdKmh,
      'highwayContextMultiplier': highwayContextMultiplier,
      'cityContextMultiplier': cityContextMultiplier,
      'maxSensorTimeDeltaMs': maxSensorTimeDeltaMs,
      'sensorBufferSize': sensorBufferSize,
      'isStructurallyValid': isStructurallyValid,
    };
  }

  Map<String, dynamic> toDebugMap() => toMap();

  static bool _isFinite(double value) {
    return !value.isNaN && !value.isInfinite;
  }

  static bool _isPositiveFinite(double value) {
    return _isFinite(value) && value > 0.0;
  }

  static bool _isFiniteNonNegative(double value) {
    return _isFinite(value) && value >= 0.0;
  }

  static bool _isFiniteInRange(
    double value, {
    required double min,
    required double max,
  }) {
    return _isFinite(value) && value >= min && value <= max;
  }

  static bool _isWeight(double value) {
    return _isFiniteInRange(value, min: 0.0, max: 1.0);
  }

  @override
  String toString() {
    return 'DetectionConfig('
        'sensitivity: $sensitivityLevel, '
        'impactThreshold: ${impactThreshold.toStringAsFixed(2)}, '
        'severeImpactThreshold: ${severeImpactThreshold.toStringAsFixed(2)}, '
        'rotationThreshold: ${rotationThreshold.toStringAsFixed(2)}, '
        'samples: impact=$minImpactSamples rotation=$minRotationSamples, '
        'minConfidence: ${minConfidenceThreshold.toStringAsFixed(1)}, '
        'cooldown: ${detectionCooldownSeconds}s, '
        'window: ${totalEventWindowMs}ms, '
        'weights: [I:$weightImpact, R:$weightRotation, S:$weightSpeed, St:$weightStillness, C:$weightContext], '
        'valid: $isStructurallyValid'
        ')';
  }
}
