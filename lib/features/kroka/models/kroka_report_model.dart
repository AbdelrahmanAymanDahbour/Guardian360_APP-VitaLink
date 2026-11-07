import 'package:cloud_firestore/cloud_firestore.dart';

import 'accident_evidence_model.dart';
import 'driver_license_model.dart';
import 'vehicle_plate_model.dart';

class KrokaReportModel {
  const KrokaReportModel({
    required this.reportId,
    required this.referenceCode,
    required this.userId,
    required this.status,
    required this.damagePoint,
    required this.damageZone,
    this.damageZones = const [],
    required this.damageSide,
    required this.damageLabelKey,
    required this.faultEstimate,
    required this.myVehiclePlate,
    this.otherVehiclePlate,
    this.myDriverLicense,
    this.otherDriverLicense,
    required this.latitude,
    required this.longitude,
    required this.locationAccuracyMeters,
    this.locationName,
    this.speedKmhAtCapture,
    this.headingDegreesAtCapture,
    this.notes,
    this.evidenceItems = const [],
    required this.locationCapturedAtClient,
    required this.submittedAtClient,
  });

  final String reportId;
  final String referenceCode;
  final String userId;
  final String status;

  /// Backward-compatible general side: front/back/left/right.
  final String damagePoint;

  /// Primary precise damage zone, e.g. front_left, right_rear_door.
  final String damageZone;

  /// All selected damage zones (multi-zone support).
  /// The primary zone is always at index 0.
  final List<String> damageZones;

  /// General side derived from the precise zone.
  final String damageSide;

  /// Localization key for the selected damage zone.
  final String damageLabelKey;

  /// User-provided non-official liability estimate.
  final String faultEstimate;

  final VehiclePlateModel myVehiclePlate;
  final VehiclePlateModel? otherVehiclePlate;

  /// Driver license verification is supportive, not a legal decision.
  /// It helps police/insurance review the report faster when parties agree.
  final DriverLicenseModel? myDriverLicense;
  final DriverLicenseModel? otherDriverLicense;

  final double latitude;
  final double longitude;
  final double locationAccuracyMeters;
  final String? locationName;

  final double? speedKmhAtCapture;
  final double? headingDegreesAtCapture;

  final String? notes;

  /// Accident evidence prepared for professional report generation.
  ///
  /// Only Firestore-safe evidence will be persisted by [toFirestoreMap].
  /// Local media paths are intentionally not saved in cloud reports.
  final List<AccidentEvidenceModel> evidenceItems;

  final DateTime locationCapturedAtClient;
  final DateTime submittedAtClient;

  static const int schemaVersion = 3;
  static const int damageSchemaVersion = 2;
  static const int evidenceSchemaVersion = 2;
  static const int driverLicenseSchemaVersion = 1;

  static const String reportType = 'minor_traffic_accident';
  static const String source = 'mobile_app';

  Map<String, dynamic> toFirestoreMap() {
    final safeLocationCapturedAt = locationCapturedAtClient.toUtc();
    final safeSubmittedAt = submittedAtClient.toUtc();

    final reportDelaySeconds = _safeDelaySeconds(
      from: safeLocationCapturedAt,
      to: safeSubmittedAt,
    );

    // ── Split evidence by purpose ─────────────────────────────────────────
    // vehicle_data holds plate/license OCR evidence.
    // accident_evidence holds general scene photos, videos, and witness notes.
    final categorized = _categorizeEvidence(evidenceItems);

    final safeGeneralItems = _firestoreSafeEvidenceItems(categorized.general);
    final safePlateItems = _firestoreSafeEvidenceItems(categorized.plate);
    final safeLicenseItems = _firestoreSafeEvidenceItems(categorized.license);

    final generalMaps =
        safeGeneralItems.map((e) => e.toMap()).toList(growable: false);
    final plateMaps =
        safePlateItems.map((e) => e.toMap()).toList(growable: false);
    final licenseMaps =
        safeLicenseItems.map((e) => e.toMap()).toList(growable: false);

    // ── vehicle_data sub-document ─────────────────────────────────────────
    final vehicleData = _removeNullValues({
      // Plate models (structured OCR-validated data).
      'myVehiclePlate': myVehiclePlate.toMap(),
      'otherVehiclePlate': otherVehiclePlate?.toMap(),
      // Driver license scan results.
      'driverLicenseSchemaVersion': driverLicenseSchemaVersion,
      'driverLicenseVerifications': _buildDriverLicenseVerifications(),
      'driverLicenseSummary': _buildDriverLicenseSummary(),
      // OCR evidence files captured specifically for plates / licenses.
      'plateScanEvidence': plateMaps,
      'licenseScanEvidence': licenseMaps,
    });

    // ── accident_evidence sub-document ────────────────────────────────────
    final accidentEvidence = <String, dynamic>{
      'schemaVersion': evidenceSchemaVersion,
      'items': generalMaps,
      'summary': _buildEvidenceSummary(safeGeneralItems),
    };
    _removeNullValuesMutating(accidentEvidence);

    return _removeNullValues({
      'id': reportId,
      'reportId': reportId,
      'referenceCode': referenceCode,
      'userId': userId,
      'schemaVersion': schemaVersion,
      'reportType': reportType,
      'source': source,
      'status': status,

      // ── Damage schema ───────────────────────────────────────────────────
      'damagePoint': damagePoint,
      'damageSide': damageSide,
      'damageZone': damageZone,
      // Multi-zone support — primary zone is always at index 0.
      'damageZones': damageZones.isEmpty ? [damageZone] : damageZones,
      'damageLabelKey': damageLabelKey,
      'damageSchemaVersion': damageSchemaVersion,

      // Liability estimate is user-provided and non-official.
      'faultEstimate': faultEstimate,

      // ── Vehicle & license data (structured, separated from scene evidence)
      // Top-level plate fields kept for backward compatibility with rules.
      'myVehiclePlate': myVehiclePlate.toMap(),
      'otherVehiclePlate': otherVehiclePlate?.toMap(),
      // Nested vehicle_data holds all plate/license data + OCR evidence.
      'vehicle_data': vehicleData,

      // ── Location ────────────────────────────────────────────────────────
      'location': GeoPoint(latitude, longitude),
      'latitude': latitude,
      'longitude': longitude,
      'locationAccuracyMeters': locationAccuracyMeters,
      'locationName': _stringOrNull(locationName),

      // User notes.
      'notes': _stringOrNull(notes),

      // ── Accident evidence (scene only — no plate/license scans here) ────
      'evidenceSchemaVersion': evidenceSchemaVersion,
      'accident_evidence': accidentEvidence,
      // Legacy flat list kept for compatibility — contains same general items.
      'evidenceItems': generalMaps,
      'evidenceSummary': _buildEvidenceSummary(safeGeneralItems),

      // Client-side timestamps are kept as evidence context.
      'locationCapturedAtClient': Timestamp.fromDate(safeLocationCapturedAt),
      'submittedAtClient': Timestamp.fromDate(safeSubmittedAt),

      // Neutral review signals for insurance/report review.
      'insuranceSignals': _removeNullValues({
        'locationAccuracyMeters': locationAccuracyMeters,
        'speedKmhAtCapture': speedKmhAtCapture,
        'headingDegreesAtCapture': headingDegreesAtCapture,
        'isSpeedAvailable': speedKmhAtCapture != null,
        'isHeadingAvailable': headingDegreesAtCapture != null,
        'locationCapturedAtClient': Timestamp.fromDate(safeLocationCapturedAt),
        'submittedAtClient': Timestamp.fromDate(safeSubmittedAt),
        'reportDelaySeconds': reportDelaySeconds,
        'myVehiclePlateKey': myVehiclePlate.normalizedKey,
        'otherVehiclePlateKey': otherVehiclePlate?.normalizedKey,
        'isOtherVehiclePlateProvided': otherVehiclePlate != null,
        'damageZone': damageZone,
        'damageZones': damageZones.isEmpty ? [damageZone] : damageZones,
        'damageSide': damageSide,
        'damageLabelKey': damageLabelKey,
        'evidenceSchemaVersion': evidenceSchemaVersion,
        'evidenceCount': safeGeneralItems.length,
        'hasEvidence': safeGeneralItems.isNotEmpty,
        'vehicleDataPlateScanCount': safePlateItems.length,
        'vehicleDataLicenseScanCount': safeLicenseItems.length,
        'driverLicenseSchemaVersion': driverLicenseSchemaVersion,
        'myDriverLicenseStatus': myDriverLicense?.status,
        'otherDriverLicenseStatus': otherDriverLicense?.status,
        'hasMyDriverLicenseEvidence': myDriverLicense?.hasEvidence,
        'hasOtherDriverLicenseEvidence': otherDriverLicense?.hasEvidence,
      }),

      // Server timestamps are the authoritative cloud save timestamps.
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  Map<String, dynamic>? _buildDriverLicenseVerifications() {
    final verifications = _removeNullValues({
      DriverLicenseRole.myDriver: myDriverLicense?.toMap(),
      DriverLicenseRole.otherDriver: otherDriverLicense?.toMap(),
    });

    if (verifications.isEmpty) return null;

    return verifications;
  }

  Map<String, dynamic>? _buildDriverLicenseSummary() {
    if (myDriverLicense == null && otherDriverLicense == null) return null;

    return _removeNullValues({
      'schemaVersion': driverLicenseSchemaVersion,
      'myDriverStatus': myDriverLicense?.status,
      'otherDriverStatus': otherDriverLicense?.status,
      'myDriverSource': myDriverLicense?.source,
      'otherDriverSource': otherDriverLicense?.source,
      'myDriverVerified': myDriverLicense?.isVerified,
      'otherDriverVerified': otherDriverLicense?.isVerified,
      'myDriverHasEvidence': myDriverLicense?.hasEvidence,
      'otherDriverHasEvidence': otherDriverLicense?.hasEvidence,
    });
  }

  List<AccidentEvidenceModel> _firestoreSafeEvidenceItems(
    List<AccidentEvidenceModel> items,
  ) {
    if (items.isEmpty) return const [];

    final sortedItems = items
        .where(_isFirestoreSafeEvidence)
        .toList(growable: true);

    if (sortedItems.isEmpty) return const [];

    sortedItems.sort((a, b) {
      final sortOrderCompare = a.sortOrder.compareTo(b.sortOrder);

      if (sortOrderCompare != 0) return sortOrderCompare;

      return a.capturedAtClient.compareTo(b.capturedAtClient);
    });

    final seenIds = <String>{};
    final uniqueItems = <AccidentEvidenceModel>[];

    for (final item in sortedItems) {
      final safeId = item.id.trim();

      if (safeId.isEmpty) continue;

      if (seenIds.add(safeId)) {
        uniqueItems.add(item);
      }
    }

    return List<AccidentEvidenceModel>.unmodifiable(uniqueItems);
  }

  /// Splits evidence into three purpose-based buckets:
  ///   - [general]  → scene photos, videos, damage shots, witness statements
  ///   - [plate]    → vehicle plate OCR captures
  ///   - [license]  → driver license scan captures
  ({List<AccidentEvidenceModel> general,
    List<AccidentEvidenceModel> plate,
    List<AccidentEvidenceModel> license}) _categorizeEvidence(
    List<AccidentEvidenceModel> items,
  ) {
    final general = <AccidentEvidenceModel>[];
    final plate = <AccidentEvidenceModel>[];
    final license = <AccidentEvidenceModel>[];

    for (final item in items) {
      switch (item.purpose) {
        case AccidentEvidencePurpose.vehiclePlate:
          plate.add(item);
        case AccidentEvidencePurpose.driverLicense:
          license.add(item);
        default:
          // general, damage_photo, witness, unknown → scene evidence.
          general.add(item);
      }
    }

    return (general: general, plate: plate, license: license);
  }

  bool _isFirestoreSafeEvidence(AccidentEvidenceModel evidence) {
    if (!evidence.isValid) return false;

    if (evidence.isMedia) {
      return evidence.hasRemoteReference;
    }

    if (evidence.isWitnessStatement) {
      return true;
    }

    return false;
  }

  Map<String, dynamic>? _buildEvidenceSummary(
    List<AccidentEvidenceModel> items,
  ) {
    if (items.isEmpty) return null;

    return {
      'total': items.length,
      'images': _countEvidenceType(items, AccidentEvidenceType.image),
      'videos': _countEvidenceType(items, AccidentEvidenceType.video),
      'audios': _countEvidenceType(items, AccidentEvidenceType.audio),
      'witnessStatements': _countEvidenceType(
        items,
        AccidentEvidenceType.witnessStatement,
      ),
      'uploaded': items.where((evidence) => evidence.isUploaded).length,
      'local': items
          .where((evidence) => evidence.status == AccidentEvidenceStatus.local)
          .length,
      'vehiclePlateEvidence': items
          .where(
            (evidence) =>
                evidence.purpose == AccidentEvidencePurpose.vehiclePlate,
          )
          .length,
      'driverLicenseEvidence': items
          .where(
            (evidence) =>
                evidence.purpose == AccidentEvidencePurpose.driverLicense,
          )
          .length,
      'cameraCaptured': items
          .where(
            (evidence) =>
                evidence.captureSource ==
                    AccidentEvidenceCaptureSource.camera ||
                evidence.captureSource ==
                    AccidentEvidenceCaptureSource.ocrCamera,
          )
          .length,
      'gallerySelected': items
          .where(
            (evidence) =>
                evidence.captureSource ==
                    AccidentEvidenceCaptureSource.gallery ||
                evidence.captureSource ==
                    AccidentEvidenceCaptureSource.ocrGallery,
          )
          .length,
    };
  }

  int _countEvidenceType(List<AccidentEvidenceModel> items, String type) {
    return items.where((evidence) => evidence.type == type).length;
  }

  int _safeDelaySeconds({required DateTime from, required DateTime to}) {
    final rawSeconds = to.difference(from).inSeconds;

    if (rawSeconds < 0) return 0;
    if (rawSeconds > 86400) return 86400;

    return rawSeconds;
  }

  Map<String, dynamic> _removeNullValues(Map<String, dynamic> map) {
    final output = Map<String, dynamic>.from(map);
    output.removeWhere((_, value) => value == null);
    return output;
  }

  void _removeNullValuesMutating(Map<String, dynamic> map) {
    map.removeWhere((_, value) => value == null);
  }

  String? _stringOrNull(String? value) {
    final trimmed = value?.trim();

    if (trimmed == null || trimmed.isEmpty) return null;

    return trimmed;
  }
}
