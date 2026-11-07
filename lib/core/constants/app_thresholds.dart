/// ==========================================
/// 🎯 App Thresholds - Guardian 360
/// ==========================================
/// Central thresholds and constants used across the app.
///
/// Rule:
/// - Do not hardcode detection/security/validation values in screens/services.
/// - Machine severity values must remain:
///   ignored / low / medium / high / critical
/// - Display labels should be handled separately from logic values.
class AppThresholds {
  // ==========================================
  // 💥 CURRENT PROJECT SENSOR THRESHOLDS
  // ==========================================
  // Kept for legacy/current SensorService compatibility.

  static const double impactThresholdHigh = 5.5;
  static const double impactThresholdMedium = 7.0;
  static const double impactThresholdLow = 8.8;

  static const double rotationThresholdHigh = 3.2;
  static const double rotationThresholdMedium = 4.1;
  static const double rotationThresholdLow = 5.2;

  static const double severeImpactThresholdHigh = 9.4;
  static const double severeImpactThresholdMedium = 11.2;
  static const double severeImpactThresholdLow = 13.0;

  static const double impactNoiseFloor = 0.8;
  static const double rotationNoiseFloor = 0.6;

  static const int minImpactSamplesHigh = 3;
  static const int minImpactSamplesMedium = 4;
  static const int minImpactSamplesLow = 5;

  static const int minRotationSamplesHigh = 2;
  static const int minRotationSamplesMedium = 3;
  static const int minRotationSamplesLow = 4;

  // ==========================================
  // 📊 SHARED SEVERITY VALUES
  // ==========================================

  static const String severityIgnored = 'ignored';
  static const String severityLow = 'low';
  static const String severityMedium = 'medium';
  static const String severityHigh = 'high';
  static const String severityCritical = 'critical';

  static const double severityScoreCritical = 72.0;
  static const double severityScoreHigh = 40.0;
  static const double severityScoreMedium = 20.0;

  static const double severityWeightImpact = 0.7;
  static const double severityWeightRotation = 0.3;

  // ==========================================
  // ⏱️ CURRENT TIME WINDOWS
  // ==========================================

  static const int fusionWindowMilliseconds = 900;
  static const int historyWindowMilliseconds = 1400;
  static const int detectionCooldownSeconds = 8;

  // ==========================================
  // ⏳ COUNTDOWN DURATIONS
  // ==========================================

  static const int countdownCriticalSeconds = 5;
  static const int countdownModerateSeconds = 10;
  static const int countdownLowSeconds = 15;

  // ==========================================
  // 📏 DISTANCE & LOCATION
  // ==========================================

  static const double minLocationChangeMeters = 10.0;
  static const double locationAccuracyMeters = 20.0;
  static const int locationTimeoutSeconds = 10;

  // ==========================================
  // 🏥 MEDICAL PROFILE COMPLETION
  // ==========================================

  static const double medicalProfileCompletionThreshold = 0.75;
  static const double medicalProfileMinimumThreshold = 0.5;

  // ==========================================
  // 📞 CONTACTS
  // ==========================================

  static const int maxEmergencyContacts = 5;
  static const int minEmergencyContacts = 1;

  // ==========================================
  // 🔐 AUTHENTICATION & VALIDATION
  // ==========================================

  static const int minPasswordLength = 6;
  static const int minNameLength = 3;
  static const int minPhoneLength = 9;
  static const int maxPhoneLength = 15;

  // ==========================================
  // 🔄 RETRY & TIMEOUT
  // ==========================================

  static const int maxRetryAttempts = 3;
  static const int networkTimeoutSeconds = 30;
  static const int firebaseTimeoutSeconds = 15;

  // ==========================================
  // 🚗 TRIP MANAGEMENT
  // ==========================================

  static const int maxTripDurationHours = 24;
  static const int minTripDurationMinutes = 1;
  static const int maxFalsePositivesBeforeWarning = 3;
  // ==========================================
  // 🛡️ SAFE ARRIVAL
  // ==========================================

  /// Collection name used by the Safe Arrival feature.
  static const String safeArrivalTripsCollection = 'safe_arrival_trips';

  /// User must be within this radius from the selected destination
  /// before the app can consider automatic arrival confirmation.
  static const double safeArrivalRadiusMeters = 120.0;

  /// User is considered close enough to the destination for approach UI
  /// and manual finish eligibility.
  static const double safeArrivalNearDestinationMeters = 350.0;

  /// Manual finish is allowed only when the user is near the destination.
  static const double safeArrivalManualFinishRadiusMeters = 350.0;

  /// GPS readings worse than this should not automatically confirm arrival.
  static const double safeArrivalMaxAccuracyMeters = 120.0;

  /// Excellent GPS accuracy reference used for safety scoring/reporting.
  static const double safeArrivalExcellentAccuracyMeters = 50.0;

  /// Required consecutive valid readings inside the arrival radius
  /// before auto-arrival is accepted.
  static const int safeArrivalRequiredStableReadings = 3;

  /// Ignore tiny movement segments caused by GPS noise.
  static const double safeArrivalMinMovementSegmentMeters = 3.0;

  /// If timestamps are unavailable, this caps a single accepted segment.
  static const double safeArrivalFallbackMaxSegmentMeters = 300.0;

  /// Extra tolerance added when filtering GPS jumps.
  static const double safeArrivalGpsJumpAccuracyBufferMeters = 80.0;

  /// Minimum improvement toward destination to count as real progress.
  static const double safeArrivalProgressThresholdMeters = 25.0;

  /// After ETA grace, danger requires no meaningful progress for this window.
  static const int safeArrivalNoProgressDangerMinutes = 7;

  /// GPS tracking distance filter.
  static const int safeArrivalTrackingDistanceFilterMeters = 10;

  /// Requested logical update interval for Safe Arrival tracking.
  /// Actual stream timing may still be controlled by platform GPS behavior.
  static const int safeArrivalLocationUpdateSeconds = 5;

  /// How often the active Safe Arrival trip should be synced to Firestore.
  static const int safeArrivalCloudUpdateSeconds = 30;

  /// If no GPS update arrives within this window, tracking health becomes weak.
  static const int safeArrivalWeakGpsSeconds = 45;

  /// Long stop threshold used for Guardian safety report.
  static const int safeArrivalLongStopMinutes = 10;

  /// Route deviation warning threshold.
  /// This is a first-pass threshold until Google Routes polyline matching is added.
  static const double safeArrivalRouteDeviationMeters = 750.0;

  /// Grace time after ETA before warning/danger escalation.
  static const int safeArrivalDelayGraceMinutes = 5;

  /// Safe Arrival trip duration bounds.
  static const int safeArrivalMinDurationMinutes = 1;
  static const int safeArrivalMaxDurationHours = 24;

  /// Guardian report should stay compact for UI and WhatsApp sharing.
  static const int safeArrivalMaxGuardianReportLength = 700;

  // ==========================================
  // 🔋 BATTERY & PERFORMANCE
  // ==========================================

  static const double minBatteryPercentageForMonitoring = 15.0;
  static const double batteryWarningPercentage = 20.0;

  // ==========================================
  // 📊 DATA LIMITS
  // ==========================================

  static const int maxLocalTripsCache = 50;
  static const int maxLocalAlertsCache = 100;
  static const int maxNotesLength = 500;

  // ==========================================
  // 🧠 ADVANCED DETECTION CORE THRESHOLDS
  // ==========================================
  // Used by:
  // SensorFusionService
  // EventWindowAnalyzer
  // PostImpactMonitor
  // AccidentDetectionEngine
  // SensorFusionFrame
  // EventWindow

  /// Minimum physical signal that can be considered accident-related.
  static const double advancedMinAccidentThreshold = 4.0;

  /// G-force interpretation bands.
  ///
  /// Machine mapping:
  /// < 4.0   => ignored
  /// 4.0-6.9 => low
  /// 7.0-9.9 => medium
  /// 10-11.9 => high
  /// >= 12.0 => critical
  static const double advancedMinorBumpThreshold = 4.0;
  static const double advancedMinorBumpMaxThreshold = 6.99;

  static const double advancedModerateCollisionThreshold = 7.0;
  static const double advancedModerateCollisionMaxThreshold = 9.99;

  static const double advancedHighCollisionThreshold = 10.0;
  static const double advancedHighCollisionMaxThreshold = 11.99;

  static const double advancedCriticalImpactThreshold = 12.0;

  /// Advanced sensitivity thresholds.
  static const double advancedImpactThresholdHigh = 4.0;
  static const double advancedImpactThresholdMedium = 4.6;
  static const double advancedImpactThresholdLow = 5.5;

  static const double advancedRotationThresholdHigh = 2.8;
  static const double advancedRotationThresholdMedium = 3.5;
  static const double advancedRotationThresholdLow = 4.5;

  /// Severe impact opens an event window immediately.
  /// Final severity still depends on full event analysis.
  static const double advancedSevereImpactThresholdHigh = 10.0;
  static const double advancedSevereImpactThresholdMedium = 10.5;
  static const double advancedSevereImpactThresholdLow = 11.0;

  static const int advancedMinImpactSamplesHigh = 2;
  static const int advancedMinImpactSamplesMedium = 2;
  static const int advancedMinImpactSamplesLow = 3;

  static const int advancedMinRotationSamplesHigh = 1;
  static const int advancedMinRotationSamplesMedium = 2;
  static const int advancedMinRotationSamplesLow = 2;

  static const int advancedDetectionCooldownSeconds = 15;

  // ==========================================
  // 🧪 ADVANCED EVENT WINDOW ENGINE
  // ==========================================

  static const int preImpactWindowMs = 2000;
  static const int impactWindowMs = 1000;
  static const int postImpactWindowMs = 3000;
  static const int totalEventWindowMs = 6000;

  // ==========================================
  // 🚗 ADVANCED GPS SPEED & MOTION THRESHOLDS
  // ==========================================

  static const double minSpeedDropKmh = 15.0;
  static const double criticalSpeedDropKmh = 40.0;
  static const double minActiveSpeedKmh = 5.0;
  static const double maxReasonableSpeedKmh = 200.0;

  // ==========================================
  // 🛑 ADVANCED POST-IMPACT STILLNESS
  // ==========================================

  static const double stillnessThresholdG = 0.3;
  static const int stillnessDurationMs = 2000;
  static const double microMovementThresholdG = 0.15;

  // ==========================================
  // ⚖️ ADVANCED MULTI-FACTOR WEIGHTED SCORING
  // ==========================================

  /// These weights must sum to 1.0.
  static const double weightImpact = 0.30;
  static const double weightRotation = 0.20;
  static const double weightSpeed = 0.25;
  static const double weightStillness = 0.15;
  static const double weightContext = 0.10;

  /// General confidence reference used by DetectionConfig/legacy helpers.
  /// Final AccidentDetectionEngine has stricter per-severity rules.
  static const double minConfidenceThreshold = 45.0;

  // ==========================================
  // 🌍 ADVANCED TRIP CONTEXT FACTORS
  // ==========================================

  static const double cityHighwaySpeedThresholdKmh = 80.0;
  static const double highwayContextMultiplier = 1.2;
  static const double cityContextMultiplier = 0.9;

  // ==========================================
  // 📊 ADVANCED SENSOR FUSION CONFIGURATION
  // ==========================================

  static const int maxSensorTimeDeltaMs = 100;
  static const int sensorBufferSize = 100;
  static const int targetSampleRateHz = 50;

  // ==========================================
  // 🎚️ SENSITIVITY HELPERS
  // ==========================================

  static const String sensitivityHigh = 'high';
  static const String sensitivityMedium = 'medium';
  static const String sensitivityLow = 'low';

  static String normalizeSensitivity(String sensitivity) {
    final normalized = sensitivity.trim().toLowerCase();

    switch (normalized) {
      case sensitivityHigh:
        return sensitivityHigh;
      case sensitivityLow:
        return sensitivityLow;
      case sensitivityMedium:
      default:
        return sensitivityMedium;
    }
  }

  static bool isKnownSensitivity(String sensitivity) {
    final normalized = sensitivity.trim().toLowerCase();

    return normalized == sensitivityHigh ||
        normalized == sensitivityMedium ||
        normalized == sensitivityLow;
  }

  static double mapUISensitivityToGForce(double uiValue) {
    final normalized = uiValue.clamp(0.0, 100.0).toDouble();
    return 8.0 - ((normalized / 100.0) * 6.0);
  }

  static double mapGForceToUISensitivity(double gForce) {
    final normalized = gForce.clamp(2.0, 8.0).toDouble();
    return ((8.0 - normalized) / 6.0) * 100.0;
  }

  // ==========================================
  // 🎯 CURRENT HELPER METHODS
  // ==========================================

  static double getImpactThreshold(String sensitivity) {
    switch (normalizeSensitivity(sensitivity)) {
      case sensitivityHigh:
        return impactThresholdHigh;
      case sensitivityLow:
        return impactThresholdLow;
      case sensitivityMedium:
      default:
        return impactThresholdMedium;
    }
  }

  static double getRotationThreshold(String sensitivity) {
    switch (normalizeSensitivity(sensitivity)) {
      case sensitivityHigh:
        return rotationThresholdHigh;
      case sensitivityLow:
        return rotationThresholdLow;
      case sensitivityMedium:
      default:
        return rotationThresholdMedium;
    }
  }

  static double getSevereImpactThreshold(String sensitivity) {
    switch (normalizeSensitivity(sensitivity)) {
      case sensitivityHigh:
        return severeImpactThresholdHigh;
      case sensitivityLow:
        return severeImpactThresholdLow;
      case sensitivityMedium:
      default:
        return severeImpactThresholdMedium;
    }
  }

  static int getMinImpactSamples(String sensitivity) {
    switch (normalizeSensitivity(sensitivity)) {
      case sensitivityHigh:
        return minImpactSamplesHigh;
      case sensitivityLow:
        return minImpactSamplesLow;
      case sensitivityMedium:
      default:
        return minImpactSamplesMedium;
    }
  }

  static int getMinRotationSamples(String sensitivity) {
    switch (normalizeSensitivity(sensitivity)) {
      case sensitivityHigh:
        return minRotationSamplesHigh;
      case sensitivityLow:
        return minRotationSamplesLow;
      case sensitivityMedium:
      default:
        return minRotationSamplesMedium;
    }
  }

  static int getCountdownDuration(double severityScore) {
    final safeScore = _safeScore(severityScore);

    if (safeScore >= severityScoreCritical) {
      return countdownCriticalSeconds;
    }

    if (safeScore >= severityScoreMedium) {
      return countdownModerateSeconds;
    }

    return countdownLowSeconds;
  }

  static int getCountdownDurationForSeverityLevel(String severityLevel) {
    switch (normalizeSeverityLevel(severityLevel)) {
      case severityCritical:
        return countdownCriticalSeconds;
      case severityHigh:
      case severityMedium:
        return countdownModerateSeconds;
      case severityLow:
      case severityIgnored:
      default:
        return countdownLowSeconds;
    }
  }

  static bool isCriticalSeverity(double severityScore) {
    return _safeScore(severityScore) >= severityScoreCritical;
  }

  static bool isHighSeverity(double severityScore) {
    final safeScore = _safeScore(severityScore);

    return safeScore >= severityScoreHigh && safeScore < severityScoreCritical;
  }

  static bool isMediumSeverity(double severityScore) {
    final safeScore = _safeScore(severityScore);

    return safeScore >= severityScoreMedium && safeScore < severityScoreHigh;
  }

  static bool isLowSeverity(double severityScore) {
    return _safeScore(severityScore) < severityScoreMedium;
  }

  static String severityLevelFromScore(double severityScore) {
    final safeScore = _safeScore(severityScore);

    if (safeScore >= severityScoreCritical) return severityCritical;
    if (safeScore >= severityScoreHigh) return severityHigh;
    if (safeScore >= severityScoreMedium) return severityMedium;
    return severityLow;
  }

  // ==========================================
  // 🎯 ADVANCED HELPER METHODS
  // ==========================================

  static double getAdvancedImpactThreshold(String sensitivity) {
    switch (normalizeSensitivity(sensitivity)) {
      case sensitivityHigh:
        return advancedImpactThresholdHigh;
      case sensitivityLow:
        return advancedImpactThresholdLow;
      case sensitivityMedium:
      default:
        return advancedImpactThresholdMedium;
    }
  }

  static double getAdvancedRotationThreshold(String sensitivity) {
    switch (normalizeSensitivity(sensitivity)) {
      case sensitivityHigh:
        return advancedRotationThresholdHigh;
      case sensitivityLow:
        return advancedRotationThresholdLow;
      case sensitivityMedium:
      default:
        return advancedRotationThresholdMedium;
    }
  }

  static double getAdvancedSevereImpactThreshold(String sensitivity) {
    switch (normalizeSensitivity(sensitivity)) {
      case sensitivityHigh:
        return advancedSevereImpactThresholdHigh;
      case sensitivityLow:
        return advancedSevereImpactThresholdLow;
      case sensitivityMedium:
      default:
        return advancedSevereImpactThresholdMedium;
    }
  }

  static int getAdvancedMinImpactSamples(String sensitivity) {
    switch (normalizeSensitivity(sensitivity)) {
      case sensitivityHigh:
        return advancedMinImpactSamplesHigh;
      case sensitivityLow:
        return advancedMinImpactSamplesLow;
      case sensitivityMedium:
      default:
        return advancedMinImpactSamplesMedium;
    }
  }

  static int getAdvancedMinRotationSamples(String sensitivity) {
    switch (normalizeSensitivity(sensitivity)) {
      case sensitivityHigh:
        return advancedMinRotationSamplesHigh;
      case sensitivityLow:
        return advancedMinRotationSamplesLow;
      case sensitivityMedium:
      default:
        return advancedMinRotationSamplesMedium;
    }
  }

  static double getContextMultiplier(double speedKmh) {
    if (!isValidSpeed(speedKmh)) return cityContextMultiplier;

    if (speedKmh >= cityHighwaySpeedThresholdKmh) {
      return highwayContextMultiplier;
    }

    return cityContextMultiplier;
  }

  static bool isValidSpeed(double speedKmh) {
    return !speedKmh.isNaN &&
        !speedKmh.isInfinite &&
        speedKmh >= 0.0 &&
        speedKmh <= maxReasonableSpeedKmh;
  }

  static bool isSignificantSpeedDrop(double speedDelta) {
    return !speedDelta.isNaN &&
        !speedDelta.isInfinite &&
        speedDelta >= minSpeedDropKmh;
  }

  static bool isCriticalSpeedDrop(double speedDelta) {
    return !speedDelta.isNaN &&
        !speedDelta.isInfinite &&
        speedDelta >= criticalSpeedDropKmh;
  }

  static bool isStillness(double gForce) {
    return !gForce.isNaN &&
        !gForce.isInfinite &&
        gForce >= 0.0 &&
        gForce <= stillnessThresholdG;
  }

  static bool isMicroMovement(double gForce) {
    return !gForce.isNaN &&
        !gForce.isInfinite &&
        gForce > microMovementThresholdG &&
        gForce <= stillnessThresholdG;
  }

  /// Machine-safe advanced severity.
  static String mapAdvancedGForceToSeverityLevel(double gForce) {
    if (gForce.isNaN ||
        gForce.isInfinite ||
        gForce < advancedMinAccidentThreshold) {
      return severityIgnored;
    }

    if (isAdvancedMinorBump(gForce)) {
      return severityLow;
    }

    if (isAdvancedModerateCollision(gForce)) {
      return severityMedium;
    }

    if (isAdvancedHighCollision(gForce)) {
      return severityHigh;
    }

    return severityCritical;
  }

  static String mapAdvancedGForceToSeverityDisplayEnglish(double gForce) {
    switch (mapAdvancedGForceToSeverityLevel(gForce)) {
      case severityLow:
        return 'Minor impact';
      case severityMedium:
        return 'Moderate collision';
      case severityHigh:
        return 'Severe collision';
      case severityCritical:
        return 'Critical impact';
      case severityIgnored:
      default:
        return 'Ignored';
    }
  }

  static String mapAdvancedGForceToSeverityLevelArabic(double gForce) {
    switch (mapAdvancedGForceToSeverityLevel(gForce)) {
      case severityLow:
        return 'اصطدام خفيف';
      case severityMedium:
        return 'اصطدام متوسط';
      case severityHigh:
        return 'اصطدام خطير';
      case severityCritical:
        return 'اصطدام حرج';
      case severityIgnored:
      default:
        return 'تم التجاهل';
    }
  }

  static bool shouldIgnoreAdvancedGForce(double gForce) {
    return gForce.isNaN ||
        gForce.isInfinite ||
        gForce < advancedMinAccidentThreshold;
  }

  static bool isAdvancedMinorBump(double gForce) {
    return !gForce.isNaN &&
        !gForce.isInfinite &&
        gForce >= advancedMinorBumpThreshold &&
        gForce <= advancedMinorBumpMaxThreshold;
  }

  static bool isAdvancedModerateCollision(double gForce) {
    return !gForce.isNaN &&
        !gForce.isInfinite &&
        gForce >= advancedModerateCollisionThreshold &&
        gForce <= advancedModerateCollisionMaxThreshold;
  }

  static bool isAdvancedHighCollision(double gForce) {
    return !gForce.isNaN &&
        !gForce.isInfinite &&
        gForce >= advancedHighCollisionThreshold &&
        gForce <= advancedHighCollisionMaxThreshold;
  }

  static bool isAdvancedCriticalImpact(double gForce) {
    return !gForce.isNaN &&
        !gForce.isInfinite &&
        gForce >= advancedCriticalImpactThreshold;
  }

  static String normalizeSeverityLevel(String severityLevel) {
    final normalized = severityLevel.trim().toLowerCase();

    switch (normalized) {
      case severityCritical:
        return severityCritical;
      case severityHigh:
        return severityHigh;
      case severityMedium:
        return severityMedium;
      case severityLow:
        return severityLow;
      case severityIgnored:
        return severityIgnored;

      // Backward compatibility with old display labels.
      case 'critical impact':
      case 'severe collision':
      case 'حادث حرج':
      case 'اصطدام حرج':
        return severityCritical;

      case 'moderate collision':
      case 'اصطدام متوسط':
        return severityMedium;

      case 'minor bump':
      case 'minor impact':
      case 'اصطدام خفيف':
        return severityLow;

      case 'تم التجاهل':
        return severityIgnored;

      default:
        return severityMedium;
    }
  }

  static bool isAccidentSeverityLevel(String severityLevel) {
    final normalized = normalizeSeverityLevel(severityLevel);

    return normalized == severityMedium ||
        normalized == severityHigh ||
        normalized == severityCritical;
  }

  static String severityDisplayArabic(String severityLevel) {
    switch (normalizeSeverityLevel(severityLevel)) {
      case severityCritical:
        return 'حرج جداً';
      case severityHigh:
        return 'خطير';
      case severityMedium:
        return 'متوسط';
      case severityLow:
        return 'خفيف';
      case severityIgnored:
      default:
        return 'تم التجاهل';
    }
  }

  static String severityDisplayEnglish(String severityLevel) {
    switch (normalizeSeverityLevel(severityLevel)) {
      case severityCritical:
        return 'Critical';
      case severityHigh:
        return 'High';
      case severityMedium:
        return 'Medium';
      case severityLow:
        return 'Low';
      case severityIgnored:
      default:
        return 'Ignored';
    }
  }

  static bool get advancedWeightsAreValid {
    final sum =
        weightImpact +
        weightRotation +
        weightSpeed +
        weightStillness +
        weightContext;

    return (sum - 1.0).abs() < 0.0001 &&
        _isWeight(weightImpact) &&
        _isWeight(weightRotation) &&
        _isWeight(weightSpeed) &&
        _isWeight(weightStillness) &&
        _isWeight(weightContext);
  }

  static bool _isWeight(double value) {
    return !value.isNaN && !value.isInfinite && value >= 0.0 && value <= 1.0;
  }

  static double _safeScore(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    return value.clamp(0.0, 100.0).toDouble();
  }
}
