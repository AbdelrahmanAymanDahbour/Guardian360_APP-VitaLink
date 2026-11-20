import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_thresholds.dart';
import 'safe_arrival_destination_model.dart';
import 'safe_arrival_report_model.dart';

/// ==========================================
/// 🛡️ Safe Arrival Trip Model
/// ==========================================
/// Represents the full lifecycle of a Safe Arrival trip.
///
/// This is intentionally separate from core TripModel because Safe Arrival
/// has different business semantics:
/// - trusted destination
/// - family notification metadata
/// - arrival detection
/// - GPS tracking health
/// - pause/resume lifecycle
/// - danger escalation
class SafeArrivalTripModel {
  final String id;
  final String userId;
  final SafeArrivalTripStatus status;

  final SafeArrivalDestinationModel? destination;

  final double? startLatitude;
  final double? startLongitude;
  final String? startLocationName;

  final double? currentLatitude;
  final double? currentLongitude;
  final String? currentLocationName;

  final double? endLatitude;
  final double? endLongitude;
  final String? endLocationName;

  final double? estimatedDistanceMeters;
  final int? estimatedDurationSeconds;
  final DateTime? estimatedArrivalAt;

  final double actualDistanceMeters;
  final double? distanceToDestinationMeters;
  final double arrivalRadiusMeters;

  final String? selectedContactName;
  final String? selectedContactPhone;
  final String? whatsappMessage;
  final DateTime? familyNotifiedAt;

  final SafeArrivalReportModel? report;

  final String? dangerReason;
  final String? pauseReason;
  final String? finishReason;

  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? arrivedAt;
  final DateTime? cancelledAt;
  final DateTime? dangerTriggeredAt;
  final DateTime? pausedAt;
  final DateTime? resumedAt;
  final DateTime? manualFinishedAt;
  final DateTime? updatedAt;

  const SafeArrivalTripModel({
    required this.id,
    required this.userId,
    required this.status,
    this.destination,
    this.startLatitude,
    this.startLongitude,
    this.startLocationName,
    this.currentLatitude,
    this.currentLongitude,
    this.currentLocationName,
    this.endLatitude,
    this.endLongitude,
    this.endLocationName,
    this.estimatedDistanceMeters,
    this.estimatedDurationSeconds,
    this.estimatedArrivalAt,
    this.actualDistanceMeters = 0.0,
    this.distanceToDestinationMeters,
    this.arrivalRadiusMeters = AppThresholds.safeArrivalRadiusMeters,
    this.selectedContactName,
    this.selectedContactPhone,
    this.whatsappMessage,
    this.familyNotifiedAt,
    this.report,
    this.dangerReason,
    this.pauseReason,
    this.finishReason,
    required this.createdAt,
    this.startedAt,
    this.arrivedAt,
    this.cancelledAt,
    this.dangerTriggeredAt,
    this.pausedAt,
    this.resumedAt,
    this.manualFinishedAt,
    this.updatedAt,
  });

  factory SafeArrivalTripModel.createDraft({
    required String userId,
    SafeArrivalDestinationModel? destination,
    String? selectedContactName,
    String? selectedContactPhone,
  }) {
    final now = DateTime.now();

    return SafeArrivalTripModel(
      id: 'safe_arrival_${now.microsecondsSinceEpoch}',
      userId: _cleanText(userId),
      status: SafeArrivalTripStatus.draft,
      destination: destination,
      selectedContactName: _stringOrNull(selectedContactName),
      selectedContactPhone: _stringOrNull(selectedContactPhone),
      createdAt: now,
      updatedAt: now,
    );
  }

  factory SafeArrivalTripModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    if (data == null) {
      throw StateError(
        'SafeArrivalTrip document data is null for id: ${doc.id}',
      );
    }

    final resolvedId = _stringOrFallback(data['id'], fallback: doc.id);

    return SafeArrivalTripModel.fromMap({...data, 'id': resolvedId});
  }

  factory SafeArrivalTripModel.fromMap(Map<String, dynamic> map) {
    final destinationMap = _asStringKeyMap(map['destination']);
    final reportMap = _asStringKeyMap(map['report']);

    final destination = destinationMap != null
        ? SafeArrivalDestinationModel.fromMap(destinationMap)
        : _destinationFromFlatFields(map);

    return SafeArrivalTripModel(
      id: _stringOrFallback(map['id']),
      userId: _stringOrFallback(map['userId']),
      status: SafeArrivalTripStatus.fromString(
        _stringOrFallback(
          map['status'],
          fallback: SafeArrivalTripStatus.draft.value,
        ),
      ),
      destination: destination,
      startLatitude: _toDouble(map['startLatitude']),
      startLongitude: _toDouble(map['startLongitude']),
      startLocationName: _stringOrNull(map['startLocationName']),
      currentLatitude: _toDouble(map['currentLatitude']),
      currentLongitude: _toDouble(map['currentLongitude']),
      currentLocationName: _stringOrNull(map['currentLocationName']),
      endLatitude: _toDouble(map['endLatitude']),
      endLongitude: _toDouble(map['endLongitude']),
      endLocationName: _stringOrNull(map['endLocationName']),
      estimatedDistanceMeters: _safeNullableDistance(
        _toDouble(map['estimatedDistanceMeters']),
      ),
      estimatedDurationSeconds: _safeNullableDurationSeconds(
        _toIntOrNull(map['estimatedDurationSeconds']),
      ),
      estimatedArrivalAt: _toDateTime(map['estimatedArrivalAt']),
      actualDistanceMeters: _safeDistance(
        _toDouble(map['actualDistanceMeters']) ?? 0.0,
      ),
      distanceToDestinationMeters: _safeNullableDistance(
        _toDouble(map['distanceToDestinationMeters']),
      ),
      arrivalRadiusMeters: _safeArrivalRadius(
        _toDouble(map['arrivalRadiusMeters']),
      ),
      selectedContactName: _stringOrNull(map['selectedContactName']),
      selectedContactPhone: _stringOrNull(map['selectedContactPhone']),
      whatsappMessage: _stringOrNull(map['whatsappMessage']),
      familyNotifiedAt: _toDateTime(map['familyNotifiedAt']),
      report: reportMap != null
          ? SafeArrivalReportModel.fromMap(reportMap)
          : null,
      dangerReason: _stringOrNull(map['dangerReason']),
      pauseReason: _stringOrNull(map['pauseReason']),
      finishReason: _stringOrNull(map['finishReason']),
      createdAt: _toDateTime(map['createdAt']) ?? DateTime.now(),
      startedAt: _toDateTime(map['startedAt']),
      arrivedAt: _toDateTime(map['arrivedAt']),
      cancelledAt: _toDateTime(map['cancelledAt']),
      dangerTriggeredAt: _toDateTime(map['dangerTriggeredAt']),
      pausedAt: _toDateTime(map['pausedAt']),
      resumedAt: _toDateTime(map['resumedAt']),
      manualFinishedAt: _toDateTime(map['manualFinishedAt']),
      updatedAt: _toDateTime(map['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    final destinationData = destination?.toMap();

    return _removeNullValues({
      'id': id,
      'userId': userId,
      'status': status.value,

      'destination': destinationData,
      'destinationPlaceId': destination?.placeId,
      'destinationName': destination?.name,
      'destinationAddress': destination?.address,
      'destinationLatitude': destination?.latitude,
      'destinationLongitude': destination?.longitude,
      'destinationLocation': destination?.hasValidCoordinates == true
          ? GeoPoint(destination!.latitude, destination!.longitude)
          : null,

      'startLatitude': startLatitude,
      'startLongitude': startLongitude,
      'startLocation': _geoPointOrNull(startLatitude, startLongitude),
      'startLocationName': startLocationName,

      'currentLatitude': currentLatitude,
      'currentLongitude': currentLongitude,
      'currentLocation': _geoPointOrNull(currentLatitude, currentLongitude),
      'currentLocationName': currentLocationName,

      'endLatitude': endLatitude,
      'endLongitude': endLongitude,
      'endLocation': _geoPointOrNull(endLatitude, endLongitude),
      'endLocationName': endLocationName,

      'estimatedDistanceMeters': estimatedDistanceMeters,
      'estimatedDurationSeconds': estimatedDurationSeconds,
      'estimatedArrivalAt': estimatedArrivalAt != null
          ? Timestamp.fromDate(estimatedArrivalAt!)
          : null,

      'actualDistanceMeters': actualDistanceMeters,
      'distanceToDestinationMeters': distanceToDestinationMeters,
      'arrivalRadiusMeters': arrivalRadiusMeters,

      'selectedContactName': selectedContactName,
      'selectedContactPhone': selectedContactPhone,
      'whatsappMessage': whatsappMessage,
      'familyNotifiedAt': familyNotifiedAt != null
          ? Timestamp.fromDate(familyNotifiedAt!)
          : null,

      'report': report?.toMap(),
      'safetyLevel': report?.safetyLevel,
      'safetyScore': report?.safetyScore,
      'safetyRating': report?.ratingLabel,
      'guardianReport': report?.guardianReport,

      'dangerReason': dangerReason,
      'pauseReason': pauseReason,
      'finishReason': finishReason,

      'createdAt': Timestamp.fromDate(createdAt),
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'arrivedAt': arrivedAt != null ? Timestamp.fromDate(arrivedAt!) : null,
      'cancelledAt': cancelledAt != null
          ? Timestamp.fromDate(cancelledAt!)
          : null,
      'dangerTriggeredAt': dangerTriggeredAt != null
          ? Timestamp.fromDate(dangerTriggeredAt!)
          : null,
      'pausedAt': pausedAt != null ? Timestamp.fromDate(pausedAt!) : null,
      'resumedAt': resumedAt != null ? Timestamp.fromDate(resumedAt!) : null,
      'manualFinishedAt': manualFinishedAt != null
          ? Timestamp.fromDate(manualFinishedAt!)
          : null,
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : FieldValue.serverTimestamp(),
    });
  }

  SafeArrivalTripModel copyWith({
    String? id,
    String? userId,
    SafeArrivalTripStatus? status,
    SafeArrivalDestinationModel? destination,
    double? startLatitude,
    double? startLongitude,
    String? startLocationName,
    double? currentLatitude,
    double? currentLongitude,
    String? currentLocationName,
    double? endLatitude,
    double? endLongitude,
    String? endLocationName,
    double? estimatedDistanceMeters,
    int? estimatedDurationSeconds,
    DateTime? estimatedArrivalAt,
    double? actualDistanceMeters,
    double? distanceToDestinationMeters,
    double? arrivalRadiusMeters,
    String? selectedContactName,
    String? selectedContactPhone,
    String? whatsappMessage,
    DateTime? familyNotifiedAt,
    SafeArrivalReportModel? report,
    String? dangerReason,
    String? pauseReason,
    String? finishReason,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? arrivedAt,
    DateTime? cancelledAt,
    DateTime? dangerTriggeredAt,
    DateTime? pausedAt,
    DateTime? resumedAt,
    DateTime? manualFinishedAt,
    DateTime? updatedAt,
  }) {
    return SafeArrivalTripModel(
      id: id != null ? _cleanText(id) : this.id,
      userId: userId != null ? _cleanText(userId) : this.userId,
      status: status ?? this.status,
      destination: destination ?? this.destination,
      startLatitude: startLatitude ?? this.startLatitude,
      startLongitude: startLongitude ?? this.startLongitude,
      startLocationName: startLocationName != null
          ? _cleanText(startLocationName)
          : this.startLocationName,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      currentLocationName: currentLocationName != null
          ? _cleanText(currentLocationName)
          : this.currentLocationName,
      endLatitude: endLatitude ?? this.endLatitude,
      endLongitude: endLongitude ?? this.endLongitude,
      endLocationName: endLocationName != null
          ? _cleanText(endLocationName)
          : this.endLocationName,
      estimatedDistanceMeters: estimatedDistanceMeters != null
          ? _safeNullableDistance(estimatedDistanceMeters)
          : this.estimatedDistanceMeters,
      estimatedDurationSeconds: estimatedDurationSeconds != null
          ? _safeNullableDurationSeconds(estimatedDurationSeconds)
          : this.estimatedDurationSeconds,
      estimatedArrivalAt: estimatedArrivalAt ?? this.estimatedArrivalAt,
      actualDistanceMeters: actualDistanceMeters != null
          ? _safeDistance(actualDistanceMeters)
          : this.actualDistanceMeters,
      distanceToDestinationMeters: distanceToDestinationMeters != null
          ? _safeNullableDistance(distanceToDestinationMeters)
          : this.distanceToDestinationMeters,
      arrivalRadiusMeters: arrivalRadiusMeters != null
          ? _safeArrivalRadius(arrivalRadiusMeters)
          : this.arrivalRadiusMeters,
      selectedContactName: selectedContactName != null
          ? _cleanText(selectedContactName)
          : this.selectedContactName,
      selectedContactPhone: selectedContactPhone != null
          ? _cleanText(selectedContactPhone)
          : this.selectedContactPhone,
      whatsappMessage: whatsappMessage != null
          ? _cleanText(whatsappMessage)
          : this.whatsappMessage,
      familyNotifiedAt: familyNotifiedAt ?? this.familyNotifiedAt,
      report: report ?? this.report,
      dangerReason: dangerReason != null
          ? _cleanText(dangerReason)
          : this.dangerReason,
      pauseReason: pauseReason != null
          ? _cleanText(pauseReason)
          : this.pauseReason,
      finishReason: finishReason != null
          ? _cleanText(finishReason)
          : this.finishReason,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      dangerTriggeredAt: dangerTriggeredAt ?? this.dangerTriggeredAt,
      pausedAt: pausedAt ?? this.pausedAt,
      resumedAt: resumedAt ?? this.resumedAt,
      manualFinishedAt: manualFinishedAt ?? this.manualFinishedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get hasValidId => id.trim().isNotEmpty;

  bool get hasValidUser => userId.trim().isNotEmpty;

  bool get hasTrustedDestination => destination?.isValid == true;

  bool get hasStartLocation {
    return _hasValidCoordinates(startLatitude, startLongitude);
  }

  bool get hasCurrentLocation {
    return _hasValidCoordinates(currentLatitude, currentLongitude);
  }

  bool get hasEndLocation {
    return _hasValidCoordinates(endLatitude, endLongitude);
  }

  bool get hasEstimatedRoute {
    return estimatedDistanceMeters != null &&
        estimatedDistanceMeters! > 0 &&
        estimatedDurationSeconds != null &&
        estimatedDurationSeconds! > 0;
  }

  bool get hasArrivalEstimate {
    return estimatedArrivalAt != null || hasEstimatedRoute;
  }

  bool get hasSelectedContact {
    final phone = selectedContactPhone?.trim();
    return phone != null && phone.isNotEmpty;
  }

  bool get hasReport {
    return report != null && report?.isPending == false;
  }

  bool get hasWhatsappMessage {
    return whatsappMessage?.trim().isNotEmpty == true;
  }

  bool get isDraft => status == SafeArrivalTripStatus.draft;

  bool get isReady => status == SafeArrivalTripStatus.ready;

  bool get isActive => status == SafeArrivalTripStatus.tracking;

  bool get isPaused => status == SafeArrivalTripStatus.paused;

  bool get isDanger => status == SafeArrivalTripStatus.danger;

  bool get isArrived => status == SafeArrivalTripStatus.arrived;

  bool get isCancelled => status == SafeArrivalTripStatus.cancelled;

  bool get isFailed => status == SafeArrivalTripStatus.failed;

  bool get isOperational {
    return status == SafeArrivalTripStatus.ready ||
        status == SafeArrivalTripStatus.tracking ||
        status == SafeArrivalTripStatus.paused ||
        status == SafeArrivalTripStatus.danger;
  }

  bool get isClosed => status.isClosed;

  bool get canResume {
    return status == SafeArrivalTripStatus.paused;
  }

  bool get canCancel {
    return !status.isClosed &&
        status != SafeArrivalTripStatus.draft &&
        status != SafeArrivalTripStatus.arrived;
  }

  bool get canMarkArrived {
    return status == SafeArrivalTripStatus.tracking ||
        status == SafeArrivalTripStatus.paused ||
        status == SafeArrivalTripStatus.danger;
  }

  int? get elapsedSeconds {
    final start = startedAt;
    if (start == null) return null;

    final end =
        arrivedAt ??
        manualFinishedAt ??
        cancelledAt ??
        (status.isClosed ? updatedAt : null) ??
        DateTime.now();

    final seconds = end.difference(start).inSeconds;

    return seconds < 0 ? 0 : seconds;
  }

  DateTime? get effectiveEndAt {
    return arrivedAt ??
        manualFinishedAt ??
        cancelledAt ??
        (status.isClosed ? updatedAt : null);
  }

  GeoPoint? get currentGeoPoint {
    return _geoPointOrNull(currentLatitude, currentLongitude);
  }

  GeoPoint? get startGeoPoint {
    return _geoPointOrNull(startLatitude, startLongitude);
  }

  GeoPoint? get endGeoPoint {
    return _geoPointOrNull(endLatitude, endLongitude);
  }

  static SafeArrivalDestinationModel? _destinationFromFlatFields(
    Map<String, dynamic> map,
  ) {
    final placeId = _stringOrNull(map['destinationPlaceId']);
    final name = _stringOrNull(map['destinationName']);
    final address = _stringOrNull(map['destinationAddress']);
    final latitude = _toDouble(map['destinationLatitude']);
    final longitude = _toDouble(map['destinationLongitude']);

    if (placeId == null &&
        name == null &&
        address == null &&
        latitude == null &&
        longitude == null) {
      return null;
    }

    return SafeArrivalDestinationModel(
      placeId: placeId ?? '',
      name: name ?? '',
      address: address ?? '',
      latitude: latitude ?? 0.0,
      longitude: longitude ?? 0.0,
    );
  }

  static GeoPoint? _geoPointOrNull(double? latitude, double? longitude) {
    if (!_hasValidCoordinates(latitude, longitude)) return null;
    return GeoPoint(latitude!, longitude!);
  }

  static bool _hasValidCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;

    return !latitude.isNaN &&
        !latitude.isInfinite &&
        !longitude.isNaN &&
        !longitude.isInfinite &&
        latitude >= -90.0 &&
        latitude <= 90.0 &&
        longitude >= -180.0 &&
        longitude <= 180.0 &&
        !(latitude == 0.0 && longitude == 0.0);
  }

  static String _cleanText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) return null;

    final text = _cleanText(value.toString());
    return text.isEmpty ? null : text;
  }

  static String _stringOrFallback(dynamic value, {String fallback = ''}) {
    return _stringOrNull(value) ?? fallback;
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

  static int? _toIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();

    if (value is String) {
      return int.tryParse(value.trim());
    }

    return null;
  }

  static int? _safeNullableDurationSeconds(int? value) {
    if (value == null || value <= 0) return null;
    return value;
  }

  static double _safeDistance(double value) {
    if (value.isNaN || value.isInfinite || value < 0.0) return 0.0;
    return value;
  }

  static double? _safeNullableDistance(double? value) {
    if (value == null || value.isNaN || value.isInfinite || value < 0.0) {
      return null;
    }

    return value;
  }

  static double _safeArrivalRadius(double? value) {
    if (value == null || value.isNaN || value.isInfinite || value <= 0.0) {
      return AppThresholds.safeArrivalRadiusMeters;
    }

    return value;
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

  static Map<String, dynamic>? _asStringKeyMap(dynamic value) {
    if (value is! Map) return null;

    return value.map(
      (key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
    );
  }

  static Map<String, dynamic> _removeNullValues(Map<String, dynamic> map) {
    final result = Map<String, dynamic>.from(map);
    result.removeWhere((_, value) => value == null);
    return result;
  }

  @override
  String toString() {
    return 'SafeArrivalTripModel('
        'id: $id, '
        'userId: $userId, '
        'status: ${status.value}, '
        'destination: ${destination?.displayName}, '
        'actualDistanceMeters: $actualDistanceMeters'
        ')';
  }
}

enum SafeArrivalTripStatus {
  draft('draft'),
  ready('ready'),
  tracking('tracking'),
  paused('paused'),
  arrived('arrived'),
  danger('danger'),
  cancelled('cancelled'),
  failed('failed');

  final String value;
  const SafeArrivalTripStatus(this.value);

  static SafeArrivalTripStatus fromString(String value) {
    switch (value.trim().toLowerCase()) {
      case 'draft':
        return SafeArrivalTripStatus.draft;
      case 'ready':
        return SafeArrivalTripStatus.ready;
      case 'tracking':
      case 'active':
        return SafeArrivalTripStatus.tracking;
      case 'paused':
      case 'pause':
        return SafeArrivalTripStatus.paused;
      case 'arrived':
      case 'completed':
      case 'manual_finished':
      case 'manually_finished':
      case 'finished':
        return SafeArrivalTripStatus.arrived;
      case 'danger':
      case 'emergency':
      case 'alert':
        return SafeArrivalTripStatus.danger;
      case 'cancelled':
      case 'canceled':
      case 'user_cancelled':
        return SafeArrivalTripStatus.cancelled;
      case 'failed':
      case 'error':
        return SafeArrivalTripStatus.failed;
      default:
        return SafeArrivalTripStatus.draft;
    }
  }

  bool get isClosed {
    switch (this) {
      case SafeArrivalTripStatus.arrived:
      case SafeArrivalTripStatus.cancelled:
      case SafeArrivalTripStatus.failed:
        return true;
      case SafeArrivalTripStatus.draft:
      case SafeArrivalTripStatus.ready:
      case SafeArrivalTripStatus.tracking:
      case SafeArrivalTripStatus.paused:
      case SafeArrivalTripStatus.danger:
        return false;
    }
  }

  bool get isOpen {
    return !isClosed;
  }
}
