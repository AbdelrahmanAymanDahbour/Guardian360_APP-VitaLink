import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/services/firebase_service.dart';
import '../models/accident_evidence_model.dart';
import '../models/generated_report_model.dart';

class KrokaStorageService {
  KrokaStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  static const Duration _uploadTimeout = Duration(seconds: 30);
  static const Duration _downloadUrlTimeout = Duration(seconds: 10);
  static const Duration _deleteTimeout = Duration(seconds: 10);

  static const String _rootPath = FirebaseService.krokaImagesPath;
  static const String _reportsSegment = 'reports';
  static const String _evidenceSegment = 'evidence';

  Future<FirebaseResult<AccidentEvidenceModel>> uploadEvidenceBytes({
    required Uint8List bytes,
    required String userId,
    required String reportId,
    required String evidenceId,
    required String type,
    required String fileName,
    required String mimeType,
    required DateTime capturedAtClient,
    String? note,
    int sortOrder = 0,
    double? durationSeconds,
    int? width,
    int? height,
    Map<String, String>? metadata,
    String purpose = AccidentEvidencePurpose.general,
    String? captureSource,
    Map<String, dynamic>? evidenceMetadata,
  }) async {
    try {
      final safeUserId = _safePathSegment(userId);
      final safeReportId = _safePathSegment(reportId);
      final safeEvidenceId = _safePathSegment(evidenceId);
      final safeType = AccidentEvidenceType.normalize(type);
      final safePurpose = AccidentEvidencePurpose.normalize(purpose);
      final safeCaptureSource = captureSource == null
          ? null
          : AccidentEvidenceCaptureSource.normalize(captureSource);
      final safeFileName = _safeFileName(fileName);
      final safeMimeType = mimeType.trim().toLowerCase();

      if (bytes.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Evidence file is empty',
            code: 'empty-evidence-file',
          ),
        );
      }

      if (safeUserId == null) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'User ID is required',
            code: 'invalid-user-id',
          ),
        );
      }

      if (safeReportId == null) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Report ID is required',
            code: 'invalid-report-id',
          ),
        );
      }

      if (safeEvidenceId == null) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Evidence ID is required',
            code: 'invalid-evidence-id',
          ),
        );
      }

      if (!_isUploadableMediaType(safeType)) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Evidence type is not uploadable media',
            code: 'unsupported-evidence-type',
          ),
        );
      }

      if (safeFileName == null) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Evidence file name is required',
            code: 'invalid-evidence-file-name',
          ),
        );
      }

      if (!_isValidMimeTypeForEvidenceType(
        type: safeType,
        mimeType: safeMimeType,
      )) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Evidence MIME type does not match evidence type',
            code: 'invalid-evidence-mime-type',
          ),
        );
      }

      final objectName = '${safeEvidenceId}_$safeFileName';

      final storagePath = _buildEvidenceStoragePath(
        userId: safeUserId,
        reportId: safeReportId,
        type: safeType,
        objectName: objectName,
      );

      final ref = _storage.ref().child(storagePath);

      final uploadMetadata = SettableMetadata(
        contentType: safeMimeType,
        customMetadata: _removeNullStringValues({
          'userId': safeUserId,
          'reportId': safeReportId,
          'evidenceId': safeEvidenceId,
          'evidenceType': safeType,
          'evidencePurpose': safePurpose,
          if (safeCaptureSource != null) 'captureSource': safeCaptureSource,
          'originalFileName': safeFileName,
          'capturedAtClient': capturedAtClient.toUtc().toIso8601String(),
          ...?metadata,
        }),
      );

      final uploadTask = ref.putData(bytes, uploadMetadata);
      final snapshot = await uploadTask.timeout(_uploadTimeout);

      final downloadUrl = await snapshot.ref.getDownloadURL().timeout(
        _downloadUrlTimeout,
      );

      final evidence = AccidentEvidenceModel(
        id: safeEvidenceId,
        type: safeType,
        status: AccidentEvidenceStatus.uploaded,
        capturedAtClient: capturedAtClient.toUtc(),
        storagePath: snapshot.ref.fullPath,
        downloadUrl: downloadUrl,
        fileName: safeFileName,
        mimeType: safeMimeType,
        sizeBytes: bytes.length,
        durationSeconds: durationSeconds,
        width: width,
        height: height,
        note: note,
        sortOrder: sortOrder,
        purpose: safePurpose,
        captureSource: safeCaptureSource,
        metadata: evidenceMetadata ?? const {},
      );

      if (!evidence.isValid || !evidence.hasRemoteReference) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Uploaded evidence metadata is invalid',
            code: 'invalid-uploaded-evidence',
          ),
        );
      }

      return FirebaseResult.success(evidence);
    } on TimeoutException catch (e, stackTrace) {
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Evidence upload timed out',
          code: 'evidence-upload-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to upload evidence',
          code: 'evidence-upload-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<FirebaseResult<AccidentEvidenceModel>> uploadImageEvidence({
    required Uint8List bytes,
    required String userId,
    required String reportId,
    required String evidenceId,
    required String fileName,
    required String mimeType,
    required DateTime capturedAtClient,
    String? note,
    int sortOrder = 0,
    int? width,
    int? height,
    Map<String, String>? metadata,
    String purpose = AccidentEvidencePurpose.general,
    String? captureSource,
    Map<String, dynamic>? evidenceMetadata,
  }) {
    return uploadEvidenceBytes(
      bytes: bytes,
      userId: userId,
      reportId: reportId,
      evidenceId: evidenceId,
      type: AccidentEvidenceType.image,
      fileName: fileName,
      mimeType: mimeType,
      capturedAtClient: capturedAtClient,
      note: note,
      sortOrder: sortOrder,
      width: width,
      height: height,
      metadata: metadata,
      purpose: purpose,
      captureSource: captureSource,
      evidenceMetadata: evidenceMetadata,
    );
  }

  Future<FirebaseResult<AccidentEvidenceModel>> uploadVideoEvidence({
    required Uint8List bytes,
    required String userId,
    required String reportId,
    required String evidenceId,
    required String fileName,
    required String mimeType,
    required DateTime capturedAtClient,
    String? note,
    int sortOrder = 0,
    double? durationSeconds,
    int? width,
    int? height,
    Map<String, String>? metadata,
  }) {
    return uploadEvidenceBytes(
      bytes: bytes,
      userId: userId,
      reportId: reportId,
      evidenceId: evidenceId,
      type: AccidentEvidenceType.video,
      fileName: fileName,
      mimeType: mimeType,
      capturedAtClient: capturedAtClient,
      note: note,
      sortOrder: sortOrder,
      durationSeconds: durationSeconds,
      width: width,
      height: height,
      metadata: metadata,
    );
  }

  Future<FirebaseResult<AccidentEvidenceModel>> uploadAudioEvidence({
    required Uint8List bytes,
    required String userId,
    required String reportId,
    required String evidenceId,
    required String fileName,
    required String mimeType,
    required DateTime capturedAtClient,
    String? note,
    int sortOrder = 0,
    double? durationSeconds,
    Map<String, String>? metadata,
  }) {
    return uploadEvidenceBytes(
      bytes: bytes,
      userId: userId,
      reportId: reportId,
      evidenceId: evidenceId,
      type: AccidentEvidenceType.audio,
      fileName: fileName,
      mimeType: mimeType,
      capturedAtClient: capturedAtClient,
      note: note,
      sortOrder: sortOrder,
      durationSeconds: durationSeconds,
      metadata: metadata,
    );
  }

  Future<FirebaseResult<GeneratedReportModel>> uploadReportPdfBytes({
    required Uint8List bytes,
    required String userId,
    required String reportId,
    required String referenceCode,
    required String fileName,
    required DateTime generatedAtClient,
    required String qrPayload,
    Map<String, String>? metadata,
  }) async {
    try {
      final safeUserId = _safePathSegment(userId);
      final safeReportId = _safePathSegment(reportId);
      final safeReferenceCode = referenceCode.trim();
      final safeFileName = _safeFileName(fileName);

      if (bytes.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Generated PDF is empty',
            code: 'empty-pdf-report',
          ),
        );
      }

      if (safeUserId == null) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'User ID is required',
            code: 'invalid-user-id',
          ),
        );
      }

      if (safeReportId == null) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Report ID is required',
            code: 'invalid-report-id',
          ),
        );
      }

      if (safeReferenceCode.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Reference code is required',
            code: 'invalid-reference-code',
          ),
        );
      }

      if (safeFileName == null || !safeFileName.endsWith('.pdf')) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'PDF file name is invalid',
            code: 'invalid-pdf-file-name',
          ),
        );
      }

      final storagePath = _buildReportPdfStoragePath(
        userId: safeUserId,
        reportId: safeReportId,
        fileName: safeFileName,
      );

      final ref = _storage.ref().child(storagePath);
      final uploadMetadata = SettableMetadata(
        contentType: GeneratedReportModel.mimeType,
        customMetadata: _removeNullStringValues({
          'userId': safeUserId,
          'reportId': safeReportId,
          'referenceCode': safeReferenceCode,
          'reportVersion': GeneratedReportModel.currentVersion.toString(),
          'format': GeneratedReportModel.format,
          'generatedAtClient': generatedAtClient.toUtc().toIso8601String(),
          'qrPayload': qrPayload,
          ...?metadata,
        }),
      );

      final snapshot = await ref
          .putData(bytes, uploadMetadata)
          .timeout(_uploadTimeout);
      final downloadUrl = await snapshot.ref.getDownloadURL().timeout(
        _downloadUrlTimeout,
      );

      final generatedReport = GeneratedReportModel(
        reportId: safeReportId,
        referenceCode: safeReferenceCode,
        reportVersion: GeneratedReportModel.currentVersion,
        fileName: safeFileName,
        storagePath: snapshot.ref.fullPath,
        downloadUrl: downloadUrl,
        generatedAtClient: generatedAtClient.toUtc(),
        sizeBytes: bytes.length,
        qrPayload: qrPayload,
        metadata: {
          'source': 'guardian360_smart_kroka',
          'reportKind': 'minor_accident_pdf',
          'storageRoot': _rootPath,
          'generatedBy': 'mobile_app',
        },
      );

      if (!generatedReport.isValid) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Generated report metadata is invalid',
            code: 'invalid-generated-report',
          ),
        );
      }

      return FirebaseResult.success(generatedReport);
    } on TimeoutException catch (e, stackTrace) {
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'PDF report upload timed out',
          code: 'pdf-report-upload-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to upload PDF report',
          code: 'pdf-report-upload-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<FirebaseResult<void>> deleteEvidenceByStoragePath(
    String storagePath,
  ) async {
    try {
      final safeStoragePath = storagePath.trim();

      if (safeStoragePath.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Storage path is required',
            code: 'invalid-storage-path',
          ),
        );
      }

      await _storage
          .ref()
          .child(safeStoragePath)
          .delete()
          .timeout(_deleteTimeout);

      return FirebaseResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Evidence delete timed out',
          code: 'evidence-delete-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to delete evidence',
          code: 'evidence-delete-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<FirebaseResult<void>> deleteEvidenceByDownloadUrl(
    String downloadUrl,
  ) async {
    try {
      final safeDownloadUrl = downloadUrl.trim();

      if (safeDownloadUrl.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Download URL is required',
            code: 'invalid-download-url',
          ),
        );
      }

      await _storage
          .refFromURL(safeDownloadUrl)
          .delete()
          .timeout(_deleteTimeout);

      return FirebaseResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Evidence delete timed out',
          code: 'evidence-delete-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to delete evidence',
          code: 'evidence-delete-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  String _buildReportPdfStoragePath({
    required String userId,
    required String reportId,
    required String fileName,
  }) {
    return [
      _rootPath,
      userId,
      _reportsSegment,
      reportId,
      'generated',
      fileName,
    ].join('/');
  }

  String _buildEvidenceStoragePath({
    required String userId,
    required String reportId,
    required String type,
    required String objectName,
  }) {
    return [
      _rootPath,
      userId,
      _reportsSegment,
      reportId,
      _evidenceSegment,
      type,
      objectName,
    ].join('/');
  }

  bool _isUploadableMediaType(String type) {
    return type == AccidentEvidenceType.image ||
        type == AccidentEvidenceType.video ||
        type == AccidentEvidenceType.audio;
  }

  bool _isValidMimeTypeForEvidenceType({
    required String type,
    required String mimeType,
  }) {
    if (mimeType.isEmpty || !mimeType.contains('/')) {
      return false;
    }

    switch (type) {
      case AccidentEvidenceType.image:
        return mimeType.startsWith('image/');
      case AccidentEvidenceType.video:
        return mimeType.startsWith('video/');
      case AccidentEvidenceType.audio:
        return mimeType.startsWith('audio/');
      default:
        return false;
    }
  }

  String? _safePathSegment(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) return null;

    final sanitized = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    if (sanitized.trim().isEmpty) return null;

    return sanitized;
  }

  String? _safeFileName(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) return null;

    final sanitized = trimmed
        .replaceAll(RegExp(r'[\\/]'), '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    final clean = sanitized.trim();

    if (clean.isEmpty || clean == '.' || clean == '..') {
      return null;
    }

    return clean;
  }

  Map<String, String> _removeNullStringValues(Map<String, String?> map) {
    final output = <String, String>{};

    map.forEach((key, value) {
      final safeKey = key.trim();
      final safeValue = value?.trim();

      if (safeKey.isEmpty || safeValue == null || safeValue.isEmpty) {
        return;
      }

      output[safeKey] = safeValue;
    });

    return output;
  }
}
