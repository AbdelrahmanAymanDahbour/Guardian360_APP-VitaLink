import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/services/firebase_service.dart';
import '../models/accident_evidence_model.dart';
import '../models/driver_license_model.dart';
import '../models/generated_report_model.dart';
import '../models/kroka_damage_zone.dart';
import '../models/kroka_report_model.dart';
import '../models/vehicle_plate_model.dart';

class KrokaRepository {
  KrokaRepository({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService();

  final FirebaseService _firebaseService;

  static const String collectionName = 'kroka_reports';

  static const String statusDraft = 'draft';
  static const String statusSubmitted = 'submitted';
  static const String statusDiscarded = 'discarded';

  Future<FirebaseResult<KrokaDraftResult>> createDraftReport({
    required String userId,
  }) async {
    try {
      final safeUserId = userId.trim();

      if (safeUserId.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'User ID is required',
            code: 'invalid-user-id',
          ),
        );
      }

      final docRef = _firebaseService.collection(collectionName).doc();
      final createdAtClient = DateTime.now().toUtc();

      final referenceCode = _buildReferenceCode(
        reportId: docRef.id,
        submittedAtClient: createdAtClient,
      );

      final draftData = _removeNullValues({
        'id': docRef.id,
        'reportId': docRef.id,
        'referenceCode': referenceCode,
        'userId': safeUserId,
        'schemaVersion': KrokaReportModel.schemaVersion,
        'reportType': KrokaReportModel.reportType,
        'source': KrokaReportModel.source,
        'status': statusDraft,

        // Evidence is initialized as empty so future uploads are attached
        // to a real report document instead of becoming orphan files.
        'evidenceSchemaVersion': KrokaReportModel.evidenceSchemaVersion,
        'driverLicenseSchemaVersion':
            KrokaReportModel.driverLicenseSchemaVersion,
        'evidenceItems': <Map<String, dynamic>>[],
        'evidenceSummary': null,

        'insuranceSignals': {
          'evidenceSchemaVersion': KrokaReportModel.evidenceSchemaVersion,
          'evidenceCount': 0,
          'hasEvidence': false,
        },

        'draftCreatedAtClient': Timestamp.fromDate(createdAtClient),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await docRef.set(draftData).timeout(const Duration(seconds: 10));

      return FirebaseResult.success(
        KrokaDraftResult(reportId: docRef.id, referenceCode: referenceCode),
      );
    } on TimeoutException catch (e, stackTrace) {
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Kroka draft creation timed out',
          code: 'kroka-draft-create-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to create kroka draft',
          code: 'kroka-draft-create-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<FirebaseResult<KrokaSubmissionResult>> submitReport({
    required String userId,
    required String damageZoneId,
    List<String> damageZoneIds = const [],
    required String faultEstimate,
    required VehiclePlateModel myVehiclePlate,
    VehiclePlateModel? otherVehiclePlate,
    DriverLicenseModel? myDriverLicense,
    DriverLicenseModel? otherDriverLicense,
    required Position position,
    String? locationName,
    String? notes,
    List<AccidentEvidenceModel> evidenceItems = const [],
    String? draftReportId,
    required DateTime locationCapturedAtClient,
  }) async {
    try {
      final safeUserId = userId.trim();
      final safeFaultEstimate = faultEstimate.trim();
      final safeDraftReportId = draftReportId?.trim();

      if (safeUserId.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'User ID is required',
            code: 'invalid-user-id',
          ),
        );
      }

      if (safeFaultEstimate.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Fault estimate is required',
            code: 'invalid-fault-estimate',
          ),
        );
      }

      final damageZone = KrokaDamageZone.maybeFromId(damageZoneId);

      if (damageZone == null) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Invalid damage zone',
            code: 'invalid-damage-zone',
          ),
        );
      }

      if (!_hasValidCoordinates(position.latitude, position.longitude)) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Invalid report coordinates',
            code: 'invalid-coordinates',
          ),
        );
      }

      if (!_hasUsableAccuracy(position.accuracy)) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Invalid location accuracy',
            code: 'invalid-location-accuracy',
          ),
        );
      }

      final useExistingDraft =
          safeDraftReportId != null && safeDraftReportId.isNotEmpty;

      final docRef = useExistingDraft
          ? _firebaseService.document(collectionName, safeDraftReportId)
          : _firebaseService.collection(collectionName).doc();

      Map<String, dynamic>? existingDraftData;

      if (useExistingDraft) {
        final draftSnapshot = await docRef.get().timeout(
          const Duration(seconds: 10),
        );

        if (!draftSnapshot.exists) {
          return FirebaseResult.failure(
            FirebaseServiceException(
              message: 'Kroka draft not found',
              code: 'kroka-draft-not-found',
            ),
          );
        }

        existingDraftData = draftSnapshot.data();

        final ownerUserId = existingDraftData?['userId']?.toString().trim();
        final draftStatus = existingDraftData?['status']?.toString().trim();

        if (ownerUserId == null || ownerUserId != safeUserId) {
          return FirebaseResult.failure(
            FirebaseServiceException(
              message: 'User is not allowed to submit this kroka draft',
              code: 'kroka-draft-owner-mismatch',
            ),
          );
        }

        if (draftStatus != statusDraft) {
          return FirebaseResult.failure(
            FirebaseServiceException(
              message: 'Kroka report is not an editable draft',
              code: 'kroka-draft-not-editable',
            ),
          );
        }
      }

      final submittedAtClient = DateTime.now().toUtc();

      final referenceCode = _existingReferenceCodeOrBuild(
        existingData: existingDraftData,
        reportId: docRef.id,
        submittedAtClient: submittedAtClient,
      );

      final firestoreSafeEvidenceItems = _firestoreSafeEvidenceItems(
        evidenceItems,
      );

      final report = KrokaReportModel(
        reportId: docRef.id,
        referenceCode: referenceCode,
        userId: safeUserId,
        status: statusSubmitted,
        damagePoint: damageZone.side,
        damageZone: damageZone.id,
        // All selected zones (de-duplicated; primary zone always first).
        damageZones: _buildDamageZoneIds(
          primaryId: damageZone.id,
          allIds: damageZoneIds,
        ),
        damageSide: damageZone.side,
        damageLabelKey: damageZone.labelKey,
        faultEstimate: safeFaultEstimate,
        myVehiclePlate: myVehiclePlate,
        otherVehiclePlate: otherVehiclePlate,
        myDriverLicense: myDriverLicense,
        otherDriverLicense: otherDriverLicense,
        latitude: position.latitude,
        longitude: position.longitude,
        locationAccuracyMeters: position.accuracy,
        locationName: locationName,
        speedKmhAtCapture: _speedKmhOrNull(position.speed),
        headingDegreesAtCapture: _headingOrNull(position.heading),
        notes: notes,
        evidenceItems: firestoreSafeEvidenceItems,
        locationCapturedAtClient: locationCapturedAtClient.toUtc(),
        submittedAtClient: submittedAtClient,
      );

      final reportMap = report.toFirestoreMap();

      if (useExistingDraft) {
        reportMap.remove('createdAt');
        reportMap['draftSubmittedAt'] = FieldValue.serverTimestamp();

        await docRef
            .set(reportMap, SetOptions(merge: true))
            .timeout(const Duration(seconds: 15));
      } else {
        await docRef.set(reportMap).timeout(const Duration(seconds: 15));
      }

      return FirebaseResult.success(
        KrokaSubmissionResult(
          reportId: docRef.id,
          referenceCode: referenceCode,
          evidenceCount: firestoreSafeEvidenceItems.length,
        ),
      );
    } on TimeoutException catch (e, stackTrace) {
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Kroka report submit timed out',
          code: 'kroka-submit-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to submit kroka report',
          code: 'kroka-submit-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<FirebaseResult<KrokaEvidenceUpdateResult>> updateReportEvidence({
    required String reportId,
    required String userId,
    required List<AccidentEvidenceModel> evidenceItems,
  }) async {
    try {
      final safeReportId = reportId.trim();
      final safeUserId = userId.trim();

      if (safeReportId.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Report ID is required',
            code: 'invalid-report-id',
          ),
        );
      }

      if (safeUserId.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'User ID is required',
            code: 'invalid-user-id',
          ),
        );
      }

      final docRef = _firebaseService.document(collectionName, safeReportId);

      final snapshot = await docRef.get().timeout(const Duration(seconds: 10));

      if (!snapshot.exists) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Kroka report not found',
            code: 'kroka-report-not-found',
          ),
        );
      }

      final data = snapshot.data();
      final ownerUserId = data?['userId']?.toString().trim();
      final status = data?['status']?.toString().trim();

      if (ownerUserId == null || ownerUserId != safeUserId) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'User is not allowed to update this kroka report',
            code: 'kroka-report-owner-mismatch',
          ),
        );
      }

      if (status == statusDiscarded) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Discarded kroka reports cannot be updated',
            code: 'kroka-report-discarded',
          ),
        );
      }

      final safeEvidenceItems = _firestoreSafeEvidenceItems(evidenceItems);
      final evidenceMaps = safeEvidenceItems
          .map((evidence) => evidence.toMap())
          .toList(growable: false);

      final evidenceSummary = _buildEvidenceSummary(safeEvidenceItems);

      await docRef
          .update({
            'evidenceSchemaVersion': KrokaReportModel.evidenceSchemaVersion,
            'driverLicenseSchemaVersion':
                KrokaReportModel.driverLicenseSchemaVersion,
            'evidenceItems': evidenceMaps,
            'evidenceSummary': evidenceSummary ?? FieldValue.delete(),
            'insuranceSignals.evidenceSchemaVersion':
                KrokaReportModel.evidenceSchemaVersion,
            'insuranceSignals.evidenceCount': safeEvidenceItems.length,
            'insuranceSignals.hasEvidence': safeEvidenceItems.isNotEmpty,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 15));

      return FirebaseResult.success(
        KrokaEvidenceUpdateResult(
          reportId: safeReportId,
          evidenceCount: safeEvidenceItems.length,
        ),
      );
    } on TimeoutException catch (e, stackTrace) {
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Kroka evidence update timed out',
          code: 'kroka-evidence-update-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to update kroka evidence',
          code: 'kroka-evidence-update-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<FirebaseResult<KrokaGeneratedReportUpdateResult>>
  attachGeneratedReport({
    required String reportId,
    required String userId,
    required GeneratedReportModel generatedReport,
  }) async {
    try {
      final safeReportId = reportId.trim();
      final safeUserId = userId.trim();

      if (safeReportId.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Report ID is required',
            code: 'invalid-report-id',
          ),
        );
      }

      if (safeUserId.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'User ID is required',
            code: 'invalid-user-id',
          ),
        );
      }

      if (!generatedReport.isValid ||
          generatedReport.reportId != safeReportId) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Generated report metadata is invalid',
            code: 'invalid-generated-report',
          ),
        );
      }

      final docRef = _firebaseService.document(collectionName, safeReportId);
      final snapshot = await docRef.get().timeout(const Duration(seconds: 10));

      if (!snapshot.exists) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Kroka report not found',
            code: 'kroka-report-not-found',
          ),
        );
      }

      final data = snapshot.data();
      final ownerUserId = data?['userId']?.toString().trim();

      if (ownerUserId == null || ownerUserId != safeUserId) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'User is not allowed to update this kroka report',
            code: 'kroka-report-owner-mismatch',
          ),
        );
      }

      await docRef
          .update({
            'generatedReport': generatedReport.toMap(),
            'generatedReportVersion': generatedReport.reportVersion,
            'pdfUrl': generatedReport.downloadUrl,
            'pdfStoragePath': generatedReport.storagePath,
            'pdfGeneratedAtClient': generatedReport.generatedAtClient
                .toUtc()
                .toIso8601String(),
            'pdfGeneratedAt': FieldValue.serverTimestamp(),
            'insuranceSignals.hasGeneratedPdfReport': true,
            'insuranceSignals.generatedReportVersion':
                generatedReport.reportVersion,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 15));

      return FirebaseResult.success(
        KrokaGeneratedReportUpdateResult(
          reportId: safeReportId,
          generatedReport: generatedReport,
        ),
      );
    } on TimeoutException catch (e, stackTrace) {
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Generated report update timed out',
          code: 'kroka-generated-report-update-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to update generated report metadata',
          code: 'kroka-generated-report-update-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<FirebaseResult<void>> discardDraftReport({
    required String reportId,
    required String userId,
  }) async {
    try {
      final safeReportId = reportId.trim();
      final safeUserId = userId.trim();

      if (safeReportId.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Report ID is required',
            code: 'invalid-report-id',
          ),
        );
      }

      if (safeUserId.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'User ID is required',
            code: 'invalid-user-id',
          ),
        );
      }

      final docRef = _firebaseService.document(collectionName, safeReportId);

      final snapshot = await docRef.get().timeout(const Duration(seconds: 10));

      if (!snapshot.exists) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Kroka draft not found',
            code: 'kroka-draft-not-found',
          ),
        );
      }

      final data = snapshot.data();
      final ownerUserId = data?['userId']?.toString().trim();
      final status = data?['status']?.toString().trim();

      if (ownerUserId == null || ownerUserId != safeUserId) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'User is not allowed to discard this kroka draft',
            code: 'kroka-draft-owner-mismatch',
          ),
        );
      }

      if (status != statusDraft) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Only draft kroka reports can be discarded',
            code: 'kroka-draft-not-editable',
          ),
        );
      }

      await docRef
          .update({
            'status': statusDiscarded,
            'discardedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 10));

      return FirebaseResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Kroka draft discard timed out',
          code: 'kroka-draft-discard-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to discard kroka draft',
          code: 'kroka-draft-discard-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  List<AccidentEvidenceModel> _firestoreSafeEvidenceItems(
    List<AccidentEvidenceModel> evidenceItems,
  ) {
    if (evidenceItems.isEmpty) return const [];

    final sortedItems = evidenceItems
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

  String _existingReferenceCodeOrBuild({
    required Map<String, dynamic>? existingData,
    required String reportId,
    required DateTime submittedAtClient,
  }) {
    final existingReference = existingData?['referenceCode']?.toString().trim();

    if (existingReference != null && existingReference.isNotEmpty) {
      return existingReference;
    }

    return _buildReferenceCode(
      reportId: reportId,
      submittedAtClient: submittedAtClient,
    );
  }

  String _buildReferenceCode({
    required String reportId,
    required DateTime submittedAtClient,
  }) {
    final year = submittedAtClient.year.toString();
    final month = submittedAtClient.month.toString().padLeft(2, '0');
    final day = submittedAtClient.day.toString().padLeft(2, '0');

    final suffix = reportId.length >= 6
        ? reportId.substring(0, 6).toUpperCase()
        : reportId.toUpperCase();

    return 'KRK-$year$month$day-$suffix';
  }

  /// Builds an ordered, de-duplicated list of damage zone IDs.
  ///
  /// The [primaryId] is always placed first so the canonical zone is
  /// unambiguous when only the first element is used.
  List<String> _buildDamageZoneIds({
    required String primaryId,
    required List<String> allIds,
  }) {
    final seen = <String>{};
    final result = <String>[];

    // Primary zone first.
    if (primaryId.isNotEmpty && seen.add(primaryId)) {
      result.add(primaryId);
    }

    // Remaining valid zones.
    for (final id in allIds) {
      final safe = id.trim();
      if (safe.isNotEmpty && KrokaDamageZone.isValidId(safe) && seen.add(safe)) {
        result.add(safe);
      }
    }

    return List<String>.unmodifiable(result);
  }

  double? _speedKmhOrNull(double speedMetersPerSecond) {
    if (speedMetersPerSecond.isNaN ||
        speedMetersPerSecond.isInfinite ||
        speedMetersPerSecond < 0) {
      return null;
    }

    final speedKmh = speedMetersPerSecond * 3.6;

    if (speedKmh.isNaN || speedKmh.isInfinite || speedKmh < 0) {
      return null;
    }

    return speedKmh;
  }

  double? _headingOrNull(double heading) {
    if (heading.isNaN || heading.isInfinite || heading < 0 || heading > 360) {
      return null;
    }

    return heading;
  }

  bool _hasUsableAccuracy(double accuracy) {
    return !accuracy.isNaN && !accuracy.isInfinite && accuracy >= 0.0;
  }

  bool _hasValidCoordinates(double latitude, double longitude) {
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

  Map<String, dynamic> _removeNullValues(Map<String, dynamic> map) {
    final output = Map<String, dynamic>.from(map);
    output.removeWhere((_, value) => value == null);
    return output;
  }
}

class KrokaGeneratedReportUpdateResult {
  const KrokaGeneratedReportUpdateResult({
    required this.reportId,
    required this.generatedReport,
  });

  final String reportId;
  final GeneratedReportModel generatedReport;
}

class KrokaDraftResult {
  const KrokaDraftResult({required this.reportId, required this.referenceCode});

  final String reportId;
  final String referenceCode;
}

class KrokaSubmissionResult {
  const KrokaSubmissionResult({
    required this.reportId,
    required this.referenceCode,
    this.evidenceCount = 0,
  });

  final String reportId;
  final String referenceCode;
  final int evidenceCount;
}

class KrokaEvidenceUpdateResult {
  const KrokaEvidenceUpdateResult({
    required this.reportId,
    required this.evidenceCount,
  });

  final String reportId;
  final int evidenceCount;
}
