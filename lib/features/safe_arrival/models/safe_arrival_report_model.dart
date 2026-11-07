import 'package:cloud_firestore/cloud_firestore.dart';

/// ==========================================
/// 🧠 Safe Arrival Report Model
/// ==========================================
/// Compact safety report generated after or during a Safe Arrival trip.
///
/// This model stores machine-safe values only.
/// UI wording/localization should stay in the ViewModel or UI layer.
///
/// Rules:
/// - safetyScore is always clamped between 0 and 100.
/// - safetyLevel must stay consistent with safetyScore unless explicitly set.
/// - Empty guardianReport is allowed for pending reports.
/// - No fake/default user-facing report text is generated here.
class SafeArrivalReportModel {
  final String safetyLevel;
  final double safetyScore;
  final String guardianReport;

  final bool arrivedOnTime;
  final bool hadLongStop;
  final bool hadWeakGps;
  final bool hadRouteDeviation;

  final int weakGpsEvents;
  final int longStopEvents;
  final int routeDeviationEvents;

  final double? averageSpeedKmh;
  final double? maxSpeedKmh;
  final double? actualDistanceMeters;

  final DateTime createdAt;

  const SafeArrivalReportModel({
    required this.safetyLevel,
    required this.safetyScore,
    required this.guardianReport,
    required this.arrivedOnTime,
    required this.hadLongStop,
    required this.hadWeakGps,
    required this.hadRouteDeviation,
    this.weakGpsEvents = 0,
    this.longStopEvents = 0,
    this.routeDeviationEvents = 0,
    this.averageSpeedKmh,
    this.maxSpeedKmh,
    this.actualDistanceMeters,
    required this.createdAt,
  });

  factory SafeArrivalReportModel.pending() {
    return SafeArrivalReportModel(
      safetyLevel: SafeArrivalSafetyLevel.pending.value,
      safetyScore: 0.0,
      guardianReport: '',
      arrivedOnTime: false,
      hadLongStop: false,
      hadWeakGps: false,
      hadRouteDeviation: false,
      weakGpsEvents: 0,
      longStopEvents: 0,
      routeDeviationEvents: 0,
      createdAt: DateTime.now(),
    );
  }

  factory SafeArrivalReportModel.create({
    required double safetyScore,
    required String guardianReport,
    required bool arrivedOnTime,
    required bool hadLongStop,
    required bool hadWeakGps,
    required bool hadRouteDeviation,
    int weakGpsEvents = 0,
    int longStopEvents = 0,
    int routeDeviationEvents = 0,
    double? averageSpeedKmh,
    double? maxSpeedKmh,
    double? actualDistanceMeters,
    DateTime? createdAt,
  }) {
    final score = _safeScore(safetyScore);

    return SafeArrivalReportModel(
      safetyLevel: SafeArrivalSafetyLevel.fromScore(score).value,
      safetyScore: score,
      guardianReport: _cleanText(guardianReport),
      arrivedOnTime: arrivedOnTime,
      hadLongStop: hadLongStop,
      hadWeakGps: hadWeakGps,
      hadRouteDeviation: hadRouteDeviation,
      weakGpsEvents: _safeCount(weakGpsEvents),
      longStopEvents: _safeCount(longStopEvents),
      routeDeviationEvents: _safeCount(routeDeviationEvents),
      averageSpeedKmh: _safeNullableDouble(averageSpeedKmh),
      maxSpeedKmh: _safeNullableDouble(maxSpeedKmh),
      actualDistanceMeters: _safeNullableDouble(actualDistanceMeters),
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  factory SafeArrivalReportModel.fromMap(Map<String, dynamic> map) {
    final rawLevel = _stringOrFallback(
      map['safetyLevel'],
      fallback: SafeArrivalSafetyLevel.pending.value,
    );

    final score = _safeScore(_toDouble(map['safetyScore']) ?? 0.0);
    final normalizedLevel = SafeArrivalSafetyLevel.normalize(rawLevel);

    return SafeArrivalReportModel(
      safetyLevel: normalizedLevel,
      safetyScore: score,
      guardianReport: _cleanText(_stringOrFallback(map['guardianReport'])),
      arrivedOnTime: _toBool(map['arrivedOnTime'], fallback: false),
      hadLongStop: _toBool(map['hadLongStop'], fallback: false),
      hadWeakGps: _toBool(map['hadWeakGps'], fallback: false),
      hadRouteDeviation: _toBool(map['hadRouteDeviation'], fallback: false),
      weakGpsEvents: _safeCount(_toInt(map['weakGpsEvents'], fallback: 0)),
      longStopEvents: _safeCount(_toInt(map['longStopEvents'], fallback: 0)),
      routeDeviationEvents: _safeCount(
        _toInt(map['routeDeviationEvents'], fallback: 0),
      ),
      averageSpeedKmh: _safeNullableDouble(_toDouble(map['averageSpeedKmh'])),
      maxSpeedKmh: _safeNullableDouble(_toDouble(map['maxSpeedKmh'])),
      actualDistanceMeters: _safeNullableDouble(
        _toDouble(map['actualDistanceMeters']),
      ),
      createdAt: _toDateTime(map['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return _removeNullValues({
      'safetyLevel': safetyLevel,
      'safetyScore': safetyScore,
      'guardianReport': guardianReport,
      'arrivedOnTime': arrivedOnTime,
      'hadLongStop': hadLongStop,
      'hadWeakGps': hadWeakGps,
      'hadRouteDeviation': hadRouteDeviation,
      'weakGpsEvents': weakGpsEvents,
      'longStopEvents': longStopEvents,
      'routeDeviationEvents': routeDeviationEvents,
      'averageSpeedKmh': averageSpeedKmh,
      'maxSpeedKmh': maxSpeedKmh,
      'actualDistanceMeters': actualDistanceMeters,
      'createdAt': Timestamp.fromDate(createdAt),
    });
  }

  SafeArrivalReportModel copyWith({
    String? safetyLevel,
    double? safetyScore,
    String? guardianReport,
    bool? arrivedOnTime,
    bool? hadLongStop,
    bool? hadWeakGps,
    bool? hadRouteDeviation,
    int? weakGpsEvents,
    int? longStopEvents,
    int? routeDeviationEvents,
    double? averageSpeedKmh,
    double? maxSpeedKmh,
    double? actualDistanceMeters,
    DateTime? createdAt,
  }) {
    final resolvedScore = safetyScore != null
        ? _safeScore(safetyScore)
        : this.safetyScore;

    final resolvedLevel = safetyLevel != null
        ? SafeArrivalSafetyLevel.normalize(safetyLevel)
        : safetyScore != null
        ? SafeArrivalSafetyLevel.fromScore(resolvedScore).value
        : this.safetyLevel;

    return SafeArrivalReportModel(
      safetyLevel: resolvedLevel,
      safetyScore: resolvedScore,
      guardianReport: guardianReport != null
          ? _cleanText(guardianReport)
          : this.guardianReport,
      arrivedOnTime: arrivedOnTime ?? this.arrivedOnTime,
      hadLongStop: hadLongStop ?? this.hadLongStop,
      hadWeakGps: hadWeakGps ?? this.hadWeakGps,
      hadRouteDeviation: hadRouteDeviation ?? this.hadRouteDeviation,
      weakGpsEvents: weakGpsEvents != null
          ? _safeCount(weakGpsEvents)
          : this.weakGpsEvents,
      longStopEvents: longStopEvents != null
          ? _safeCount(longStopEvents)
          : this.longStopEvents,
      routeDeviationEvents: routeDeviationEvents != null
          ? _safeCount(routeDeviationEvents)
          : this.routeDeviationEvents,
      averageSpeedKmh: averageSpeedKmh != null
          ? _safeNullableDouble(averageSpeedKmh)
          : this.averageSpeedKmh,
      maxSpeedKmh: maxSpeedKmh != null
          ? _safeNullableDouble(maxSpeedKmh)
          : this.maxSpeedKmh,
      actualDistanceMeters: actualDistanceMeters != null
          ? _safeNullableDouble(actualDistanceMeters)
          : this.actualDistanceMeters,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isPending => safetyLevel == SafeArrivalSafetyLevel.pending.value;

  bool get hasGuardianReport => guardianReport.trim().isNotEmpty;

  bool get isExcellent {
    return safetyLevel == SafeArrivalSafetyLevel.excellent.value;
  }

  bool get isGood {
    return safetyLevel == SafeArrivalSafetyLevel.good.value;
  }

  bool get isCaution {
    return safetyLevel == SafeArrivalSafetyLevel.caution.value;
  }

  bool get isDanger {
    return safetyLevel == SafeArrivalSafetyLevel.danger.value;
  }

  bool get isSafe {
    return isExcellent || isGood;
  }

  String get ratingLabel {
    switch (SafeArrivalSafetyLevel.fromString(safetyLevel)) {
      case SafeArrivalSafetyLevel.excellent:
        return 'A+';
      case SafeArrivalSafetyLevel.good:
        return 'A';
      case SafeArrivalSafetyLevel.caution:
        return 'B';
      case SafeArrivalSafetyLevel.danger:
        return 'C';
      case SafeArrivalSafetyLevel.pending:
        return '--';
    }
  }

  double? get actualDistanceKm {
    final meters = actualDistanceMeters;
    if (meters == null) return null;
    return meters / 1000.0;
  }

  static String _cleanText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _stringOrFallback(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;

    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static double _safeScore(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    return value.clamp(0.0, 100.0).toDouble();
  }

  static int _safeCount(int value) {
    return value < 0 ? 0 : value;
  }

  static double? _safeNullableDouble(double? value) {
    if (value == null || value.isNaN || value.isInfinite) return null;
    return value < 0 ? 0.0 : value;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();

    if (value is String) {
      return double.tryParse(value.trim());
    }

    return null;
  }

  static int _toInt(dynamic value, {required int fallback}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();

    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }

    return fallback;
  }

  static bool _toBool(dynamic value, {required bool fallback}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;

    if (value is String) {
      final normalized = value.trim().toLowerCase();

      if (['true', '1', 'yes', 'y'].contains(normalized)) return true;
      if (['false', '0', 'no', 'n'].contains(normalized)) return false;
    }

    return fallback;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }

    if (value is String) {
      return DateTime.tryParse(value.trim());
    }

    return null;
  }

  static Map<String, dynamic> _removeNullValues(Map<String, dynamic> map) {
    final result = Map<String, dynamic>.from(map);
    result.removeWhere((_, value) => value == null);
    return result;
  }
}

enum SafeArrivalSafetyLevel {
  pending('pending'),
  excellent('excellent'),
  good('good'),
  caution('caution'),
  danger('danger');

  final String value;
  const SafeArrivalSafetyLevel(this.value);

  static SafeArrivalSafetyLevel fromScore(double score) {
    final safeScore = score.isNaN || score.isInfinite
        ? 0.0
        : score.clamp(0.0, 100.0).toDouble();

    if (safeScore >= 90.0) return SafeArrivalSafetyLevel.excellent;
    if (safeScore >= 75.0) return SafeArrivalSafetyLevel.good;
    if (safeScore >= 50.0) return SafeArrivalSafetyLevel.caution;
    return SafeArrivalSafetyLevel.danger;
  }

  static SafeArrivalSafetyLevel fromString(String value) {
    switch (normalize(value)) {
      case 'excellent':
        return SafeArrivalSafetyLevel.excellent;
      case 'good':
        return SafeArrivalSafetyLevel.good;
      case 'caution':
        return SafeArrivalSafetyLevel.caution;
      case 'danger':
        return SafeArrivalSafetyLevel.danger;
      case 'pending':
      default:
        return SafeArrivalSafetyLevel.pending;
    }
  }

  static String normalize(String value) {
    final normalized = value.trim().toLowerCase();

    switch (normalized) {
      case 'excellent':
      case 'good':
      case 'caution':
      case 'danger':
      case 'pending':
        return normalized;
      default:
        return SafeArrivalSafetyLevel.pending.value;
    }
  }
}
