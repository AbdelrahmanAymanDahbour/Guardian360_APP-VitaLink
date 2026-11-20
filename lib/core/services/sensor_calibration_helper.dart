import 'package:flutter/foundation.dart';

/// ==========================================
/// 🎯 Sensor Calibration Helper - Guardian 360
/// ==========================================
/// أداة مساعدة لمعايرة وضبط الحساسات
/// تساعد في اختبار وتحسين دقة كشف الحوادث
///
/// الاستخدامات:
/// - معايرة الحساسات على أجهزة مختلفة
/// - اختبار العتبات المختلفة
/// - تحليل البيانات الحقيقية
/// - توليد تقارير الأداء
class SensorCalibrationHelper {
  // ==========================================
  // 📊 Statistics Tracking
  // ==========================================
  final List<CalibrationSample> _samples = [];

  int _totalDetections = 0;
  int _truePositives = 0;
  int _falsePositives = 0;
  int _trueNegatives = 0;
  int _falseNegatives = 0;

  // ==========================================
  // 📈 Getters
  // ==========================================
  int get totalSamples => _samples.length;
  int get totalDetections => _totalDetections;
  int get truePositives => _truePositives;
  int get falsePositives => _falsePositives;
  int get trueNegatives => _trueNegatives;
  int get falseNegatives => _falseNegatives;

  /// دقة النظام (Accuracy)
  double get accuracy {
    final total =
        _truePositives + _falsePositives + _trueNegatives + _falseNegatives;
    if (total == 0) return 0.0;
    return ((_truePositives + _trueNegatives) / total) * 100;
  }

  /// الدقة (Precision)
  double get precision {
    final total = _truePositives + _falsePositives;
    if (total == 0) return 0.0;
    return (_truePositives / total) * 100;
  }

  /// الاستدعاء (Recall)
  double get recall {
    final total = _truePositives + _falseNegatives;
    if (total == 0) return 0.0;
    return (_truePositives / total) * 100;
  }

  /// F1 Score
  double get f1Score {
    final p = precision;
    final r = recall;
    if (p + r == 0) return 0.0;
    return 2 * (p * r) / (p + r);
  }

  // ==========================================
  // 📝 Recording Methods
  // ==========================================

  /// تسجيل عينة جديدة
  void recordSample({
    required double gForce,
    required double rotation,
    required bool wasAccident,
    required bool detectedAsAccident,
    required double severityScore,
    String? notes,
  }) {
    final sample = CalibrationSample(
      gForce: gForce,
      rotation: rotation,
      wasAccident: wasAccident,
      detectedAsAccident: detectedAsAccident,
      severityScore: severityScore,
      timestamp: DateTime.now(),
      notes: notes,
    );

    _samples.add(sample);
    _updateStatistics(wasAccident, detectedAsAccident);

    debugPrint('📝 Sample recorded: ${sample.toString()}');
  }

  /// تحديث الإحصائيات
  void _updateStatistics(bool wasAccident, bool detectedAsAccident) {
    _totalDetections++;

    if (wasAccident && detectedAsAccident) {
      _truePositives++;
    } else if (!wasAccident && detectedAsAccident) {
      _falsePositives++;
    } else if (!wasAccident && !detectedAsAccident) {
      _trueNegatives++;
    } else if (wasAccident && !detectedAsAccident) {
      _falseNegatives++;
    }
  }

  // ==========================================
  // 📊 Analysis Methods
  // ==========================================

  /// تحليل العينات المسجلة
  CalibrationAnalysis analyzeData() {
    if (_samples.isEmpty) {
      return CalibrationAnalysis(
        totalSamples: 0,
        accuracy: 0.0,
        precision: 0.0,
        recall: 0.0,
        f1Score: 0.0,
        averageGForce: 0.0,
        averageRotation: 0.0,
        maxGForce: 0.0,
        maxRotation: 0.0,
        minGForce: 0.0,
        minRotation: 0.0,
        recommendations: ['لا توجد بيانات كافية للتحليل'],
      );
    }

    // حساب المتوسطات
    double totalGForce = 0.0;
    double totalRotation = 0.0;
    double maxGForce = _samples.first.gForce;
    double maxRotation = _samples.first.rotation;
    double minGForce = _samples.first.gForce;
    double minRotation = _samples.first.rotation;

    for (final sample in _samples) {
      totalGForce += sample.gForce;
      totalRotation += sample.rotation;

      if (sample.gForce > maxGForce) maxGForce = sample.gForce;
      if (sample.rotation > maxRotation) maxRotation = sample.rotation;
      if (sample.gForce < minGForce) minGForce = sample.gForce;
      if (sample.rotation < minRotation) minRotation = sample.rotation;
    }

    final avgGForce = totalGForce / _samples.length;
    final avgRotation = totalRotation / _samples.length;

    // توليد التوصيات
    final recommendations = _generateRecommendations();

    return CalibrationAnalysis(
      totalSamples: _samples.length,
      accuracy: accuracy,
      precision: precision,
      recall: recall,
      f1Score: f1Score,
      averageGForce: avgGForce,
      averageRotation: avgRotation,
      maxGForce: maxGForce,
      maxRotation: maxRotation,
      minGForce: minGForce,
      minRotation: minRotation,
      recommendations: recommendations,
    );
  }

  /// توليد التوصيات بناءً على البيانات
  List<String> _generateRecommendations() {
    final recommendations = <String>[];

    // تحليل الدقة
    if (accuracy < 70) {
      recommendations.add(
        '⚠️ الدقة منخفضة جداً (${accuracy.toStringAsFixed(1)}%) - يحتاج النظام لمعايرة شاملة',
      );
    } else if (accuracy < 85) {
      recommendations.add(
        '⚡ الدقة متوسطة (${accuracy.toStringAsFixed(1)}%) - يمكن تحسينها',
      );
    } else {
      recommendations.add('✅ الدقة ممتازة (${accuracy.toStringAsFixed(1)}%)');
    }

    // تحليل False Positives
    if (_falsePositives > _truePositives) {
      recommendations.add(
        '🚨 عدد الإنذارات الكاذبة مرتفع - قم برفع العتبات (Thresholds)',
      );
    }

    // تحليل False Negatives
    if (_falseNegatives > 0) {
      recommendations.add(
        '⚠️ النظام فوّت $_falseNegatives حادث حقيقي - قم بخفض العتبات',
      );
    }

    // تحليل Precision
    if (precision < 80) {
      recommendations.add('📊 الدقة في التصنيف منخفضة - راجع خوارزمية الكشف');
    }

    // تحليل Recall
    if (recall < 90) {
      recommendations.add('🔍 معدل الاستدعاء منخفض - النظام يفوت بعض الحوادث');
    }

    if (recommendations.isEmpty) {
      recommendations.add('🎉 النظام يعمل بكفاءة عالية!');
    }

    return recommendations;
  }

  // ==========================================
  // 📄 Reporting Methods
  // ==========================================

  /// طباعة تقرير مفصل
  void printDetailedReport() {
    final analysis = analyzeData();

    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('📊 SENSOR CALIBRATION REPORT - Guardian 360');
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('');
    debugPrint('📈 PERFORMANCE METRICS:');
    debugPrint('   ├─ Total Samples: ${analysis.totalSamples}');
    debugPrint('   ├─ Accuracy: ${analysis.accuracy.toStringAsFixed(2)}%');
    debugPrint('   ├─ Precision: ${analysis.precision.toStringAsFixed(2)}%');
    debugPrint('   ├─ Recall: ${analysis.recall.toStringAsFixed(2)}%');
    debugPrint('   └─ F1 Score: ${analysis.f1Score.toStringAsFixed(2)}%');
    debugPrint('');
    debugPrint('🎯 CONFUSION MATRIX:');
    debugPrint('   ├─ True Positives: $_truePositives');
    debugPrint('   ├─ False Positives: $_falsePositives');
    debugPrint('   ├─ True Negatives: $_trueNegatives');
    debugPrint('   └─ False Negatives: $_falseNegatives');
    debugPrint('');
    debugPrint('📊 SENSOR DATA STATISTICS:');
    debugPrint(
      '   ├─ Average G-Force: ${analysis.averageGForce.toStringAsFixed(3)}',
    );
    debugPrint(
      '   ├─ Average Rotation: ${analysis.averageRotation.toStringAsFixed(3)}',
    );
    debugPrint('   ├─ Max G-Force: ${analysis.maxGForce.toStringAsFixed(3)}');
    debugPrint(
      '   ├─ Max Rotation: ${analysis.maxRotation.toStringAsFixed(3)}',
    );
    debugPrint('   ├─ Min G-Force: ${analysis.minGForce.toStringAsFixed(3)}');
    debugPrint(
      '   └─ Min Rotation: ${analysis.minRotation.toStringAsFixed(3)}',
    );
    debugPrint('');
    debugPrint('💡 RECOMMENDATIONS:');
    for (int i = 0; i < analysis.recommendations.length; i++) {
      final prefix = i == analysis.recommendations.length - 1
          ? '   └─'
          : '   ├─';
      debugPrint('$prefix ${analysis.recommendations[i]}');
    }
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('');
  }

  /// تصدير البيانات كـ CSV
  String exportToCSV() {
    final buffer = StringBuffer();

    // Header
    buffer.writeln(
      'Timestamp,G-Force,Rotation,Was Accident,Detected As Accident,Severity Score,Notes',
    );

    // Data
    for (final sample in _samples) {
      buffer.writeln(
        '${sample.timestamp.toIso8601String()},'
        '${sample.gForce},'
        '${sample.rotation},'
        '${sample.wasAccident},'
        '${sample.detectedAsAccident},'
        '${sample.severityScore},'
        '"${sample.notes ?? ""}"',
      );
    }

    return buffer.toString();
  }

  // ==========================================
  // 🧹 Utility Methods
  // ==========================================

  /// مسح جميع البيانات
  void clearData() {
    _samples.clear();
    _totalDetections = 0;
    _truePositives = 0;
    _falsePositives = 0;
    _trueNegatives = 0;
    _falseNegatives = 0;
    debugPrint('🧹 Calibration data cleared');
  }

  /// الحصول على آخر N عينة
  List<CalibrationSample> getRecentSamples(int count) {
    if (_samples.length <= count) {
      return List.from(_samples);
    }
    return _samples.sublist(_samples.length - count);
  }

  /// الحصول على العينات الخاطئة فقط
  List<CalibrationSample> getIncorrectSamples() {
    return _samples.where((sample) {
      return sample.wasAccident != sample.detectedAsAccident;
    }).toList();
  }
}

// ==========================================
// 📦 Data Models
// ==========================================

/// عينة معايرة واحدة
class CalibrationSample {
  final double gForce;
  final double rotation;
  final bool wasAccident;
  final bool detectedAsAccident;
  final double severityScore;
  final DateTime timestamp;
  final String? notes;

  CalibrationSample({
    required this.gForce,
    required this.rotation,
    required this.wasAccident,
    required this.detectedAsAccident,
    required this.severityScore,
    required this.timestamp,
    this.notes,
  });

  bool get isCorrect => wasAccident == detectedAsAccident;

  String get resultType {
    if (wasAccident && detectedAsAccident) return 'True Positive';
    if (!wasAccident && detectedAsAccident) return 'False Positive';
    if (!wasAccident && !detectedAsAccident) return 'True Negative';
    return 'False Negative';
  }

  @override
  String toString() {
    return 'CalibrationSample('
        'gForce: ${gForce.toStringAsFixed(2)}, '
        'rotation: ${rotation.toStringAsFixed(2)}, '
        'result: $resultType, '
        'score: ${severityScore.toStringAsFixed(1)}'
        ')';
  }
}

/// نتيجة تحليل المعايرة
class CalibrationAnalysis {
  final int totalSamples;
  final double accuracy;
  final double precision;
  final double recall;
  final double f1Score;
  final double averageGForce;
  final double averageRotation;
  final double maxGForce;
  final double maxRotation;
  final double minGForce;
  final double minRotation;
  final List<String> recommendations;

  CalibrationAnalysis({
    required this.totalSamples,
    required this.accuracy,
    required this.precision,
    required this.recall,
    required this.f1Score,
    required this.averageGForce,
    required this.averageRotation,
    required this.maxGForce,
    required this.maxRotation,
    required this.minGForce,
    required this.minRotation,
    required this.recommendations,
  });
}
