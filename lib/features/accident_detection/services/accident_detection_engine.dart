import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_thresholds.dart';
import '../models/detection_config.dart';
import '../models/detection_event.dart';
import '../models/event_window.dart';
import '../models/sensor_fusion_frame.dart';
import 'event_window_analyzer.dart';
import 'post_impact_monitor.dart';
import 'sensor_fusion_service.dart';

/// ==========================================
/// 🧠 Accident Detection Engine - Guardian 360
/// ==========================================
/// Central orchestrator for the advanced accident detection pipeline.
///
/// Pipeline:
/// SensorFusionService
///   → EventWindowAnalyzer
///   → PostImpactMonitor
///   → DetectionEvent
///
/// Responsibilities:
/// - Start/stop sensor fusion.
/// - Decide when a raw frame is strong enough to open an event window.
/// - Build a full event after post-impact capture.
/// - Calculate normalized scores.
/// - Classify severity into machine-safe values:
///   low / medium / high / critical / ignored.
///
/// Not responsible for:
/// - Firebase writes.
/// - SOS countdown UI.
/// - Dashboard sync.
/// - Manual SOS.
/// - Notifications.
///
/// Final emergency reporting happens later:
/// AccidentDetectionEngine
///   → AccidentMonitorViewModel
///   → SOSViewModel
///   → FirebaseService.reportAccident()
class AccidentDetectionEngine {
  final SensorFusionService _fusionService;
  final EventWindowAnalyzer _windowAnalyzer;
  final PostImpactMonitor _impactMonitor;

  DetectionConfig _config;

  AccidentDetectionEngine({
    SensorFusionService? fusionService,
    EventWindowAnalyzer? windowAnalyzer,
    PostImpactMonitor? impactMonitor,
    DetectionConfig? config,
  }) : _fusionService = fusionService ?? SensorFusionService(),
       _windowAnalyzer = windowAnalyzer ?? EventWindowAnalyzer(),
       _impactMonitor = impactMonitor ?? PostImpactMonitor(),
       _config = _safeConfig(config);

  static const Duration _doubleHitWindow = Duration(milliseconds: 180);

  bool _isRunning = false;
  bool _isProcessingEvent = false;
  bool _isDisposed = false;

  DateTime? _lastDetectionTime;

  DateTime? _lastHighGForceTime;
  double _lastHighGForce = 0.0;

  StreamSubscription<SensorFusionFrame>? _fusionSubscription;
  void Function(DetectionEvent)? _onDetectionCallback;

  static DetectionConfig _safeConfig(DetectionConfig? config) {
    if (config != null && config.isStructurallyValid) {
      return config;
    }

    if (config != null) {
      debugPrint(
        '⚠️ AccidentDetectionEngine: Invalid config received, using medium config',
      );
    }

    return DetectionConfig.medium();
  }

  Future<void> startDetection({
    required void Function(DetectionEvent) onDetection,
    DetectionConfig? config,
  }) async {
    if (_isDisposed) {
      debugPrint('⚠️ AccidentDetectionEngine: start ignored after dispose');
      return;
    }

    if (_isRunning) {
      debugPrint('⚠️ AccidentDetectionEngine: Already running');
      return;
    }

    _config = _safeConfig(config ?? _config);
    _onDetectionCallback = onDetection;
    _isRunning = true;
    _isProcessingEvent = false;
    _lastDetectionTime = null;
    _resetTriggerDebounce();

    // Critical: keep all advanced components on the same config.
    _fusionService.updateConfig(_config);
    _windowAnalyzer.updateConfig(_config);
    _impactMonitor.updateConfig(_config);

    debugPrint('🧠 AccidentDetectionEngine: Starting advanced detection...');
    debugPrint('   Config: $_config');

    try {
      await _fusionService.startFusion(config: _config);

      if (_isDisposed) {
        await _fusionService.stopFusion();
        return;
      }

      _fusionSubscription = _fusionService.fusionStream.listen(
        _processSensorFrame,
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('❌ AccidentDetectionEngine: Fusion stream error - $error');
          debugPrintStack(stackTrace: stackTrace);
        },
        onDone: () {
          debugPrint('ℹ️ AccidentDetectionEngine: Fusion stream closed');
        },
        cancelOnError: false,
      );

      debugPrint('✅ AccidentDetectionEngine: Detection engine started');
    } catch (e, stackTrace) {
      debugPrint('❌ AccidentDetectionEngine: Failed to start - $e');
      debugPrintStack(stackTrace: stackTrace);

      _isRunning = false;
      _isProcessingEvent = false;
      _onDetectionCallback = null;
      _resetTriggerDebounce();

      rethrow;
    }
  }

  Future<void> stopDetection() async {
    if (!_isRunning && _fusionSubscription == null) return;

    debugPrint('🛑 AccidentDetectionEngine: Stopping detection engine...');

    try {
      await _fusionSubscription?.cancel();
    } catch (e, stackTrace) {
      debugPrint(
        '❌ AccidentDetectionEngine: Fusion subscription cancel failed - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      await _fusionService.stopFusion();
    } catch (e, stackTrace) {
      debugPrint('❌ AccidentDetectionEngine: Fusion service stop failed - $e');
      debugPrintStack(stackTrace: stackTrace);
    }

    _fusionSubscription = null;
    _isRunning = false;
    _isProcessingEvent = false;
    _onDetectionCallback = null;
    _lastDetectionTime = null;

    _resetTriggerDebounce();
    _windowAnalyzer.reset();
    _impactMonitor.reset();

    debugPrint('✅ AccidentDetectionEngine: Detection engine stopped');
  }

  void _processSensorFrame(SensorFusionFrame frame) {
    if (_isDisposed || !_isRunning) return;

    try {
      if (!frame.isStructurallyValid || !frame.hasValidSensorData) {
        debugPrint('⛔ AccidentDetectionEngine: Invalid frame ignored');
        return;
      }

      _windowAnalyzer.addFrame(frame);

      if (_windowAnalyzer.isCapturingPostImpact) {
        _impactMonitor.processFrame(frame);

        if (_windowAnalyzer.hasCompleteWindow() && !_isProcessingEvent) {
          _processCompleteEvent();
        }

        return;
      }

      if (_shouldTriggerDetection(frame)) {
        _triggerImpactDetection(frame);
      }
    } catch (e, stackTrace) {
      debugPrint('⚠️ AccidentDetectionEngine: Frame processing error - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  bool _shouldTriggerDetection(SensorFusionFrame frame) {
    if (_isInCooldown()) {
      debugPrint('⛔ AccidentDetectionEngine: Trigger blocked by cooldown');
      return false;
    }

    if (!frame.isStructurallyValid) {
      debugPrint(
        '⛔ AccidentDetectionEngine: Trigger blocked by structurally invalid frame',
      );
      return false;
    }

    if (!frame.hasValidSensorData) {
      debugPrint(
        '⛔ AccidentDetectionEngine: Trigger blocked by invalid sensor data',
      );
      return false;
    }

    final isLowSpeed = frame.speedKmh < _config.minActiveSpeedKmh;

    // Severe physical impact is allowed to open the event window.
    // Final severity is still decided later using full event analysis.
    if (frame.gForce >= _config.severeImpactThreshold) {
      debugPrint(
        '🚨 AccidentDetectionEngine: Immediate severe-impact trigger '
        '(gForce=${frame.gForce.toStringAsFixed(2)})',
      );
      return true;
    }

    // GPS speed-drop trigger should only be trusted when GPS data is available.
    if (frame.hasGPSData &&
        AppThresholds.isCriticalSpeedDrop(frame.speedDropKmh)) {
      debugPrint(
        '🚨 AccidentDetectionEngine: Immediate critical-speed-drop trigger '
        '(speedDrop=${frame.speedDropKmh.toStringAsFixed(1)} km/h)',
      );
      return true;
    }

    final lowSpeedImpactRotationSignal =
        frame.gForce >= _config.impactThreshold &&
        frame.rotation >= (_config.rotationThreshold * 0.80);

    final lowSpeedImpactSpeedSignal =
        frame.hasGPSData &&
        frame.gForce >= _config.impactThreshold &&
        AppThresholds.isSignificantSpeedDrop(frame.speedDropKmh);

    final lowSpeedStrongImpactOnlyThreshold =
        (_config.impactThreshold + _config.severeImpactThreshold) / 2.0;

    final lowSpeedStrongImpactOnlySignal =
        frame.gForce >= lowSpeedStrongImpactOnlyThreshold;

    final lowSpeedInvestigateSignal =
        lowSpeedImpactRotationSignal ||
        lowSpeedImpactSpeedSignal ||
        lowSpeedStrongImpactOnlySignal;

    if (isLowSpeed && !lowSpeedInvestigateSignal) {
      debugPrint(
        '📉 AccidentDetectionEngine: Trigger blocked by low speed '
        '(speed=${frame.speedKmh.toStringAsFixed(1)}, '
        'required=${_config.minActiveSpeedKmh.toStringAsFixed(1)}, '
        'gForce=${frame.gForce.toStringAsFixed(2)}, '
        'rotation=${frame.rotation.toStringAsFixed(2)})',
      );
      return false;
    }

    if (isLowSpeed && lowSpeedInvestigateSignal) {
      debugPrint(
        '🧪 AccidentDetectionEngine: Low-speed strong event allowed for analysis '
        '(gForce=${frame.gForce.toStringAsFixed(2)}, '
        'rotation=${frame.rotation.toStringAsFixed(2)}, '
        'speed=${frame.speedKmh.toStringAsFixed(1)})',
      );
      return true;
    }

    return _passesDoubleHitConfirmation(frame);
  }

  bool _passesDoubleHitConfirmation(SensorFusionFrame frame) {
    final now = frame.timestamp;

    if (frame.gForce < _config.impactThreshold) {
      _expireDoubleHitIfNeeded(now);
      return false;
    }

    final lastHighGForceTime = _lastHighGForceTime;

    if (lastHighGForceTime != null) {
      final delta = now.difference(lastHighGForceTime);

      if (delta <= _doubleHitWindow &&
          _lastHighGForce >= _config.impactThreshold) {
        debugPrint(
          '✅ AccidentDetectionEngine: Double-hit confirmation passed '
          '(delta=${delta.inMilliseconds}ms, '
          'currentG=${frame.gForce.toStringAsFixed(2)}, '
          'previousG=${_lastHighGForce.toStringAsFixed(2)})',
        );

        _resetTriggerDebounce();
        return true;
      }
    }

    _lastHighGForceTime = now;
    _lastHighGForce = frame.gForce;

    debugPrint(
      '🕒 AccidentDetectionEngine: Waiting for double-hit confirmation '
      '(gForce=${frame.gForce.toStringAsFixed(2)}, '
      'threshold=${_config.impactThreshold.toStringAsFixed(2)})',
    );

    return false;
  }

  void _expireDoubleHitIfNeeded(DateTime now) {
    final lastHighGForceTime = _lastHighGForceTime;

    if (lastHighGForceTime == null) return;

    final delta = now.difference(lastHighGForceTime);

    if (delta > _doubleHitWindow) {
      debugPrint(
        '⌛ AccidentDetectionEngine: Double-hit window expired '
        '(delta=${delta.inMilliseconds}ms)',
      );

      _resetTriggerDebounce();
    }
  }

  void _triggerImpactDetection(SensorFusionFrame triggerFrame) {
    if (_isDisposed || !_isRunning || _isProcessingEvent) return;

    debugPrint('💥 AccidentDetectionEngine: Impact trigger detected');
    debugPrint('   G-Force: ${triggerFrame.gForce.toStringAsFixed(2)}');
    debugPrint('   Rotation: ${triggerFrame.rotation.toStringAsFixed(2)}');
    debugPrint('   Speed: ${triggerFrame.speedKmh.toStringAsFixed(1)} km/h');
    debugPrint(
      '   Speed Drop: ${triggerFrame.speedDropKmh.toStringAsFixed(1)} km/h',
    );

    _lastDetectionTime = triggerFrame.timestamp;

    _windowAnalyzer.triggerImpactDetection(triggerFrame);
    _impactMonitor.startMonitoring();
  }

  void _processCompleteEvent() {
    if (_isDisposed || !_isRunning) return;

    _isProcessingEvent = true;

    try {
      debugPrint('📊 AccidentDetectionEngine: Processing complete event...');

      final eventWindow = _windowAnalyzer.getEventWindow();
      if (eventWindow == null) {
        debugPrint('⚠️ AccidentDetectionEngine: No event window available');
        _resetDetection();
        return;
      }

      final triggerFrame = _windowAnalyzer.triggerFrame;
      if (triggerFrame == null) {
        debugPrint('⚠️ AccidentDetectionEngine: No trigger frame available');
        _resetDetection();
        return;
      }

      final scores = _calculateWeightedScores(eventWindow, triggerFrame);
      final rawConfidence = _calculateConfidenceScore(scores);
      final adjustedConfidence = _applyFalsePositiveReduction(
        rawConfidence,
        scores,
        eventWindow,
        triggerFrame,
      );

      final detectionEvent = _classifyEvent(
        adjustedConfidence,
        scores,
        eventWindow,
        triggerFrame,
      );

      debugPrint('🎯 AccidentDetectionEngine: Detection complete');
      debugPrint('   Raw Confidence: ${rawConfidence.toStringAsFixed(1)}%');
      debugPrint(
        '   Final Confidence: ${adjustedConfidence.toStringAsFixed(1)}%',
      );
      debugPrint('   Severity: ${detectionEvent.severityLevel}');
      debugPrint('   Is Accident: ${detectionEvent.isAccident}');
      debugPrint('   Action: ${detectionEvent.recommendedAction}');

      _onDetectionCallback?.call(detectionEvent);
      _resetDetection();
    } catch (e, stackTrace) {
      debugPrint('❌ AccidentDetectionEngine: Event processing error - $e');
      debugPrintStack(stackTrace: stackTrace);
      _resetDetection();
    }
  }

  Map<String, double> _calculateWeightedScores(
    EventWindow window,
    SensorFusionFrame triggerFrame,
  ) {
    final impactScore = _calculateImpactScore(window);
    final rotationScore = _calculateRotationScore(window);
    final speedScore = _calculateSpeedScore(window);
    final stillnessScore = _calculateStillnessScore();
    final contextScore = _calculateContextScore(triggerFrame, window);

    debugPrint('📊 Weighted Scores:');
    debugPrint('   Impact: ${impactScore.toStringAsFixed(1)}');
    debugPrint('   Rotation: ${rotationScore.toStringAsFixed(1)}');
    debugPrint('   Speed: ${speedScore.toStringAsFixed(1)}');
    debugPrint('   Stillness: ${stillnessScore.toStringAsFixed(1)}');
    debugPrint('   Context: ${contextScore.toStringAsFixed(1)}');

    return {
      'impact': impactScore,
      'rotation': rotationScore,
      'speed': speedScore,
      'stillness': stillnessScore,
      'context': contextScore,
    };
  }

  double _calculateImpactScore(EventWindow window) {
    final peakGForce = _safeNumber(window.impactPeakGForce);
    final avgGForce = _safeNumber(window.impactAverageGForce);

    final range = (_config.severeImpactThreshold - _config.impactThreshold)
        .abs()
        .clamp(0.1, 1000.0);

    final peakNormalized = ((peakGForce - _config.impactThreshold) / range)
        .clamp(0.0, 1.0);

    final avgNormalized = ((avgGForce - _config.impactThreshold) / range).clamp(
      0.0,
      1.0,
    );

    final score = (peakNormalized * 0.75) + (avgNormalized * 0.25);
    return (score * 100).clamp(0.0, 100.0);
  }

  double _calculateRotationScore(EventWindow window) {
    final peakRotation = _safeNumber(window.impactPeakRotation);
    final avgRotation = _safeNumber(window.impactAverageRotation);

    final peakNormalized = (peakRotation / (_config.rotationThreshold * 2.0))
        .clamp(0.0, 1.0);

    final avgNormalized = (avgRotation / (_config.rotationThreshold * 1.6))
        .clamp(0.0, 1.0);

    final score = (peakNormalized * 0.65) + (avgNormalized * 0.35);
    return (score * 100).clamp(0.0, 100.0);
  }

  double _calculateSpeedScore(EventWindow window) {
    final peakSpeedDrop = _safeNumber(window.impactMaxSpeedDrop);
    final averageImpactDrop = _safeNumber(window.impactAverageSpeedDrop);
    final totalSpeedDrop = _safeNumber(window.totalBeforeAfterSpeedDrop);

    final peakDropNormalized = (peakSpeedDrop / _config.criticalSpeedDropKmh)
        .clamp(0.0, 1.0);

    final sustainedDropNormalized =
        (averageImpactDrop / _config.minSpeedDropKmh).clamp(0.0, 1.0);

    final totalDropNormalized = (totalSpeedDrop / _config.criticalSpeedDropKmh)
        .clamp(0.0, 1.0);

    final score =
        (peakDropNormalized * 0.45) +
        (totalDropNormalized * 0.35) +
        (sustainedDropNormalized * 0.20);

    return (score * 100).clamp(0.0, 100.0);
  }

  double _calculateStillnessScore() {
    final stillnessConfidence = _safeNumber(
      _impactMonitor.getStillnessConfidence(),
    );

    final confirmedStillness = _impactMonitor.hasConfirmedStillness();

    final score = confirmedStillness
        ? stillnessConfidence * 1.15
        : stillnessConfidence;

    return score.clamp(0.0, 100.0);
  }

  double _calculateContextScore(
    SensorFusionFrame triggerFrame,
    EventWindow window,
  ) {
    var score = 20.0;

    final isHighway =
        triggerFrame.speedKmh >= _config.cityHighwaySpeedThresholdKmh;

    if (isHighway) {
      score += 20.0;
    }

    if (triggerFrame.hasGPSData) {
      score += 15.0;
    }

    if (window.hasPreImpactDeceleration) {
      score += 10.0;
    }

    if (window.preImpactAverageSpeed >= _config.minActiveSpeedKmh) {
      score += 10.0;
    }

    if (triggerFrame.hasUsableGPSAccuracy) {
      score += 10.0;
    }

    return score.clamp(0.0, 100.0);
  }

  double _calculateConfidenceScore(Map<String, double> scores) {
    final weightedScore =
        (scores['impact']! * _config.weightImpact) +
        (scores['rotation']! * _config.weightRotation) +
        (scores['speed']! * _config.weightSpeed) +
        (scores['stillness']! * _config.weightStillness) +
        (scores['context']! * _config.weightContext);

    return weightedScore.clamp(0.0, 100.0);
  }

  double _applyFalsePositiveReduction(
    double confidenceScore,
    Map<String, double> scores,
    EventWindow window,
    SensorFusionFrame triggerFrame,
  ) {
    var adjustedScore = confidenceScore;
    final adjustments = <String>[];

    final isLowSpeed = triggerFrame.speedKmh < _config.minActiveSpeedKmh;

    final hasLowSpeedCorroboration = _hasLowSpeedCorroboration(
      scores,
      window.impactPeakGForce,
    );

    if (scores['stillness']! < 30.0) {
      adjustedScore -= 8.0;
      adjustments.add('Low stillness (-8)');
    }

    if (scores['speed']! < 20.0) {
      adjustedScore -= 6.0;
      adjustments.add('No meaningful speed drop (-6)');
    }

    if (_impactMonitor.hasSignificantMovement()) {
      adjustedScore -= 10.0;
      adjustments.add('Significant movement after impact (-10)');
    }

    if (scores['impact']! < 35.0 && scores['rotation']! < 25.0) {
      adjustedScore -= 8.0;
      adjustments.add('Low impact + low rotation (-8)');
    }

    if (window.postImpactAverageSpeed > _config.minActiveSpeedKmh * 2) {
      adjustedScore -= 12.0;
      adjustments.add('Normal post-impact speed (-12)');
    }

    final impactRotationGap = (scores['impact']! - scores['rotation']!).abs();

    if (impactRotationGap >= 55.0 &&
        scores['impact']! < 70.0 &&
        scores['rotation']! < 70.0) {
      adjustedScore -= 5.0;
      adjustments.add('Impact/rotation imbalance (-5)');
    }

    final weakEvent =
        scores['impact']! < 30.0 &&
        scores['rotation']! < 25.0 &&
        scores['speed']! < 20.0;

    if (weakEvent) {
      adjustedScore -= 10.0;
      adjustments.add('Weak multi-factor support (-10)');
    }

    if (isLowSpeed && !hasLowSpeedCorroboration) {
      adjustedScore -= 18.0;
      adjustments.add('Low-speed event lacks corroboration (-18)');
    }

    if (_impactMonitor.hasConfirmedStillness() && scores['impact']! > 60.0) {
      adjustedScore += 15.0;
      adjustments.add('Confirmed stillness + strong impact (+15)');
    }

    if (scores['impact']! >= 70.0 && scores['rotation']! >= 45.0) {
      adjustedScore += 8.0;
      adjustments.add('Strong impact + rotation signature (+8)');
    }

    if (adjustments.isNotEmpty) {
      debugPrint('🛡️ False Positive Reduction:');

      for (final entry in adjustments) {
        debugPrint('   - $entry');
      }

      debugPrint('   Before: ${confidenceScore.toStringAsFixed(1)}%');
      debugPrint('   After : ${adjustedScore.toStringAsFixed(1)}%');
    }

    return adjustedScore.clamp(0.0, 100.0);
  }

  DetectionEvent _classifyEvent(
    double confidenceScore,
    Map<String, double> scores,
    EventWindow window,
    SensorFusionFrame triggerFrame,
  ) {
    final peakGForce = _safeNumber(window.impactPeakGForce);
    final severityIndex = _calculateSeverityIndex(confidenceScore, scores);

    final severityLevel = _resolveSeverityLevel(
      peakGForce,
      severityIndex,
      scores,
      triggerFrame,
      confidenceScore,
    );

    final recommendedAction = _recommendedActionForSeverity(severityLevel);
    final isAccident = _isSeverityAccident(
      severityLevel,
      confidenceScore,
      triggerFrame,
      scores,
      peakGForce,
    );

    final isHighway =
        triggerFrame.speedKmh >= _config.cityHighwaySpeedThresholdKmh;

    return DetectionEvent(
      eventId: _createEventId(triggerFrame),
      detectedAt: DateTime.now(),
      eventWindow: window,
      triggerFrame: triggerFrame,
      impactScore: scores['impact']!,
      rotationScore: scores['rotation']!,
      speedScore: scores['speed']!,
      stillnessScore: scores['stillness']!,
      contextScore: scores['context']!,
      confidenceScore: confidenceScore.clamp(0.0, 100.0),
      isAccident: isAccident,
      severityLevel: severityLevel,
      recommendedAction: recommendedAction,
      latitude: triggerFrame.latitude,
      longitude: triggerFrame.longitude,
      speedAtImpact: triggerFrame.speedKmh,
      speedBeforeImpact: window.preImpactAverageSpeed,
      speedAfterImpact: window.postImpactAverageSpeed,
      isHighwayContext: isHighway,
      sensitivityLevel: _config.sensitivityLevel,
      metadata: {
        'windowFrames': window.totalFrames,
        'stillnessDurationMs': _impactMonitor.stillnessDurationMs,
        'movementDurationMs': _impactMonitor.movementDurationMs,
        'peakGForce': window.impactPeakGForce,
        'peakRotation': window.impactPeakRotation,
        'severityIndex': severityIndex,
        'rawScores': scores,
        'debugWindow': window.toDebugMap(),
        'debugMonitor': _impactMonitor.getAnalysis(),
      },
    );
  }

  double _calculateSeverityIndex(
    double confidenceScore,
    Map<String, double> scores,
  ) {
    final fusedSeverity =
        (scores['impact']! * 0.45) +
        (scores['rotation']! * 0.25) +
        (scores['speed']! * 0.12) +
        (scores['stillness']! * 0.10) +
        (scores['context']! * 0.08);

    return ((fusedSeverity * 0.70) + (confidenceScore * 0.30)).clamp(
      0.0,
      100.0,
    );
  }

  String _resolveSeverityLevel(
    double peakGForce,
    double severityIndex,
    Map<String, double> scores,
    SensorFusionFrame triggerFrame,
    double confidenceScore,
  ) {
    final isLowSpeed = triggerFrame.speedKmh < _config.minActiveSpeedKmh;
    final hasSevereImpact = peakGForce >= _config.severeImpactThreshold;

    final hasStrongImpact = scores['impact']! >= 55.0;
    final hasStrongRotation = scores['rotation']! >= 45.0;

    final hasStrongImpactRotationSignature =
        scores['impact']! >= 50.0 && scores['rotation']! >= 40.0;

    final hasMeaningfulImpactOrRotation =
        scores['impact']! >= 30.0 || scores['rotation']! >= 25.0;

    final hasLowSpeedCorroboration = _hasLowSpeedCorroboration(
      scores,
      peakGForce,
    );

    if (peakGForce < 3.0 && !hasMeaningfulImpactOrRotation) {
      return 'ignored';
    }

    if ((peakGForce > AppThresholds.advancedCriticalImpactThreshold &&
            (severityIndex >= 65.0 ||
                hasStrongImpactRotationSignature ||
                scores['speed']! >= 35.0 ||
                scores['stillness']! >= 50.0)) ||
        severityIndex >= 85.0) {
      return 'critical';
    }

    if (isLowSpeed && !hasSevereImpact && !hasLowSpeedCorroboration) {
      if (hasMeaningfulImpactOrRotation || severityIndex >= 20.0) {
        return 'low';
      }

      return 'ignored';
    }

    if (severityIndex >= 60.0 ||
        hasStrongImpactRotationSignature ||
        (hasSevereImpact && (hasStrongImpact || hasStrongRotation))) {
      return 'high';
    }

    if (severityIndex >= 35.0 || hasStrongImpact || hasStrongRotation) {
      return 'medium';
    }

    if (hasMeaningfulImpactOrRotation || severityIndex >= 20.0) {
      return 'low';
    }

    return 'ignored';
  }

  String _recommendedActionForSeverity(String severityLevel) {
    switch (severityLevel) {
      case 'critical':
        return 'emergency';
      case 'high':
      case 'medium':
        return 'alert';
      case 'low':
        return 'monitor';
      default:
        return 'ignore';
    }
  }

  bool _isSeverityAccident(
    String severityLevel,
    double confidenceScore,
    SensorFusionFrame triggerFrame,
    Map<String, double> scores,
    double peakGForce,
  ) {
    final isLowSpeed = triggerFrame.speedKmh < _config.minActiveSpeedKmh;
    final hasLowSpeedCorroboration = _hasLowSpeedCorroboration(
      scores,
      peakGForce,
    );

    final hasStrongImpactRotationSignature =
        scores['impact']! >= 50.0 && scores['rotation']! >= 40.0;

    if (hasStrongImpactRotationSignature) {
      return true;
    }

    switch (severityLevel) {
      case 'critical':
        return true;

      case 'high':
        if (isLowSpeed) {
          return hasLowSpeedCorroboration && confidenceScore >= 45.0;
        }

        return confidenceScore >= 45.0 ||
            peakGForce >= _config.severeImpactThreshold;

      case 'medium':
        if (isLowSpeed) {
          return hasLowSpeedCorroboration && confidenceScore >= 45.0;
        }

        return confidenceScore >= 40.0 ||
            scores['impact']! >= 45.0 ||
            scores['rotation']! >= 40.0;

      case 'low':
        if (isLowSpeed) return false;

        return confidenceScore >= 65.0 &&
            (scores['impact']! >= 35.0 || scores['rotation']! >= 30.0);

      default:
        return false;
    }
  }

  bool _hasLowSpeedCorroboration(
    Map<String, double> scores,
    double peakGForce,
  ) {
    return scores['impact']! >= 45.0 &&
        (scores['rotation']! >= 30.0 ||
            scores['speed']! >= 20.0 ||
            scores['stillness']! >= 50.0 ||
            peakGForce >= _config.severeImpactThreshold);
  }

  void _resetDetection() {
    _windowAnalyzer.reset();
    _impactMonitor.reset();
    _isProcessingEvent = false;
    _resetTriggerDebounce();
  }

  void _resetTriggerDebounce() {
    _lastHighGForceTime = null;
    _lastHighGForce = 0.0;
  }

  bool _isInCooldown() {
    final lastDetectionTime = _lastDetectionTime;

    if (lastDetectionTime == null) return false;

    final elapsed = DateTime.now().difference(lastDetectionTime);

    return elapsed.inSeconds < _config.detectionCooldownSeconds;
  }

  void updateConfig(DetectionConfig config) {
    if (!config.isStructurallyValid) {
      debugPrint(
        '⚠️ AccidentDetectionEngine: Ignored invalid config update: $config',
      );
      return;
    }

    _config = config;
    _fusionService.updateConfig(config);
    _windowAnalyzer.updateConfig(config);
    _impactMonitor.updateConfig(config);

    debugPrint('🔧 AccidentDetectionEngine: Configuration updated');
    debugPrint('   Config: $_config');
  }

  double _safeNumber(double value, {double fallback = 0.0}) {
    if (value.isNaN || value.isInfinite) {
      return fallback;
    }

    return value;
  }

  String _createEventId(SensorFusionFrame triggerFrame) {
    return 'evt_${triggerFrame.timestamp.microsecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}';
  }

  bool get isRunning => _isRunning;
  bool get isProcessingEvent => _isProcessingEvent;

  Map<String, dynamic> getDebugSnapshot() {
    return {
      'isRunning': _isRunning,
      'isProcessingEvent': _isProcessingEvent,
      'isDisposed': _isDisposed,
      'lastDetectionTime': _lastDetectionTime?.toIso8601String(),
      'hasActiveCallback': _onDetectionCallback != null,
      'fusion': _fusionService.getDebugSnapshot(),
      'windowAnalyzer': _windowAnalyzer.getDebugSnapshot(),
      'impactMonitor': _impactMonitor.getAnalysis(),
      'config': _config.toString(),
    };
  }

  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    await stopDetection();
    await _fusionService.dispose();

    debugPrint('🧹 AccidentDetectionEngine: Disposed');
  }
}
