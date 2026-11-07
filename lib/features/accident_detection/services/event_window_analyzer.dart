import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_thresholds.dart';
import '../models/detection_config.dart';
import '../models/event_window.dart';
import '../models/sensor_fusion_frame.dart';

/// ==========================================
/// 📊 Event Window Analyzer - Guardian 360
/// ==========================================
/// يحلل بيانات الحساسات ضمن نوافذ زمنية:
/// - قبل الاصطدام
/// - أثناء الاصطدام
/// - بعد الاصطدام
///
/// مسؤولياته:
/// - حفظ sliding buffers.
/// - بناء EventWindow كاملة للمحرك.
/// - كشف patterns مساعدة مثل impact spike / speed drop / stillness.
///
/// غير مسؤول عن:
/// - حساب final severity.
/// - إنشاء DetectionEvent.
/// - إرسال SOS.
/// - الكتابة في Firebase.
///
/// المسار:
/// SensorFusionService
///   → EventWindowAnalyzer
///   → PostImpactMonitor / AccidentDetectionEngine
class EventWindowAnalyzer {
  DetectionConfig _config;

  EventWindowAnalyzer({DetectionConfig? config})
    : _config = _safeConfig(config);

  static DetectionConfig _safeConfig(DetectionConfig? config) {
    if (config != null && config.isStructurallyValid) {
      return config;
    }

    if (config != null) {
      debugPrint(
        '⚠️ EventWindowAnalyzer: Invalid config received, using medium config',
      );
    }

    return DetectionConfig.medium();
  }

  // ==========================================
  // 📦 Sliding Window Buffers
  // ==========================================

  final Queue<SensorFusionFrame> _preImpactBuffer = Queue<SensorFusionFrame>();
  final Queue<SensorFusionFrame> _impactBuffer = Queue<SensorFusionFrame>();
  final Queue<SensorFusionFrame> _postImpactBuffer = Queue<SensorFusionFrame>();

  // ==========================================
  // 🎯 Detection State
  // ==========================================

  bool _isCapturingPostImpact = false;
  bool _postImpactCaptureCompleted = false;

  DateTime? _impactDetectedAt;
  DateTime? _lastFrameTimestamp;
  SensorFusionFrame? _triggerFrame;

  // ==========================================
  // 📥 Add Frame to Analysis
  // ==========================================

  /// إضافة frame جديدة للتحليل.
  ///
  /// قبل trigger:
  /// - تحفظ داخل pre-impact buffer.
  ///
  /// بعد trigger:
  /// - توزع بين impact/post-impact حسب timestamp.
  void addFrame(SensorFusionFrame frame) {
    if (!frame.isStructurallyValid) {
      debugPrint('⚠️ EventWindowAnalyzer: Invalid frame ignored');
      return;
    }

    if (_postImpactCaptureCompleted) {
      // بعد اكتمال النافذة لا نغيرها حتى يعالجها المحرك ثم ينادي reset().
      return;
    }

    _updateLastFrameTimestamp(frame.timestamp);

    if (_isCapturingPostImpact) {
      _capturePostImpactFrame(frame);
      return;
    }

    _maintainPreImpactBuffer(frame, frame.timestamp);
  }

  // ==========================================
  // 🔍 Impact Detection Trigger
  // ==========================================

  /// يبدأ نافذة حادث كاملة حول triggerFrame.
  ///
  /// مهم جداً:
  /// نضيف triggerFrame إلى impactBuffer صراحةً حتى لا تضيع لحظة الاصطدام
  /// إذا لم تكن موجودة داخل preImpactBuffer.
  void triggerImpactDetection(SensorFusionFrame triggerFrame) {
    if (!triggerFrame.isStructurallyValid) {
      debugPrint('⚠️ EventWindowAnalyzer: Invalid trigger frame ignored');
      return;
    }

    if (_isCapturingPostImpact) {
      debugPrint('⚠️ EventWindowAnalyzer: Already capturing post-impact data');
      return;
    }

    debugPrint('💥 EventWindowAnalyzer: Impact triggered');

    _triggerFrame = triggerFrame;
    _impactDetectedAt = triggerFrame.timestamp;
    _lastFrameTimestamp = triggerFrame.timestamp;

    _isCapturingPostImpact = true;
    _postImpactCaptureCompleted = false;

    _populateImpactBuffer(triggerFrame.timestamp);
    _addToImpactBufferIfNeeded(triggerFrame);
  }

  // ==========================================
  // 📊 Buffer Management
  // ==========================================

  void _maintainPreImpactBuffer(SensorFusionFrame frame, DateTime now) {
    _preImpactBuffer.add(frame);

    final cutoffTime = now.subtract(
      Duration(milliseconds: _config.preImpactWindowMs),
    );

    while (_preImpactBuffer.isNotEmpty &&
        _preImpactBuffer.first.timestamp.isBefore(cutoffTime)) {
      _preImpactBuffer.removeFirst();
    }
  }

  void _populateImpactBuffer(DateTime impactTime) {
    _impactBuffer.clear();

    final impactWindowStart = impactTime.subtract(
      Duration(milliseconds: _config.impactWindowMs ~/ 2),
    );
    final impactWindowEnd = impactTime.add(
      Duration(milliseconds: _config.impactWindowMs ~/ 2),
    );

    for (final frame in _preImpactBuffer) {
      if (!frame.timestamp.isBefore(impactWindowStart) &&
          !frame.timestamp.isAfter(impactWindowEnd)) {
        _addToImpactBufferIfNeeded(frame);
      }
    }

    _preImpactBuffer.removeWhere(
      (frame) =>
          !frame.timestamp.isBefore(impactWindowStart) &&
          !frame.timestamp.isAfter(impactWindowEnd),
    );
  }

  void _capturePostImpactFrame(SensorFusionFrame frame) {
    final impactDetectedAt = _impactDetectedAt;

    if (impactDetectedAt == null) return;
    if (_postImpactCaptureCompleted) return;

    // تجاهل أي frame قديم وصل خارج الترتيب بعد trigger.
    if (frame.timestamp.isBefore(impactDetectedAt)) {
      debugPrint(
        '⚠️ EventWindowAnalyzer: Out-of-order pre-impact frame ignored during post-capture',
      );
      return;
    }

    final timeSinceImpact = frame.timestamp
        .difference(impactDetectedAt)
        .inMilliseconds;

    final impactTailWindowMs = _config.impactWindowMs ~/ 2;

    if (timeSinceImpact <= impactTailWindowMs) {
      _addToImpactBufferIfNeeded(frame);
    } else if (timeSinceImpact <= _config.postImpactWindowMs) {
      _postImpactBuffer.add(frame);
    }

    if (timeSinceImpact >= _config.postImpactWindowMs) {
      _markPostImpactCompleted();
    }
  }

  void _addToImpactBufferIfNeeded(SensorFusionFrame frame) {
    final exists = _impactBuffer.any(
      (existing) => _isSameFrame(existing, frame),
    );

    if (!exists) {
      _impactBuffer.add(frame);
    }
  }

  bool _isSameFrame(SensorFusionFrame a, SensorFusionFrame b) {
    return a.timestamp == b.timestamp &&
        a.gForce == b.gForce &&
        a.rotation == b.rotation &&
        a.speedKmh == b.speedKmh;
  }

  void _updateLastFrameTimestamp(DateTime timestamp) {
    final last = _lastFrameTimestamp;

    if (last == null || timestamp.isAfter(last)) {
      _lastFrameTimestamp = timestamp;
    }
  }

  void _markPostImpactCompleted() {
    if (_postImpactCaptureCompleted) return;

    _postImpactCaptureCompleted = true;

    debugPrint(
      '✅ EventWindowAnalyzer: Post-impact capture complete '
      '(${_postImpactBuffer.length} post frames, '
      '${_impactBuffer.length} impact frames)',
    );
  }

  // ==========================================
  // 📈 Window Readiness
  // ==========================================

  /// هل نافذة الحدث جاهزة للتحليل؟
  ///
  /// نستخدم آخر frame وصلت، ومعها fallback بسيط على الوقت الحالي.
  /// هذا يمنع بناء نافذة قبل اكتمال post-impact قدر الإمكان.
  bool hasCompleteWindow() {
    if (!_isCapturingPostImpact || _impactDetectedAt == null) {
      return false;
    }

    if (_postImpactCaptureCompleted) {
      return true;
    }

    final impactTime = _impactDetectedAt!;
    final lastFrameTime = _lastFrameTimestamp;

    if (lastFrameTime != null && !lastFrameTime.isBefore(impactTime)) {
      final elapsed = lastFrameTime.difference(impactTime).inMilliseconds;

      if (elapsed >= _config.postImpactWindowMs) {
        return true;
      }
    }

    final wallClockElapsed = DateTime.now()
        .difference(impactTime)
        .inMilliseconds;

    return wallClockElapsed >= _config.postImpactWindowMs &&
        _impactBuffer.isNotEmpty;
  }

  /// بناء نافذة الحدث النهائية.
  EventWindow? getEventWindow() {
    if (!hasCompleteWindow() || _impactDetectedAt == null) {
      return null;
    }

    final triggerFrame = _triggerFrame;
    if (triggerFrame != null) {
      _addToImpactBufferIfNeeded(triggerFrame);
    }

    if (_impactBuffer.isEmpty) {
      debugPrint(
        '⚠️ EventWindowAnalyzer: Complete window requested but impact buffer is empty',
      );
      return null;
    }

    final windowStart = _impactDetectedAt!.subtract(
      Duration(milliseconds: _config.preImpactWindowMs),
    );
    final windowEnd = _impactDetectedAt!.add(
      Duration(milliseconds: _config.postImpactWindowMs),
    );

    final eventWindow = EventWindow(
      preImpactFrames: List<SensorFusionFrame>.from(_preImpactBuffer),
      impactFrames: List<SensorFusionFrame>.from(_impactBuffer),
      postImpactFrames: List<SensorFusionFrame>.from(_postImpactBuffer),
      impactTimestamp: _impactDetectedAt!,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );

    debugPrint('📊 EventWindowAnalyzer: Event window created - $eventWindow');
    return eventWindow;
  }

  // ==========================================
  // 🔍 Pattern Detection Helpers
  // ==========================================

  /// كشف هبوط السرعة.
  ///
  /// المنطق الأقوى:
  /// نقارن متوسط السرعة قبل الاصطدام بمتوسط السرعة بعده.
  /// إن لم تتوفر post-impact frames نستخدم impact frames كـ fallback.
  bool detectSuddenDeceleration() {
    final speedBeforeImpact = _averageValidSpeed(_preImpactBuffer);
    final speedAfterImpact = _averageValidSpeed(
      _postImpactBuffer.isNotEmpty ? _postImpactBuffer : _impactBuffer,
    );

    if (speedBeforeImpact == null || speedAfterImpact == null) {
      return false;
    }

    final speedDrop = speedBeforeImpact - speedAfterImpact;

    return AppThresholds.isSignificantSpeedDrop(speedDrop);
  }

  /// كشف peak impact داخل نافذة الاصطدام.
  bool detectImpactSpike() {
    final peakGForce = _peakGForce();

    if (peakGForce == null) return false;

    return peakGForce >= _config.impactThreshold;
  }

  /// كشف السكون بعد الاصطدام.
  ///
  /// لا نكتفي بعينة واحدة، بل نتحقق من وجود مدة post-impact كافية.
  bool detectStillness() {
    if (_postImpactBuffer.length < 3) return false;

    final durationMs = _durationMs(_postImpactBuffer);

    if (durationMs < _minimumStillnessDurationMs) {
      return false;
    }

    final avgGForce = _averageGForce(_postImpactBuffer);
    final avgSpeed = _averageValidSpeed(_postImpactBuffer);

    if (avgGForce == null || avgSpeed == null) {
      return false;
    }

    return AppThresholds.isStillness(avgGForce) &&
        avgSpeed < AppThresholds.minActiveSpeedKmh;
  }

  double? _peakGForce() {
    final frames = <SensorFusionFrame>[
      ..._impactBuffer,
      if (_triggerFrame != null) _triggerFrame!,
    ];

    if (frames.isEmpty) return null;

    var peak = 0.0;

    for (final frame in frames) {
      if (frame.gForce.isNaN || frame.gForce.isInfinite) continue;
      if (frame.gForce > peak) peak = frame.gForce;
    }

    return peak;
  }

  double? _averageGForce(Iterable<SensorFusionFrame> frames) {
    var sum = 0.0;
    var count = 0;

    for (final frame in frames) {
      if (frame.gForce.isNaN || frame.gForce.isInfinite) continue;

      sum += frame.gForce;
      count++;
    }

    if (count == 0) return null;

    return sum / count;
  }

  double? _averageValidSpeed(Iterable<SensorFusionFrame> frames) {
    var sum = 0.0;
    var count = 0;

    for (final frame in frames) {
      final speed = frame.speedKmh;

      if (speed.isNaN || speed.isInfinite) continue;
      if (!AppThresholds.isValidSpeed(speed)) continue;

      sum += speed;
      count++;
    }

    if (count == 0) return null;

    return sum / count;
  }

  int _durationMs(Iterable<SensorFusionFrame> frames) {
    final list = frames.toList();

    if (list.length < 2) return 0;

    final first = list.first.timestamp;
    final last = list.last.timestamp;

    return last.difference(first).inMilliseconds.abs();
  }

  int get _minimumStillnessDurationMs {
    final configured = _config.stillnessDurationMs;

    if (configured <= 0) {
      return AppThresholds.stillnessDurationMs;
    }

    return configured;
  }

  // ==========================================
  // ⚙️ Configuration
  // ==========================================

  void updateConfig(DetectionConfig config) {
    if (!config.isStructurallyValid) {
      debugPrint(
        '⚠️ EventWindowAnalyzer: Ignored invalid config update: $config',
      );
      return;
    }

    _config = config;
    debugPrint('🔧 EventWindowAnalyzer: Configuration updated');
  }

  // ==========================================
  // 🧹 Reset & Cleanup
  // ==========================================

  /// Reset analyzer completely after processing an event.
  void reset() {
    _preImpactBuffer.clear();
    _impactBuffer.clear();
    _postImpactBuffer.clear();

    _isCapturingPostImpact = false;
    _postImpactCaptureCompleted = false;

    _impactDetectedAt = null;
    _lastFrameTimestamp = null;
    _triggerFrame = null;

    debugPrint('🔄 EventWindowAnalyzer: Reset complete');
  }

  /// Clear buffers only.
  ///
  /// ملاحظة:
  /// يفضل استخدام reset() بعد معالجة حدث كامل.
  /// هذه الدالة موجودة فقط للتنظيف الجزئي عند الحاجة.
  void clear() {
    _preImpactBuffer.clear();
    _impactBuffer.clear();
    _postImpactBuffer.clear();

    debugPrint('🧹 EventWindowAnalyzer: Buffers cleared');
  }

  // ==========================================
  // 📊 Status & Debugging
  // ==========================================

  Map<String, int> getBufferSizes() {
    return {
      'preImpact': _preImpactBuffer.length,
      'impact': _impactBuffer.length,
      'postImpact': _postImpactBuffer.length,
    };
  }

  Map<String, dynamic> getDebugSnapshot() {
    return {
      'isCapturingPostImpact': _isCapturingPostImpact,
      'postImpactCaptureCompleted': _postImpactCaptureCompleted,
      'impactDetectedAt': _impactDetectedAt?.toIso8601String(),
      'lastFrameTimestamp': _lastFrameTimestamp?.toIso8601String(),
      'hasTriggerFrame': _triggerFrame != null,
      'bufferSizes': getBufferSizes(),
      'hasCompleteWindow': hasCompleteWindow(),
      'detectSuddenDeceleration': detectSuddenDeceleration(),
      'detectImpactSpike': detectImpactSpike(),
      'detectStillness': detectStillness(),
      'peakGForce': _peakGForce(),
      'config': _config.toString(),
    };
  }

  bool get isCapturingPostImpact => _isCapturingPostImpact;
  bool get postImpactCaptureCompleted => _postImpactCaptureCompleted;
  SensorFusionFrame? get triggerFrame => _triggerFrame;

  @override
  String toString() {
    return 'EventWindowAnalyzer('
        'preImpact: ${_preImpactBuffer.length}, '
        'impact: ${_impactBuffer.length}, '
        'postImpact: ${_postImpactBuffer.length}, '
        'capturing: $_isCapturingPostImpact, '
        'completed: $_postImpactCaptureCompleted'
        ')';
  }
}
