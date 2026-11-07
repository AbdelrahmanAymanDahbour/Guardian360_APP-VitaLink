import 'package:cloud_firestore/cloud_firestore.dart';

class TripModel {
  final String id;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final TripStatus status;

  // Trip info
  final String? destination;
  final int? estimatedDurationMinutes;

  // Location info
  final double? startLatitude;
  final double? startLongitude;
  final double? endLatitude;
  final double? endLongitude;

  // Trip statistics
  final int accidentDetectionCount;
  final int falsePositiveCount;
  final double? maxGForceDetected;
  final double? maxRotationDetected;

  // Trip settings
  final String sensitivityLevel;
  final bool autoSOSEnabled;
  final bool safeArrivalNotificationEnabled;

  const TripModel({
    required this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    required this.status,
    this.destination,
    this.estimatedDurationMinutes,
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
    this.accidentDetectionCount = 0,
    this.falsePositiveCount = 0,
    this.maxGForceDetected,
    this.maxRotationDetected,
    this.sensitivityLevel = 'medium',
    this.autoSOSEnabled = true,
    this.safeArrivalNotificationEnabled = true,
  });

  // ==========================================
  // Factory Constructors
  // ==========================================

  factory TripModel.create({
    required String userId,
    String? destination,
    int? estimatedDurationMinutes,
    double? startLatitude,
    double? startLongitude,
    String sensitivityLevel = 'medium',
  }) {
    final now = DateTime.now();

    return TripModel(
      id: now.microsecondsSinceEpoch.toString(),
      userId: userId.trim(),
      startTime: now,
      status: TripStatus.active,
      destination: destination?.trim().isEmpty == true
          ? null
          : destination?.trim(),
      estimatedDurationMinutes: estimatedDurationMinutes,
      startLatitude: startLatitude,
      startLongitude: startLongitude,
      sensitivityLevel: sensitivityLevel.trim().isEmpty
          ? 'medium'
          : sensitivityLevel.trim().toLowerCase(),
    );
  }

  factory TripModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    if (data == null) {
      throw StateError('Trip document data is null for id: ${doc.id}');
    }

    return TripModel(
      id: doc.id,
      userId: (data['userId'] ?? '').toString(),
      startTime: _parseDateTime(data['startTime']) ?? DateTime.now(),
      endTime: _parseDateTime(data['endTime']),
      status: TripStatus.fromString((data['status'] ?? 'active').toString()),
      destination: data['destination']?.toString(),
      estimatedDurationMinutes: _parseInt(data['estimatedDurationMinutes']),
      startLatitude: _parseDouble(data['startLatitude']),
      startLongitude: _parseDouble(data['startLongitude']),
      endLatitude: _parseDouble(data['endLatitude']),
      endLongitude: _parseDouble(data['endLongitude']),
      accidentDetectionCount: _parseInt(data['accidentDetectionCount']) ?? 0,
      falsePositiveCount: _parseInt(data['falsePositiveCount']) ?? 0,
      maxGForceDetected: _parseDouble(data['maxGForceDetected']),
      maxRotationDetected: _parseDouble(data['maxRotationDetected']),
      sensitivityLevel: (data['sensitivityLevel'] ?? 'medium').toString(),
      autoSOSEnabled: data['autoSOSEnabled'] == true,
      safeArrivalNotificationEnabled:
          data['safeArrivalNotificationEnabled'] != false,
    );
  }

  factory TripModel.fromMap(Map<String, dynamic> map) {
    return TripModel(
      id: (map['id'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      startTime: _parseDateTime(map['startTime']) ?? DateTime.now(),
      endTime: _parseDateTime(map['endTime']),
      status: TripStatus.fromString((map['status'] ?? 'active').toString()),
      destination: map['destination']?.toString(),
      estimatedDurationMinutes: _parseInt(map['estimatedDurationMinutes']),
      startLatitude: _parseDouble(map['startLatitude']),
      startLongitude: _parseDouble(map['startLongitude']),
      endLatitude: _parseDouble(map['endLatitude']),
      endLongitude: _parseDouble(map['endLongitude']),
      accidentDetectionCount: _parseInt(map['accidentDetectionCount']) ?? 0,
      falsePositiveCount: _parseInt(map['falsePositiveCount']) ?? 0,
      maxGForceDetected: _parseDouble(map['maxGForceDetected']),
      maxRotationDetected: _parseDouble(map['maxRotationDetected']),
      sensitivityLevel: (map['sensitivityLevel'] ?? 'medium').toString(),
      autoSOSEnabled: map['autoSOSEnabled'] != false,
      safeArrivalNotificationEnabled:
          map['safeArrivalNotificationEnabled'] != false,
    );
  }

  // ==========================================
  // Serialization
  // ==========================================

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'status': status.value,
      'destination': destination,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'startLatitude': startLatitude,
      'startLongitude': startLongitude,
      'endLatitude': endLatitude,
      'endLongitude': endLongitude,
      'accidentDetectionCount': accidentDetectionCount,
      'falsePositiveCount': falsePositiveCount,
      'maxGForceDetected': maxGForceDetected,
      'maxRotationDetected': maxRotationDetected,
      'sensitivityLevel': sensitivityLevel,
      'autoSOSEnabled': autoSOSEnabled,
      'safeArrivalNotificationEnabled': safeArrivalNotificationEnabled,
    };
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'status': status.value,
      'destination': destination,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'startLatitude': startLatitude,
      'startLongitude': startLongitude,
      'endLatitude': endLatitude,
      'endLongitude': endLongitude,
      'accidentDetectionCount': accidentDetectionCount,
      'falsePositiveCount': falsePositiveCount,
      'maxGForceDetected': maxGForceDetected,
      'maxRotationDetected': maxRotationDetected,
      'sensitivityLevel': sensitivityLevel,
      'autoSOSEnabled': autoSOSEnabled,
      'safeArrivalNotificationEnabled': safeArrivalNotificationEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ==========================================
  // Copy With
  // ==========================================

  TripModel copyWith({
    String? id,
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    TripStatus? status,
    String? destination,
    int? estimatedDurationMinutes,
    double? startLatitude,
    double? startLongitude,
    double? endLatitude,
    double? endLongitude,
    int? accidentDetectionCount,
    int? falsePositiveCount,
    double? maxGForceDetected,
    double? maxRotationDetected,
    String? sensitivityLevel,
    bool? autoSOSEnabled,
    bool? safeArrivalNotificationEnabled,
  }) {
    return TripModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      status: status ?? this.status,
      destination: destination ?? this.destination,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      accidentDetectionCount:
          accidentDetectionCount ?? this.accidentDetectionCount,
      falsePositiveCount: falsePositiveCount ?? this.falsePositiveCount,
      maxGForceDetected: maxGForceDetected ?? this.maxGForceDetected,
      maxRotationDetected: maxRotationDetected ?? this.maxRotationDetected,
      sensitivityLevel: sensitivityLevel ?? this.sensitivityLevel,
      autoSOSEnabled: autoSOSEnabled ?? this.autoSOSEnabled,
      safeArrivalNotificationEnabled:
          safeArrivalNotificationEnabled ?? this.safeArrivalNotificationEnabled,
    );
  }

  // ==========================================
  // Helpers
  // ==========================================

  int? get durationMinutes {
    if (endTime == null) return null;
    return endTime!.difference(startTime).inMinutes;
  }

  bool get isActive => status == TripStatus.active;

  bool get isClosed =>
      status == TripStatus.completed || status == TripStatus.cancelled;

  bool get isEmergency => status == TripStatus.emergency;

  bool get hasAccidentDetections => accidentDetectionCount > 0;

  bool get hasFalsePositives => falsePositiveCount > 0;

  // ==========================================
  // Parsing helpers
  // ==========================================

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

enum TripStatus {
  active('active'),
  completed('completed'),
  cancelled('cancelled'),
  emergency('emergency');

  final String value;
  const TripStatus(this.value);

  static TripStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return TripStatus.active;
      case 'completed':
        return TripStatus.completed;
      case 'cancelled':
        return TripStatus.cancelled;
      case 'emergency':
        return TripStatus.emergency;
      default:
        return TripStatus.active;
    }
  }

  String get displayName {
    switch (this) {
      case TripStatus.active:
        return 'نشطة';
      case TripStatus.completed:
        return 'مكتملة';
      case TripStatus.cancelled:
        return 'ملغاة';
      case TripStatus.emergency:
        return 'طوارئ';
    }
  }
}
