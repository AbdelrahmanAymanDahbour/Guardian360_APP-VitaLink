import '../../../core/constants/app_thresholds.dart';
import 'sensor_fusion_frame.dart';
import 'event_window.dart';

/// ==========================================
/// 🎯 Detection Event Model
/// ==========================================
/// Complete accident detection event with all analysis data.
/// This is the final output of the advanced detection engine.
///
/// This model belongs to the NEW advanced architecture:
/// SensorFusionService -> EventWindowAnalyzer -> PostImpactMonitor -> DetectionEngine
class DetectionEvent {
  /// Unique identifier for this event
  final String eventId;

  /// Timestamp when the event was detected
  final DateTime detectedAt;

  /// The complete event window with all sensor data
  final EventWindow eventWindow;

  /// The specific frame that triggered the detection
  final SensorFusionFrame triggerFrame;

  // ==========================================
  // 📊 Detection Scores (0-100)
  // ==========================================

  /// Impact score
  final double impactScore;

  /// Rotation score
  final double rotationScore;

  /// Speed delta score
  final double speedScore;

  /// Stillness score
  final double stillnessScore;

  /// Trip / road context score
  final double contextScore;

  /// Final weighted confidence score (0-100)
  final double confidenceScore;

  // ==========================================
  // 🎯 Detection Classification
  // ==========================================

  /// Whether this is classified as an accident
  final bool isAccident;

  /// Severity level: 'critical', 'high', 'medium', 'low', or 'ignored'
  final String severityLevel;

  /// Recommended action: 'emergency', 'alert', 'monitor', 'ignore'
  final String recommendedAction;

  // ==========================================
  // 📍 Location & Context
  // ==========================================

  final double? latitude;
  final double? longitude;

  /// Speed at trigger moment
  final double speedAtImpact;

  /// Average speed before impact
  final double speedBeforeImpact;

  /// Average speed after impact
  final double speedAfterImpact;

  /// Whether the context is highway-like
  final bool isHighwayContext;

  // ==========================================
  // 🔍 Detection Metadata
  // ==========================================

  /// Detection sensitivity level used: 'high', 'medium', 'low'
  final String sensitivityLevel;

  /// Whether this was auto-detected or manually triggered
  final bool isAutoDetected;

  /// Additional notes / flags / diagnostics
  final Map<String, dynamic> metadata;

  const DetectionEvent({
    required this.eventId,
    required this.detectedAt,
    required this.eventWindow,
    required this.triggerFrame,
    required this.impactScore,
    required this.rotationScore,
    required this.speedScore,
    required this.stillnessScore,
    required this.contextScore,
    required this.confidenceScore,
    required this.isAccident,
    required this.severityLevel,
    required this.recommendedAction,
    this.latitude,
    this.longitude,
    required this.speedAtImpact,
    required this.speedBeforeImpact,
    required this.speedAfterImpact,
    required this.isHighwayContext,
    required this.sensitivityLevel,
    this.isAutoDetected = true,
    this.metadata = const {},
  });

  /// Create a non-accident / false-positive event
  factory DetectionEvent.falsePositive({
    required SensorFusionFrame triggerFrame,
    required String sensitivityLevel,
    String reason = 'below_threshold',
  }) {
    return DetectionEvent(
      eventId: DateTime.now().millisecondsSinceEpoch.toString(),
      detectedAt: DateTime.now(),
      eventWindow: EventWindow.empty(),
      triggerFrame: triggerFrame,
      impactScore: 0.0,
      rotationScore: 0.0,
      speedScore: 0.0,
      stillnessScore: 0.0,
      contextScore: 0.0,
      confidenceScore: 0.0,
      isAccident: false,
      severityLevel: 'ignored',
      recommendedAction: 'ignore',
      latitude: triggerFrame.latitude,
      longitude: triggerFrame.longitude,
      speedAtImpact: triggerFrame.speedKmh,
      speedBeforeImpact: triggerFrame.speedKmh,
      speedAfterImpact: triggerFrame.speedKmh,
      isHighwayContext: false,
      sensitivityLevel: sensitivityLevel,
      metadata: {'reason': reason},
    );
  }

  // ==========================================
  // 📈 Analysis Helpers
  // ==========================================

  /// Total speed drop from before to after impact
  double get totalSpeedDrop {
    return (speedBeforeImpact - speedAfterImpact).clamp(0.0, 300.0);
  }

  /// Whether this is a critical event
  bool get isCritical => severityLevel == 'critical';

  /// Whether this is a high severity event
  bool get isHighSeverity => severityLevel == 'high';

  /// Whether this is a medium severity event
  bool get isMediumSeverity => severityLevel == 'medium';

  /// Whether this is a low severity event
  bool get isLowSeverity => severityLevel == 'low';

  /// Whether this event is effectively ignored
  bool get isIgnored => severityLevel == 'ignored';

  /// Whether emergency response is recommended
  bool get requiresEmergencyResponse => recommendedAction == 'emergency';

  /// Whether alert flow (but not full emergency) is recommended
  bool get requiresAlertFlow => recommendedAction == 'alert';

  /// Whether monitor-only behavior is recommended
  bool get requiresMonitoringOnly => recommendedAction == 'monitor';

  /// Countdown duration in seconds based on severity
  int get countdownDurationSeconds {
    switch (severityLevel) {
      case 'critical':
        return AppThresholds.countdownCriticalSeconds;
      case 'high':
        return AppThresholds.countdownModerateSeconds;
      case 'medium':
        return AppThresholds.countdownModerateSeconds;
      case 'low':
        return AppThresholds.countdownLowSeconds;
      case 'ignored':
      default:
        return AppThresholds.countdownLowSeconds;
    }
  }

  /// A compact severity rank useful for comparisons
  int get severityRank {
    switch (severityLevel) {
      case 'critical':
        return 4;
      case 'high':
        return 3;
      case 'medium':
        return 2;
      case 'low':
        return 1;
      case 'ignored':
      default:
        return 0;
    }
  }

  /// Whether GPS coordinates are available
  bool get hasLocation => latitude != null && longitude != null;

  /// Whether the event carries meaningful confidence
  bool get hasMeaningfulConfidence => confidenceScore > 0.0;

  /// Human-readable summary
  String get summary {
    if (!isAccident) {
      return 'No accident detected '
          '(Confidence: ${confidenceScore.toStringAsFixed(1)}%)';
    }

    return 'Accident detected - $severityLevel severity '
        '(Confidence: ${confidenceScore.toStringAsFixed(1)}%, '
        'Impact: ${impactScore.toStringAsFixed(1)}, '
        'Rotation: ${rotationScore.toStringAsFixed(1)}, '
        'Speed drop: ${totalSpeedDrop.toStringAsFixed(1)} km/h)';
  }

  // ==========================================
  // 📦 Serialization
  // ==========================================

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'detectedAt': detectedAt.toIso8601String(),
      'isAccident': isAccident,
      'severityLevel': severityLevel,
      'recommendedAction': recommendedAction,
      'confidenceScore': confidenceScore,
      'impactScore': impactScore,
      'rotationScore': rotationScore,
      'speedScore': speedScore,
      'stillnessScore': stillnessScore,
      'contextScore': contextScore,
      'latitude': latitude,
      'longitude': longitude,
      'speedAtImpact': speedAtImpact,
      'speedBeforeImpact': speedBeforeImpact,
      'speedAfterImpact': speedAfterImpact,
      'totalSpeedDrop': totalSpeedDrop,
      'isHighwayContext': isHighwayContext,
      'sensitivityLevel': sensitivityLevel,
      'isAutoDetected': isAutoDetected,
      'triggerGForce': triggerFrame.gForce,
      'triggerRotation': triggerFrame.rotation,
      'windowTotalFrames': eventWindow.totalFrames,
      'windowDurationMs': eventWindow.windowDurationMs,
      'metadata': metadata,
    };
  }

  /// Useful for debugging and logs
  Map<String, dynamic> toDebugMap() {
    return {
      'eventId': eventId,
      'detectedAt': detectedAt.toIso8601String(),
      'severityLevel': severityLevel,
      'recommendedAction': recommendedAction,
      'isAccident': isAccident,
      'confidenceScore': confidenceScore,
      'impactScore': impactScore,
      'rotationScore': rotationScore,
      'speedScore': speedScore,
      'stillnessScore': stillnessScore,
      'contextScore': contextScore,
      'speedAtImpact': speedAtImpact,
      'speedBeforeImpact': speedBeforeImpact,
      'speedAfterImpact': speedAfterImpact,
      'totalSpeedDrop': totalSpeedDrop,
      'hasLocation': hasLocation,
      'isHighwayContext': isHighwayContext,
      'sensitivityLevel': sensitivityLevel,
      'isAutoDetected': isAutoDetected,
      'triggerFrame': triggerFrame.toString(),
      'eventWindow': eventWindow.toDebugMap(),
      'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'DetectionEvent('
        'id: $eventId, '
        'accident: $isAccident, '
        'severity: $severityLevel, '
        'action: $recommendedAction, '
        'confidence: ${confidenceScore.toStringAsFixed(1)}%, '
        'impact: ${impactScore.toStringAsFixed(1)}, '
        'rotation: ${rotationScore.toStringAsFixed(1)}, '
        'speed: ${speedScore.toStringAsFixed(1)}, '
        'stillness: ${stillnessScore.toStringAsFixed(1)}'
        ')';
  }
}
