import 'package:cloud_firestore/cloud_firestore.dart';

/// ==========================================
/// 🔔 In-App Notification Model - Guardian 360
/// ==========================================
/// Model for in-app notifications stored in:
/// users/{uid}/notifications/{notificationId}
///
/// Important:
/// - This is NOT for official emergency accidents.
/// - This is NOT for dashboard alerts.
/// - This is for user-facing in-app notifications only.
/// - Emergency reports still go through accidents collection.
class NotificationModel {
  const NotificationModel({
    required this.id,
    required this.type,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    required this.isRead,
    required this.priority,
    required this.source,
    required this.payload,
    required this.createdAt,
    required this.updatedAt,
    this.relatedAccidentId,
    this.readAt,
  });

  final String id;
  final String type;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  final bool isRead;
  final String priority;
  final String source;
  final String? relatedAccidentId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? readAt;

  static const String typeSystemNotice = 'system_notice';
  static const String typeKrokaReportSaved = 'kroka_report_saved';

  static const Set<String> safeArrivalTypes = <String>{
    'safe_arrival_started',
    'safe_arrival_paused',
    'safe_arrival_resumed',
    'safe_arrival_near_destination',
    'safe_arrival_arrived',
    'safe_arrival_cancelled',
    'safe_arrival_danger',
  };

  static const Set<String> emergencyTypes = <String>{
    'accident_pre_alert',
    'emergency_report_sent',
    'status_change',
    'incident_status_change',
  };

  static const Set<String> krokaTypes = <String>{typeKrokaReportSaved};

  static const Set<String> systemTypes = <String>{
    'offline_sync_success',
    'battery_low',
    'system_notice',
  };

  static const Set<String> allowedPriorities = <String>{
    'low',
    'normal',
    'high',
    'critical',
  };

  /// Safely create from Firestore document.
  factory NotificationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final now = DateTime.now();

    return NotificationModel(
      id: doc.id,
      type: _normalizeType(_stringValue(data['type'])),
      titleAr: _stringValue(data['titleAr']) ?? '',
      titleEn: _stringValue(data['titleEn']) ?? '',
      bodyAr: _stringValue(data['bodyAr']) ?? '',
      bodyEn: _stringValue(data['bodyEn']) ?? '',
      isRead: _boolValue(data['isRead']) ?? false,
      priority: _normalizePriority(_stringValue(data['priority'])),
      source: _normalizeSource(_stringValue(data['source'])),
      relatedAccidentId: _stringValue(data['relatedAccidentId']),
      payload: _mapValue(data['payload']),
      createdAt: _dateTimeValue(data['createdAt']) ?? now,
      updatedAt: _dateTimeValue(data['updatedAt']) ?? now,
      readAt: _dateTimeValue(data['readAt']),
    );
  }

  /// Normal map if we need to serialize an existing model.
  ///
  /// For creating new Firestore docs, prefer [toCreateMap] because it uses
  /// server timestamps.
  Map<String, dynamic> toFirestore() {
    return _removeNullValues({
      'type': _normalizeType(type),
      'titleAr': titleAr.trim(),
      'titleEn': titleEn.trim(),
      'bodyAr': bodyAr.trim(),
      'bodyEn': bodyEn.trim(),
      'isRead': isRead,
      'priority': _normalizePriority(priority),
      'source': _normalizeSource(source),
      'relatedAccidentId': relatedAccidentId,
      'payload': _jsonSafeMap(payload),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'readAt': readAt == null ? null : Timestamp.fromDate(readAt!),
    });
  }

  /// Map for creating a new notification document.
  ///
  /// This keeps time consistent with Firestore server time.
  static Map<String, dynamic> toCreateMap({
    required String type,
    required String titleAr,
    required String titleEn,
    required String bodyAr,
    required String bodyEn,
    required String priority,
    required String source,
    String? relatedAccidentId,
    Map<String, dynamic>? payload,
  }) {
    return _removeNullValues({
      'type': _normalizeType(type),
      'titleAr': titleAr.trim(),
      'titleEn': titleEn.trim(),
      'bodyAr': bodyAr.trim(),
      'bodyEn': bodyEn.trim(),
      'isRead': false,
      'priority': _normalizePriority(priority),
      'source': _normalizeSource(source),
      'relatedAccidentId': _stringValue(relatedAccidentId),
      'payload': _jsonSafeMap(payload ?? const <String, dynamic>{}),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'readAt': null,
    });
  }

  NotificationModel copyWith({
    String? id,
    String? type,
    String? titleAr,
    String? titleEn,
    String? bodyAr,
    String? bodyEn,
    bool? isRead,
    String? priority,
    String? source,
    String? relatedAccidentId,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? readAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type != null ? _normalizeType(type) : this.type,
      titleAr: titleAr ?? this.titleAr,
      titleEn: titleEn ?? this.titleEn,
      bodyAr: bodyAr ?? this.bodyAr,
      bodyEn: bodyEn ?? this.bodyEn,
      isRead: isRead ?? this.isRead,
      priority: priority != null ? _normalizePriority(priority) : this.priority,
      source: source != null ? _normalizeSource(source) : this.source,
      relatedAccidentId: relatedAccidentId ?? this.relatedAccidentId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      readAt: readAt ?? this.readAt,
    );
  }

  String localizedTitle(String languageCode) {
    final isArabic = languageCode.toLowerCase().startsWith('ar');

    if (isArabic) {
      return titleAr.trim().isNotEmpty ? titleAr.trim() : titleEn.trim();
    }

    return titleEn.trim().isNotEmpty ? titleEn.trim() : titleAr.trim();
  }

  String localizedBody(String languageCode) {
    final isArabic = languageCode.toLowerCase().startsWith('ar');

    if (isArabic) {
      return bodyAr.trim().isNotEmpty ? bodyAr.trim() : bodyEn.trim();
    }

    return bodyEn.trim().isNotEmpty ? bodyEn.trim() : bodyAr.trim();
  }

  NotificationCategory get category {
    if (isSafeArrivalNotification) return NotificationCategory.safeArrival;
    if (isEmergencyNotification) return NotificationCategory.emergency;
    if (isKrokaNotification) return NotificationCategory.kroka;
    return NotificationCategory.system;
  }

  bool get isSafeArrivalNotification {
    return safeArrivalTypes.contains(type) || source == 'safe_arrival';
  }

  bool get isEmergencyNotification {
    return emergencyTypes.contains(type) ||
        source == 'emergency' ||
        source == 'sos' ||
        source == 'auto_detection' ||
        source == 'accident_detection';
  }

  bool get isKrokaNotification {
    return krokaTypes.contains(type) || source == 'kroka';
  }

  bool get isSystemNotification {
    return category == NotificationCategory.system;
  }

  bool get isUnread => !isRead;

  bool get isCriticalPriority => priority == 'critical';

  bool get isHighPriority {
    return priority == 'high' || priority == 'critical';
  }

  bool get isNormalPriority => priority == 'normal';

  bool get isLowPriority => priority == 'low';

  bool get isSyncConfirmation => type == 'offline_sync_success';

  bool get isBatteryWarning => type == 'battery_low';

  bool get isSafeArrivalDanger => type == 'safe_arrival_danger';

  bool get isSafeArrivalArrived => type == 'safe_arrival_arrived';

  bool get isKrokaReportSaved => type == typeKrokaReportSaved;

  String? get safeArrivalTripId {
    final value = payload['tripId']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? get destinationName {
    final value = payload['destinationName']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? get krokaReportId {
    final value = payload['krokaReportId']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? get krokaReferenceCode {
    final value = payload['referenceCode']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  // ==========================================
  // Safe parsing helpers
  // ==========================================

  static String? _stringValue(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  static String _normalizeType(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();

    if (normalized == null || normalized.isEmpty) {
      return typeSystemNotice;
    }

    if (safeArrivalTypes.contains(normalized) ||
        emergencyTypes.contains(normalized) ||
        krokaTypes.contains(normalized) ||
        systemTypes.contains(normalized)) {
      return normalized;
    }

    return typeSystemNotice;
  }

  static String _normalizePriority(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();

    if (normalized != null && allowedPriorities.contains(normalized)) {
      return normalized;
    }

    return 'normal';
  }

  static String _normalizeSource(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();

    if (normalized == null || normalized.isEmpty) {
      return 'system';
    }

    return normalized;
  }

  static bool? _boolValue(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      final normalized = value.trim().toLowerCase();

      if (['true', '1', 'yes', 'y'].contains(normalized)) return true;
      if (['false', '0', 'no', 'n'].contains(normalized)) return false;
    }

    return null;
  }

  static Map<String, dynamic> _mapValue(dynamic value) {
    if (value == null || value is! Map) {
      return const <String, dynamic>{};
    }

    return _jsonSafeMap(
      value.map((key, dynamic mapValue) => MapEntry(key.toString(), mapValue)),
    );
  }

  static DateTime? _dateTimeValue(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value.trim());
    }

    return null;
  }

  static Map<String, dynamic> _jsonSafeMap(Map<String, dynamic> input) {
    if (input.isEmpty) {
      return const <String, dynamic>{};
    }

    final output = <String, dynamic>{};

    input.forEach((key, value) {
      final safeKey = key.trim();

      if (safeKey.isEmpty) return;

      final safeValue = _jsonSafeValue(value);

      if (safeValue != null) {
        output[safeKey] = safeValue;
      }
    });

    return output;
  }

  static dynamic _jsonSafeValue(dynamic value) {
    if (value == null) return null;

    if (value is String || value is bool) {
      return value;
    }

    if (value is num) {
      if (value.isNaN || value.isInfinite) return null;
      return value;
    }

    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is List) {
      return value
          .map(_jsonSafeValue)
          .where((element) => element != null)
          .toList();
    }

    if (value is Map) {
      return _jsonSafeMap(
        value.map(
          (key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
        ),
      );
    }

    return value.toString();
  }

  static Map<String, dynamic> _removeNullValues(Map<String, dynamic> map) {
    final result = Map<String, dynamic>.from(map);
    result.removeWhere((_, value) => value == null);
    return result;
  }
}

enum NotificationCategory { all, safeArrival, emergency, kroka, system }
