import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/app_thresholds.dart';

/// ==========================================
/// 🚨 Alert Model - Guardian 360
/// ==========================================
/// Unified data contract for Guardian 360 emergency alerts.
///
/// Supports:
/// - Manual SOS
/// - Auto Accident Detection
/// - Accident projections from `accidents`
/// - Croquis
/// - Safe Arrival Emergency
/// - Firestore
/// - Web Dashboard
///
/// Architecture note:
/// - `accidents` is the official emergency source of truth.
/// - `alerts` can be a read/dashboard projection.
/// - This model keeps old flat fields and supports new nested snapshots.
class AlertModel {
  static const int currentSchemaVersion = 2;
  static const Object _unset = Object();

  final String id;
  final String? accidentId;
  final String userId;
  final String? tripId;

  /// Main alert timestamp.
  final DateTime timestamp;

  /// Firestore/document creation time.
  final DateTime? createdAt;

  /// Last update time.
  final DateTime? updatedAt;

  final AlertStatus status;
  final AlertSeverity severity;

  /// Source enum used by app logic.
  final AlertSource source;

  /// Machine-safe emergency source:
  /// auto_detection / manual_sos / croquis / safe_arrival / unknown
  final String emergencySource;

  /// Compatibility aliases for dashboards/services.
  final String alertSource;
  final String reportType;

  /// Original raw severity if present.
  final String rawSeverity;

  /// Human-readable severity label.
  final String severityDisplay;

  /// Schema version for migration safety.
  final int schemaVersion;

  // ==========================================
  // Accident / alert data
  // ==========================================

  final double gForce;
  final double rotation;
  final double severityScore;
  final String detectionReason;

  /// Kept for backward compatibility.
  final bool autoDetected;

  /// Whether this alert document was projected from an accident document.
  final bool isProjection;

  /// Projection source, usually `accidents`.
  final String? projectionSource;

  // ==========================================
  // Location
  // ==========================================

  final double latitude;
  final double longitude;

  /// Human-readable location name (city / area). Populated via reverse geocoding.
  final String? locationAddress;

  /// Detailed address string (street, district). Populated via reverse geocoding.
  final String? locationDetails;

  // ==========================================
  // User snapshot - flat compatibility fields
  // ==========================================

  final String userName;
  final String userPhone;
  final String? userEmail;

  // ==========================================
  // Medical snapshot - flat compatibility fields
  // ==========================================

  final String? bloodType;
  final String? chronicDiseases;
  final String? medications;
  final String? allergies;
  final String? nationalId;
  final String? address;
  final String? weight;
  final String? height;
  final DateTime? dateOfBirth;
  final int? age;
  final bool? isOrganDonor;
  final String? medicalNotes;

  // ==========================================
  // Nested snapshots
  // ==========================================

  final Map<String, dynamic> userSnapshot;
  final Map<String, dynamic> medicalSnapshot;
  final List<EmergencyContactSnapshot> emergencyContacts;
  final Map<String, dynamic> additionalData;

  // ==========================================
  // Response information
  // ==========================================

  final DateTime? userResponseTime;

  /// kept as String for backward compatibility:
  /// safe / need_help / no_response
  final String? userResponse;

  final DateTime? resolvedTime;
  final String? resolvedBy;
  final String? notes;

  AlertModel({
    required this.id,
    this.accidentId,
    required this.userId,
    this.tripId,
    required this.timestamp,
    this.createdAt,
    this.updatedAt,
    required this.status,
    required this.severity,
    this.source = AlertSource.autoDetection,
    String? emergencySource,
    String? alertSource,
    String? reportType,
    String? rawSeverity,
    String? severityDisplay,
    this.schemaVersion = currentSchemaVersion,
    required this.gForce,
    required this.rotation,
    required this.severityScore,
    required this.detectionReason,
    this.autoDetected = true,
    this.isProjection = false,
    this.projectionSource,
    required this.latitude,
    required this.longitude,
    this.locationAddress,
    this.locationDetails,
    required this.userName,
    required this.userPhone,
    this.userEmail,
    this.bloodType,
    this.chronicDiseases,
    this.medications,
    this.allergies,
    this.nationalId,
    this.address,
    this.weight,
    this.height,
    this.dateOfBirth,
    this.age,
    this.isOrganDonor,
    this.medicalNotes,
    Map<String, dynamic> userSnapshot = const {},
    Map<String, dynamic> medicalSnapshot = const {},
    List<EmergencyContactSnapshot> emergencyContacts = const [],
    Map<String, dynamic> additionalData = const {},
    this.userResponseTime,
    this.userResponse,
    this.resolvedTime,
    this.resolvedBy,
    this.notes,
  }) : emergencySource = emergencySource ?? source.value,
       alertSource = alertSource ?? emergencySource ?? source.value,
       reportType = reportType ?? emergencySource ?? source.value,
       rawSeverity = rawSeverity ?? severity.value,
       severityDisplay = severityDisplay ?? severity.displayNameArabic,
       userSnapshot = Map.unmodifiable(userSnapshot),
       medicalSnapshot = Map.unmodifiable(medicalSnapshot),
       emergencyContacts = List.unmodifiable(emergencyContacts),
       additionalData = Map.unmodifiable(additionalData);

  // ==========================================
  // Factory Constructors
  // ==========================================

  factory AlertModel.create({
    String? id,
    String? accidentId,
    required String userId,
    String? tripId,
    AlertSource source = AlertSource.autoDetection,
    bool? autoDetected,
    AlertSeverity? severity,
    DateTime? timestamp,
    required double gForce,
    required double rotation,
    required double severityScore,
    required String detectionReason,
    required double latitude,
    required double longitude,
    String? locationAddress,
    String? locationDetails,
    required String userName,
    required String userPhone,
    String? userEmail,
    String? bloodType,
    String? chronicDiseases,
    String? medications,
    String? allergies,
    String? nationalId,
    String? address,
    String? weight,
    String? height,
    DateTime? dateOfBirth,
    int? age,
    bool? isOrganDonor,
    String? medicalNotes,
    List<EmergencyContactSnapshot>? emergencyContacts,
  }) {
    final createdTimestamp = timestamp ?? DateTime.now();
    final safeScore = _safeScore(severityScore);
    final resolvedSeverity = severity ?? AlertSeverity.fromScore(safeScore);
    final resolvedAutoDetected =
        autoDetected ?? source == AlertSource.autoDetection;

    final resolvedEmergencySource = source.value;

    final medicalSnapshot = _removeNullValues({
      'bloodType': bloodType,
      'chronicDiseases': chronicDiseases,
      'medications': medications,
      'allergies': allergies,
      'nationalId': nationalId,
      'address': address,
      'weight': weight,
      'height': height,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'age': age,
      'isOrganDonor': isOrganDonor,
      'notes': medicalNotes,
    });

    final userSnapshot = _removeNullValues({
      'userId': userId,
      'fullName': userName,
      'userName': userName,
      'phone': userPhone,
      'userPhone': userPhone,
      'email': userEmail,
      'userEmail': userEmail,
      ...medicalSnapshot,
      'emergencyContacts': (emergencyContacts ?? const [])
          .map((e) => e.toMap())
          .toList(),
    });

    return AlertModel(
      id: id ?? 'alert_${DateTime.now().microsecondsSinceEpoch}',
      accidentId: accidentId,
      userId: userId,
      tripId: tripId,
      timestamp: createdTimestamp,
      createdAt: createdTimestamp,
      status: AlertStatus.active,
      severity: resolvedSeverity,
      source: source,
      emergencySource: resolvedEmergencySource,
      alertSource: resolvedEmergencySource,
      reportType: resolvedEmergencySource,
      rawSeverity: resolvedSeverity.value,
      severityDisplay: resolvedSeverity.displayNameArabic,
      schemaVersion: currentSchemaVersion,
      gForce: gForce,
      rotation: rotation,
      severityScore: safeScore,
      detectionReason: detectionReason,
      autoDetected: resolvedAutoDetected,
      latitude: latitude,
      longitude: longitude,
      locationAddress: locationAddress,
      locationDetails: locationDetails,
      userName: userName,
      userPhone: userPhone,
      userEmail: userEmail,
      bloodType: bloodType,
      chronicDiseases: chronicDiseases,
      medications: medications,
      allergies: allergies,
      nationalId: nationalId,
      address: address,
      weight: weight,
      height: height,
      dateOfBirth: dateOfBirth,
      age: age,
      isOrganDonor: isOrganDonor,
      medicalNotes: medicalNotes,
      userSnapshot: userSnapshot,
      medicalSnapshot: medicalSnapshot,
      emergencyContacts: emergencyContacts ?? const [],
    );
  }

  factory AlertModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    if (data == null) {
      throw StateError('Alert document "${doc.id}" has no data.');
    }

    return AlertModel.fromMap({...data, 'id': doc.id});
  }

  factory AlertModel.fromMap(Map<String, dynamic> map) {
    final userSnapshot = _asStringKeyMap(map['userSnapshot']) ?? const {};
    final medicalSnapshot = _asStringKeyMap(map['medicalSnapshot']) ?? const {};
    final additionalData = _asStringKeyMap(map['additionalData']) ?? const {};

    final locationValue = map['location'];
    final locationMap = _asStringKeyMap(locationValue);
    final geoPoint = locationValue is GeoPoint ? locationValue : null;

    final rawEmergencySource = _toNullableString(
      map['emergencySource'] ??
          map['alertSource'] ??
          map['reportType'] ??
          map['source'],
    );

    final parsedAutoDetected = _toBool(
      map['autoDetected'],
      fallback: rawEmergencySource == 'manual_sos' ? false : true,
    );

    final parsedSource = AlertSource.fromValue(
      map['source'] ?? rawEmergencySource,
      autoDetected: parsedAutoDetected,
    );

    final resolvedEmergencySource = _normalizeEmergencySource(
      rawEmergencySource,
      fallbackSource: parsedSource,
      autoDetected: parsedAutoDetected,
    );

    final parsedTimestamp =
        _toDateTime(map['timestamp'] ?? map['createdAt']) ?? DateTime.now();

    final rawSeverityValue =
        map['rawSeverity'] ?? map['severity'] ?? map['severityLevel'];

    final parsedSeverity = AlertSeverity.fromValue(rawSeverityValue);
    final safeScore = _safeScore(
      _toDouble(map['severityScore'] ?? map['score']),
    );

    final dob = _toDateTime(
      map['dateOfBirth'] ??
          medicalSnapshot['dateOfBirth'] ??
          userSnapshot['dateOfBirth'],
    );

    final resolvedAge =
        _toNullableInt(
          map['age'] ?? medicalSnapshot['age'] ?? userSnapshot['age'],
        ) ??
        (dob != null ? _calculateAge(dob) : null);

    final parsedEmergencyContacts = _parseEmergencyContacts(
      map['emergencyContactsSnapshot'] ??
          map['emergencyContacts'] ??
          userSnapshot['emergencyContacts'],
    );

    final latitude = _toDouble(
      map['latitude'] ??
          map['lat'] ??
          locationMap?['latitude'] ??
          locationMap?['lat'] ??
          geoPoint?.latitude,
    );

    final longitude = _toDouble(
      map['longitude'] ??
          map['lng'] ??
          map['lon'] ??
          locationMap?['longitude'] ??
          locationMap?['lng'] ??
          locationMap?['lon'] ??
          geoPoint?.longitude,
    );

    return AlertModel(
      id: _toStringValue(map['id']),
      accidentId: _toNullableString(map['accidentId']),
      userId: _toStringValue(map['userId'] ?? userSnapshot['userId']),
      tripId: _toNullableString(map['tripId']),
      timestamp: parsedTimestamp,
      createdAt: _toDateTime(map['createdAt'] ?? map['timestamp']),
      updatedAt: _toDateTime(map['updatedAt']),
      status: AlertStatus.fromValue(map['status']),
      severity: parsedSeverity,
      source: parsedSource,
      emergencySource: resolvedEmergencySource,
      alertSource:
          _toNullableString(map['alertSource']) ?? resolvedEmergencySource,
      reportType:
          _toNullableString(map['reportType']) ?? resolvedEmergencySource,
      rawSeverity: _toNullableString(rawSeverityValue) ?? parsedSeverity.value,
      severityDisplay:
          _toNullableString(map['severityDisplay']) ??
          AppThresholds.severityDisplayArabic(parsedSeverity.value),
      schemaVersion: _toInt(map['schemaVersion'], fallback: 1),
      gForce: _toDouble(map['gForce']),
      rotation: _toDouble(map['rotation']),
      severityScore: safeScore,
      detectionReason: _toStringValue(map['detectionReason'] ?? map['reason']),
      autoDetected: _toBool(
        map['autoDetected'],
        fallback: parsedSource == AlertSource.autoDetection,
      ),
      isProjection: _toBool(map['isProjection'], fallback: false),
      projectionSource: _toNullableString(map['projectionSource']),
      latitude: latitude,
      longitude: longitude,
      locationAddress: _toNullableString(
        map['locationName'] ??
            map['locationAddress'] ??
            locationMap?['address'],
      ),
      locationDetails: _toNullableString(
        map['locationDetails'] ?? locationMap?['details'],
      ),
      userName: _toStringValue(
        map['userName'] ??
            userSnapshot['userName'] ??
            userSnapshot['fullName'] ??
            userSnapshot['name'],
      ),
      userPhone: _toStringValue(
        map['userPhone'] ?? userSnapshot['userPhone'] ?? userSnapshot['phone'],
      ),
      userEmail: _toNullableString(
        map['userEmail'] ?? userSnapshot['userEmail'] ?? userSnapshot['email'],
      ),
      bloodType: _toNullableString(
        map['bloodType'] ??
            medicalSnapshot['bloodType'] ??
            userSnapshot['bloodType'],
      ),
      chronicDiseases: _toNullableString(
        map['chronicDiseases'] ??
            medicalSnapshot['chronicDiseases'] ??
            userSnapshot['chronicDiseases'],
      ),
      medications: _toNullableString(
        map['medications'] ??
            medicalSnapshot['medications'] ??
            userSnapshot['medications'],
      ),
      allergies: _toNullableString(
        map['allergies'] ??
            medicalSnapshot['allergies'] ??
            userSnapshot['allergies'],
      ),
      nationalId: _toNullableString(
        map['nationalId'] ??
            medicalSnapshot['nationalId'] ??
            userSnapshot['nationalId'],
      ),
      address: _toNullableString(
        map['address'] ?? medicalSnapshot['address'] ?? userSnapshot['address'],
      ),
      weight: _toNullableString(
        map['weight'] ?? medicalSnapshot['weight'] ?? userSnapshot['weight'],
      ),
      height: _toNullableString(
        map['height'] ?? medicalSnapshot['height'] ?? userSnapshot['height'],
      ),
      dateOfBirth: dob,
      age: resolvedAge,
      isOrganDonor: _toNullableBool(
        map['isOrganDonor'] ??
            medicalSnapshot['isOrganDonor'] ??
            userSnapshot['isOrganDonor'],
      ),
      medicalNotes: _toNullableString(
        map['medicalNotes'] ??
            map['notes'] ??
            medicalSnapshot['medicalNotes'] ??
            medicalSnapshot['notes'] ??
            userSnapshot['medicalNotes'] ??
            userSnapshot['notes'],
      ),
      userSnapshot: Map<String, dynamic>.from(userSnapshot),
      medicalSnapshot: Map<String, dynamic>.from(medicalSnapshot),
      emergencyContacts: parsedEmergencyContacts,
      additionalData: Map<String, dynamic>.from(additionalData),
      userResponseTime: _toDateTime(map['userResponseTime']),
      userResponse: _toNullableString(map['userResponse']),
      resolvedTime: _toDateTime(map['resolvedTime']),
      resolvedBy: _toNullableString(map['resolvedBy']),
      notes: _toNullableString(map['notes']),
    );
  }

  // ==========================================
  // To Map / Firestore
  // ==========================================

  Map<String, dynamic> toMap() {
    final contacts = emergencyContacts.map((e) => e.toMap()).toList();

    return _removeNullValues({
      'id': id,
      'accidentId': accidentId,
      'userId': userId,
      'tripId': tripId,
      'timestamp': timestamp.toIso8601String(),
      'createdAt': (createdAt ?? timestamp).toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'status': status.value,
      'severity': severity.value,
      'rawSeverity': rawSeverity,
      'severityDisplay': severityDisplay,
      'source': source.value,
      'emergencySource': emergencySource,
      'alertSource': alertSource,
      'reportType': reportType,
      'schemaVersion': schemaVersion,
      'gForce': gForce,
      'rotation': rotation,
      'severityScore': severityScore,
      'detectionReason': detectionReason,
      'autoDetected': autoDetected,
      'isProjection': isProjection,
      'projectionSource': projectionSource,
      'latitude': latitude,
      'longitude': longitude,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
        'address': locationAddress,
        'details': locationDetails,
      },
      'locationAddress': locationAddress,
      'locationName': locationAddress,
      'locationDetails': locationDetails,
      'userName': userName,
      'userPhone': userPhone,
      'userEmail': userEmail,
      'bloodType': bloodType,
      'chronicDiseases': chronicDiseases,
      'medications': medications,
      'allergies': allergies,
      'nationalId': nationalId,
      'address': address,
      'weight': weight,
      'height': height,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'age': age,
      'isOrganDonor': isOrganDonor,
      'medicalNotes': medicalNotes,
      'emergencyContacts': contacts,
      'emergencyContactsSnapshot': contacts,
      'userSnapshot': _mergedUserSnapshot(),
      'medicalSnapshot': _mergedMedicalSnapshot(),
      'additionalData': additionalData.isEmpty ? null : additionalData,
      'userResponseTime': userResponseTime?.toIso8601String(),
      'userResponse': userResponse,
      'resolvedTime': resolvedTime?.toIso8601String(),
      'resolvedBy': resolvedBy,
      'notes': notes,
    });
  }

  Map<String, dynamic> toFirestore() {
    final contacts = emergencyContacts.map((e) => e.toMap()).toList();

    return _removeNullValues({
      'id': id,
      'accidentId': accidentId,
      'userId': userId,
      'tripId': tripId,
      'timestamp': Timestamp.fromDate(timestamp),
      'createdAt': Timestamp.fromDate(createdAt ?? timestamp),
      'updatedAt': FieldValue.serverTimestamp(),
      'status': status.value,
      'severity': severity.value,
      'rawSeverity': rawSeverity,
      'severityDisplay': severityDisplay,
      'source': source.value,
      'emergencySource': emergencySource,
      'alertSource': alertSource,
      'reportType': reportType,
      'schemaVersion': schemaVersion,
      'gForce': gForce,
      'rotation': rotation,
      'severityScore': severityScore,
      'detectionReason': detectionReason,
      'autoDetected': autoDetected,
      'isProjection': isProjection,
      'projectionSource': projectionSource,

      // Location
      'latitude': latitude,
      'longitude': longitude,
      'locationAddress': locationAddress,
      'locationName': locationAddress,
      'locationDetails': locationDetails,
      'location': GeoPoint(latitude, longitude),

      // Backward-compatible user flat fields
      'userName': userName,
      'userPhone': userPhone,
      'userEmail': userEmail,
      'bloodType': bloodType,
      'chronicDiseases': chronicDiseases,
      'medications': medications,
      'allergies': allergies,
      'nationalId': nationalId,
      'address': address,
      'weight': weight,
      'height': height,
      'dateOfBirth': dateOfBirth != null
          ? Timestamp.fromDate(dateOfBirth!)
          : null,
      'age': age,
      'isOrganDonor': isOrganDonor,
      'medicalNotes': medicalNotes,
      'emergencyContacts': contacts,
      'emergencyContactsSnapshot': contacts,

      // Preferred snapshots
      'userSnapshot': _mergedUserSnapshot(),
      'medicalSnapshot': _mergedMedicalSnapshot(),

      'additionalData': additionalData.isEmpty ? null : additionalData,

      'userResponseTime': userResponseTime != null
          ? Timestamp.fromDate(userResponseTime!)
          : null,
      'userResponse': userResponse,
      'resolvedTime': resolvedTime != null
          ? Timestamp.fromDate(resolvedTime!)
          : null,
      'resolvedBy': resolvedBy,
      'notes': notes,
    });
  }

  Map<String, dynamic> _mergedUserSnapshot() {
    return _removeNullValues({
      ...userSnapshot,
      'userId': userId,
      'fullName': userName,
      'userName': userName,
      'phone': userPhone,
      'userPhone': userPhone,
      'email': userEmail,
      'userEmail': userEmail,
      'bloodType': bloodType,
      'emergencyContacts': emergencyContacts.map((e) => e.toMap()).toList(),
    });
  }

  Map<String, dynamic> _mergedMedicalSnapshot() {
    return _removeNullValues({
      ...medicalSnapshot,
      'bloodType': bloodType,
      'chronicDiseases': chronicDiseases,
      'medications': medications,
      'allergies': allergies,
      'nationalId': nationalId,
      'address': address,
      'weight': weight,
      'height': height,
      'dateOfBirth': dateOfBirth?.toIso8601String(),
      'age': age,
      'isOrganDonor': isOrganDonor,
      'notes': medicalNotes,
      'medicalNotes': medicalNotes,
    });
  }

  // ==========================================
  // Copy With
  // ==========================================

  AlertModel copyWith({
    String? id,
    Object? accidentId = _unset,
    String? userId,
    Object? tripId = _unset,
    DateTime? timestamp,
    Object? createdAt = _unset,
    Object? updatedAt = _unset,
    AlertStatus? status,
    AlertSeverity? severity,
    AlertSource? source,
    String? emergencySource,
    String? alertSource,
    String? reportType,
    String? rawSeverity,
    String? severityDisplay,
    int? schemaVersion,
    double? gForce,
    double? rotation,
    double? severityScore,
    String? detectionReason,
    bool? autoDetected,
    bool? isProjection,
    Object? projectionSource = _unset,
    double? latitude,
    double? longitude,
    Object? locationAddress = _unset,
    Object? locationDetails = _unset,
    String? userName,
    String? userPhone,
    Object? userEmail = _unset,
    Object? bloodType = _unset,
    Object? chronicDiseases = _unset,
    Object? medications = _unset,
    Object? allergies = _unset,
    Object? nationalId = _unset,
    Object? address = _unset,
    Object? weight = _unset,
    Object? height = _unset,
    Object? dateOfBirth = _unset,
    Object? age = _unset,
    Object? isOrganDonor = _unset,
    Object? medicalNotes = _unset,
    Map<String, dynamic>? userSnapshot,
    Map<String, dynamic>? medicalSnapshot,
    List<EmergencyContactSnapshot>? emergencyContacts,
    Map<String, dynamic>? additionalData,
    Object? userResponseTime = _unset,
    Object? userResponse = _unset,
    Object? resolvedTime = _unset,
    Object? resolvedBy = _unset,
    Object? notes = _unset,
  }) {
    return AlertModel(
      id: id ?? this.id,
      accidentId: identical(accidentId, _unset)
          ? this.accidentId
          : accidentId as String?,
      userId: userId ?? this.userId,
      tripId: identical(tripId, _unset) ? this.tripId : tripId as String?,
      timestamp: timestamp ?? this.timestamp,
      createdAt: identical(createdAt, _unset)
          ? this.createdAt
          : createdAt as DateTime?,
      updatedAt: identical(updatedAt, _unset)
          ? this.updatedAt
          : updatedAt as DateTime?,
      status: status ?? this.status,
      severity: severity ?? this.severity,
      source: source ?? this.source,
      emergencySource: emergencySource ?? this.emergencySource,
      alertSource: alertSource ?? this.alertSource,
      reportType: reportType ?? this.reportType,
      rawSeverity: rawSeverity ?? this.rawSeverity,
      severityDisplay: severityDisplay ?? this.severityDisplay,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      gForce: gForce ?? this.gForce,
      rotation: rotation ?? this.rotation,
      severityScore: severityScore ?? this.severityScore,
      detectionReason: detectionReason ?? this.detectionReason,
      autoDetected: autoDetected ?? this.autoDetected,
      isProjection: isProjection ?? this.isProjection,
      projectionSource: identical(projectionSource, _unset)
          ? this.projectionSource
          : projectionSource as String?,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationAddress: identical(locationAddress, _unset)
          ? this.locationAddress
          : locationAddress as String?,
      locationDetails: identical(locationDetails, _unset)
          ? this.locationDetails
          : locationDetails as String?,
      userName: userName ?? this.userName,
      userPhone: userPhone ?? this.userPhone,
      userEmail: identical(userEmail, _unset)
          ? this.userEmail
          : userEmail as String?,
      bloodType: identical(bloodType, _unset)
          ? this.bloodType
          : bloodType as String?,
      chronicDiseases: identical(chronicDiseases, _unset)
          ? this.chronicDiseases
          : chronicDiseases as String?,
      medications: identical(medications, _unset)
          ? this.medications
          : medications as String?,
      allergies: identical(allergies, _unset)
          ? this.allergies
          : allergies as String?,
      nationalId: identical(nationalId, _unset)
          ? this.nationalId
          : nationalId as String?,
      address: identical(address, _unset) ? this.address : address as String?,
      weight: identical(weight, _unset) ? this.weight : weight as String?,
      height: identical(height, _unset) ? this.height : height as String?,
      dateOfBirth: identical(dateOfBirth, _unset)
          ? this.dateOfBirth
          : dateOfBirth as DateTime?,
      age: identical(age, _unset) ? this.age : age as int?,
      isOrganDonor: identical(isOrganDonor, _unset)
          ? this.isOrganDonor
          : isOrganDonor as bool?,
      medicalNotes: identical(medicalNotes, _unset)
          ? this.medicalNotes
          : medicalNotes as String?,
      userSnapshot: userSnapshot ?? this.userSnapshot,
      medicalSnapshot: medicalSnapshot ?? this.medicalSnapshot,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
      additionalData: additionalData ?? this.additionalData,
      userResponseTime: identical(userResponseTime, _unset)
          ? this.userResponseTime
          : userResponseTime as DateTime?,
      userResponse: identical(userResponse, _unset)
          ? this.userResponse
          : userResponse as String?,
      resolvedTime: identical(resolvedTime, _unset)
          ? this.resolvedTime
          : resolvedTime as DateTime?,
      resolvedBy: identical(resolvedBy, _unset)
          ? this.resolvedBy
          : resolvedBy as String?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
    );
  }

  // ==========================================
  // Helpers
  // ==========================================

  bool get isActive => status == AlertStatus.active;

  bool get hasUserResponse => userResponse != null && userResponse!.isNotEmpty;

  bool get isResolved =>
      status == AlertStatus.resolved || status == AlertStatus.falseAlarm;

  bool get isCritical => severity == AlertSeverity.critical;

  bool get isHighRisk =>
      severity == AlertSeverity.high || severity == AlertSeverity.critical;

  bool get isManual =>
      source == AlertSource.manualSos || emergencySource == 'manual_sos';

  bool get isAutoDetected =>
      source == AlertSource.autoDetection ||
      emergencySource == 'auto_detection' ||
      autoDetected;

  bool get hasValidLocation =>
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180 &&
      !(latitude == 0.0 && longitude == 0.0);

  bool get hasMedicalSnapshot =>
      bloodType?.trim().isNotEmpty == true ||
      chronicDiseases?.trim().isNotEmpty == true ||
      medications?.trim().isNotEmpty == true ||
      allergies?.trim().isNotEmpty == true ||
      medicalSnapshot.isNotEmpty;

  bool get hasEmergencyContacts => emergencyContacts.isNotEmpty;

  bool get needsImmediateResponse => isHighRisk && status == AlertStatus.active;

  int? get responseTimeSeconds {
    if (userResponseTime == null) return null;
    final seconds = userResponseTime!.difference(timestamp).inSeconds;
    return seconds < 0 ? 0 : seconds;
  }

  static List<EmergencyContactSnapshot> _parseEmergencyContacts(dynamic value) {
    if (value is! List) return const [];

    final contacts = <EmergencyContactSnapshot>[];

    for (final item in value) {
      final itemMap = _asStringKeyMap(item);
      if (itemMap == null) continue;
      contacts.add(EmergencyContactSnapshot.fromMap(itemMap));
    }

    return List.unmodifiable(contacts);
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) {
      final result = value.toDouble();
      return result.isNaN || result.isInfinite ? fallback : result;
    }
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      if (parsed == null || parsed.isNaN || parsed.isInfinite) {
        return fallback;
      }
      return parsed;
    }
    return fallback;
  }

  static double _safeScore(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    return value.clamp(0.0, 100.0).toDouble();
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    return _toNullableInt(value) ?? fallback;
  }

  static int? _toNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
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

  static bool? _toNullableBool(dynamic value) {
    if (value == null) return null;
    return _toBool(value, fallback: false);
  }

  static String _toStringValue(dynamic value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static String? _toNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
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

  static String _normalizeEmergencySource(
    String? value, {
    required AlertSource fallbackSource,
    required bool autoDetected,
  }) {
    final normalized = value?.trim().toLowerCase();

    if (normalized == 'manual_sos' || normalized == 'auto_detection') {
      return normalized!;
    }

    switch (fallbackSource) {
      case AlertSource.manualSos:
        return 'manual_sos';
      case AlertSource.autoDetection:
        return 'auto_detection';
      case AlertSource.croquis:
        return 'croquis';
      case AlertSource.safeArrival:
        return 'safe_arrival';
      case AlertSource.unknown:
        return autoDetected ? 'auto_detection' : 'manual_sos';
    }
  }

  static int _calculateAge(DateTime dateOfBirth) {
    final now = DateTime.now();
    var age = now.year - dateOfBirth.year;

    final hadBirthdayThisYear =
        now.month > dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day >= dateOfBirth.day);

    if (!hadBirthdayThisYear) {
      age--;
    }

    return age.clamp(0, 130);
  }
}

/// ==========================================
/// 🚦 Alert Status Enum
/// ==========================================
enum AlertStatus {
  active('active'),
  responded('responded'),
  resolved('resolved'),
  falseAlarm('false_alarm'),
  escalated('escalated');

  final String value;
  const AlertStatus(this.value);

  static AlertStatus fromString(String value) => fromValue(value);

  static AlertStatus fromValue(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';

    switch (normalized) {
      case 'active':
      case 'open':
      case 'new':
      case 'pending':
        return AlertStatus.active;
      case 'responded':
      case 'response_received':
        return AlertStatus.responded;
      case 'resolved':
      case 'closed':
      case 'done':
        return AlertStatus.resolved;
      case 'false_alarm':
      case 'falsealarm':
      case 'cancelled':
      case 'canceled':
        return AlertStatus.falseAlarm;
      case 'escalated':
        return AlertStatus.escalated;
      default:
        return AlertStatus.active;
    }
  }

  String get displayName {
    switch (this) {
      case AlertStatus.active:
        return 'نشط';
      case AlertStatus.responded:
        return 'تم الرد';
      case AlertStatus.resolved:
        return 'تم الحل';
      case AlertStatus.falseAlarm:
        return 'إنذار كاذب';
      case AlertStatus.escalated:
        return 'تم التصعيد';
    }
  }
}

/// ==========================================
/// ⚠️ Alert Severity Enum
/// ==========================================
enum AlertSeverity {
  low('low'),
  medium('medium'),
  high('high'),
  critical('critical');

  final String value;
  const AlertSeverity(this.value);

  static AlertSeverity fromScore(double score) {
    final safeScore = score.isNaN || score.isInfinite
        ? 0.0
        : score.clamp(0.0, 100.0).toDouble();

    if (safeScore >= AppThresholds.severityScoreCritical) {
      return AlertSeverity.critical;
    }
    if (safeScore >= AppThresholds.severityScoreHigh) {
      return AlertSeverity.high;
    }
    if (safeScore >= AppThresholds.severityScoreMedium) {
      return AlertSeverity.medium;
    }
    return AlertSeverity.low;
  }

  static AlertSeverity fromString(String value) => fromValue(value);

  static AlertSeverity fromValue(dynamic value) {
    final normalized = AppThresholds.normalizeSeverityLevel(
      value?.toString() ?? '',
    );

    switch (normalized) {
      case AppThresholds.severityCritical:
        return AlertSeverity.critical;
      case AppThresholds.severityHigh:
        return AlertSeverity.high;
      case AppThresholds.severityMedium:
        return AlertSeverity.medium;
      case AppThresholds.severityLow:
      case AppThresholds.severityIgnored:
      default:
        return AlertSeverity.low;
    }
  }

  String get displayName {
    switch (this) {
      case AlertSeverity.low:
        return 'منخفض';
      case AlertSeverity.medium:
        return 'متوسط';
      case AlertSeverity.high:
        return 'عالي';
      case AlertSeverity.critical:
        return 'حرج';
    }
  }

  String get displayNameArabic {
    switch (this) {
      case AlertSeverity.low:
        return 'خفيف';
      case AlertSeverity.medium:
        return 'متوسط';
      case AlertSeverity.high:
        return 'خطير';
      case AlertSeverity.critical:
        return 'حرج جداً';
    }
  }
}

/// ==========================================
/// 🧭 Alert Source Enum
/// ==========================================
enum AlertSource {
  autoDetection('auto_detection'),
  manualSos('manual_sos'),
  croquis('croquis'),
  safeArrival('safe_arrival'),
  unknown('unknown');

  final String value;
  const AlertSource(this.value);

  static AlertSource fromString(String value) => fromValue(value);

  static AlertSource fromValue(dynamic value, {bool? autoDetected}) {
    final normalized = value?.toString().trim().toLowerCase() ?? '';

    switch (normalized) {
      case 'auto_detection':
      case 'autodetection':
      case 'auto':
      case 'sensor':
      case 'sensors':
      case 'accident_detection':
        return AlertSource.autoDetection;
      case 'manual_sos':
      case 'manual':
      case 'sos':
      case 'manual_sos_button':
        return AlertSource.manualSos;
      case 'croquis':
      case 'kroka':
      case 'minor_accident':
        return AlertSource.croquis;
      case 'safe_arrival':
      case 'safearrival':
      case 'trip':
        return AlertSource.safeArrival;
      default:
        if (autoDetected == true) return AlertSource.autoDetection;
        if (autoDetected == false) return AlertSource.manualSos;
        return AlertSource.unknown;
    }
  }

  String get displayNameArabic {
    switch (this) {
      case AlertSource.autoDetection:
        return 'استشعار تلقائي';
      case AlertSource.manualSos:
        return 'استغاثة يدوية';
      case AlertSource.croquis:
        return 'كروكا';
      case AlertSource.safeArrival:
        return 'الوصول الآمن';
      case AlertSource.unknown:
        return 'غير معروف';
    }
  }
}

/// ==========================================
/// 📞 Emergency Contact Snapshot
/// ==========================================
class EmergencyContactSnapshot {
  final String name;
  final String phone;
  final String? relation;
  final bool isPrimary;
  final int? priority;

  const EmergencyContactSnapshot({
    required this.name,
    required this.phone,
    this.relation,
    this.isPrimary = false,
    this.priority,
  });

  factory EmergencyContactSnapshot.fromMap(Map<String, dynamic> map) {
    return EmergencyContactSnapshot(
      name: map['name']?.toString().trim() ?? '',
      phone: map['phone']?.toString().trim() ?? '',
      relation: _toNullableString(map['relation']),
      isPrimary: _toBool(map['isPrimary'], fallback: false),
      priority: _toNullableInt(map['priority']),
    );
  }

  Map<String, dynamic> toMap() {
    final result = <String, dynamic>{
      'name': name,
      'phone': phone,
      'relation': relation,
      'isPrimary': isPrimary,
      'priority': priority,
    };

    result.removeWhere((_, value) => value == null);
    return result;
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

  static int? _toNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String? _toNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
