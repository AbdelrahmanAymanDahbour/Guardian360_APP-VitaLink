import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../models/accident_evidence_model.dart';

class EvidenceCaptureService {
  const EvidenceCaptureService();

  static const int maxEvidenceFileSizeBytes = 25 * 1024 * 1024;

  static const Set<String> supportedImageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  static const Set<String> supportedVideoExtensions = {'mp4', 'mov', 'm4v'};

  static const Set<String> supportedAudioExtensions = {
    'aac',
    'm4a',
    'mp3',
    'wav',
  };

  static const Set<String> supportedExtensions = {
    ...supportedImageExtensions,
    ...supportedVideoExtensions,
    ...supportedAudioExtensions,
  };

  Future<EvidenceCaptureResult> pickEvidenceFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: supportedExtensions.toList(),
      );

      if (result == null || result.files.isEmpty) {
        return const EvidenceCaptureResult.cancelled();
      }

      final file = result.files.first;
      final fileName = file.name.trim();
      final extension = _normalizeExtension(file.extension);

      if (fileName.isEmpty || extension == null) {
        return const EvidenceCaptureResult.failure(errorCode: 'invalid-file');
      }

      if (!supportedExtensions.contains(extension)) {
        return const EvidenceCaptureResult.failure(
          errorCode: 'unsupported-file-type',
        );
      }

      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        return const EvidenceCaptureResult.failure(errorCode: 'empty-file');
      }

      if (bytes.length > maxEvidenceFileSizeBytes) {
        return const EvidenceCaptureResult.failure(errorCode: 'file-too-large');
      }

      final evidenceType = _resolveEvidenceType(extension);
      final mimeType = _resolveMimeType(extension);
      final capturedAtClient = DateTime.now().toUtc();
      final evidenceId = _generateEvidenceId(prefix: 'evidence_file');

      final capturedFile = CapturedEvidenceFile(
        id: evidenceId,
        type: evidenceType,
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        sizeBytes: bytes.length,
        capturedAtClient: capturedAtClient,
        localPath: _stringOrNull(file.path),
        captureSource: AccidentEvidenceCaptureSource.filePicker,
      );

      if (!capturedFile.isValid) {
        return const EvidenceCaptureResult.failure(
          errorCode: 'invalid-evidence',
        );
      }

      return EvidenceCaptureResult.success(file: capturedFile);
    } catch (e, stackTrace) {
      debugPrint('❌ EvidenceCaptureService.pickEvidenceFile failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      return const EvidenceCaptureResult.failure(errorCode: 'capture-failed');
    }
  }

  Future<EvidenceCaptureResult> pickVideoEvidenceFile() {
    return _pickEvidenceFileWithExtensions(
      allowedExtensions: supportedVideoExtensions,
      idPrefix: 'evidence_video_file',
    );
  }

  Future<EvidenceCaptureResult> pickAudioEvidenceFile() {
    return _pickEvidenceFileWithExtensions(
      allowedExtensions: supportedAudioExtensions,
      idPrefix: 'evidence_audio_file',
    );
  }

  Future<EvidenceCaptureResult> captureVideoFromCamera() {
    return _pickVideoEvidence(source: AccidentEvidenceCaptureSource.camera);
  }

  Future<EvidenceCaptureResult> pickVideoFromGallery() {
    return _pickVideoEvidence(source: AccidentEvidenceCaptureSource.gallery);
  }

  Future<EvidenceCaptureResult> _pickEvidenceFileWithExtensions({
    required Set<String> allowedExtensions,
    required String idPrefix,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: allowedExtensions.toList(),
      );

      if (result == null || result.files.isEmpty) {
        return const EvidenceCaptureResult.cancelled();
      }

      final file = result.files.first;
      final fileName = file.name.trim();
      final extension = _normalizeExtension(file.extension);

      if (fileName.isEmpty || extension == null) {
        return const EvidenceCaptureResult.failure(errorCode: 'invalid-file');
      }

      if (!allowedExtensions.contains(extension)) {
        return const EvidenceCaptureResult.failure(
          errorCode: 'unsupported-file-type',
        );
      }

      final bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        return const EvidenceCaptureResult.failure(errorCode: 'empty-file');
      }

      if (bytes.length > maxEvidenceFileSizeBytes) {
        return const EvidenceCaptureResult.failure(errorCode: 'file-too-large');
      }

      final capturedFile = CapturedEvidenceFile(
        id: _generateEvidenceId(prefix: idPrefix),
        type: _resolveEvidenceType(extension),
        bytes: bytes,
        fileName: fileName,
        mimeType: _resolveMimeType(extension),
        sizeBytes: bytes.length,
        capturedAtClient: DateTime.now().toUtc(),
        localPath: _stringOrNull(file.path),
        captureSource: AccidentEvidenceCaptureSource.filePicker,
      );

      if (!capturedFile.isValid) {
        return const EvidenceCaptureResult.failure(
          errorCode: 'invalid-evidence',
        );
      }

      return EvidenceCaptureResult.success(file: capturedFile);
    } catch (e, stackTrace) {
      debugPrint(
        '❌ EvidenceCaptureService._pickEvidenceFileWithExtensions failed: $e',
      );
      debugPrintStack(stackTrace: stackTrace);

      return const EvidenceCaptureResult.failure(errorCode: 'capture-failed');
    }
  }

  Future<EvidenceCaptureResult> _pickVideoEvidence({
    required String source,
  }) async {
    try {
      final picker = ImagePicker();
      final pickedVideo = await picker.pickVideo(
        source: source == AccidentEvidenceCaptureSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.rear,
        maxDuration: const Duration(seconds: 30),
      );

      if (pickedVideo == null) {
        return const EvidenceCaptureResult.cancelled();
      }

      final videoPath = pickedVideo.path.trim();
      final extension = _normalizeExtension(_extensionFromPath(videoPath));

      if (videoPath.isEmpty || extension == null) {
        return const EvidenceCaptureResult.failure(errorCode: 'invalid-file');
      }

      if (!supportedVideoExtensions.contains(extension)) {
        return const EvidenceCaptureResult.failure(
          errorCode: 'unsupported-file-type',
        );
      }

      final bytes = await pickedVideo.readAsBytes();

      if (bytes.isEmpty) {
        return const EvidenceCaptureResult.failure(errorCode: 'empty-file');
      }

      if (bytes.length > maxEvidenceFileSizeBytes) {
        return const EvidenceCaptureResult.failure(errorCode: 'file-too-large');
      }

      final capturedFile = CapturedEvidenceFile(
        id: _generateEvidenceId(
          prefix: source == AccidentEvidenceCaptureSource.camera
              ? 'evidence_video_camera'
              : 'evidence_video_gallery',
        ),
        type: AccidentEvidenceType.video,
        bytes: bytes,
        fileName: _safePickedImageName(
          pickedVideo.name,
          fallbackExtension: extension,
          source: source,
        ),
        mimeType: _resolveMimeType(extension),
        sizeBytes: bytes.length,
        capturedAtClient: DateTime.now().toUtc(),
        localPath: _stringOrNull(videoPath),
        captureSource: AccidentEvidenceCaptureSource.normalize(source),
      );

      if (!capturedFile.isValid) {
        return const EvidenceCaptureResult.failure(
          errorCode: 'invalid-evidence',
        );
      }

      return EvidenceCaptureResult.success(file: capturedFile);
    } catch (e, stackTrace) {
      debugPrint('❌ EvidenceCaptureService._pickVideoEvidence failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      return const EvidenceCaptureResult.failure(errorCode: 'capture-failed');
    }
  }

  Future<EvidenceCaptureResult> captureImageFromCamera() {
    return _pickImageEvidence(source: AccidentEvidenceCaptureSource.camera);
  }

  Future<EvidenceCaptureResult> pickImageFromGallery() {
    return _pickImageEvidence(source: AccidentEvidenceCaptureSource.gallery);
  }

  Future<EvidenceCaptureResult> _pickImageEvidence({
    required String source,
  }) async {
    try {
      final picker = ImagePicker();
      final pickedImage = await picker.pickImage(
        source: source == AccidentEvidenceCaptureSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 92,
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (pickedImage == null) {
        return const EvidenceCaptureResult.cancelled();
      }

      final imagePath = pickedImage.path.trim();
      final extension = _normalizeExtension(_extensionFromPath(imagePath));

      if (imagePath.isEmpty || extension == null) {
        return const EvidenceCaptureResult.failure(errorCode: 'invalid-file');
      }

      if (!supportedImageExtensions.contains(extension)) {
        return const EvidenceCaptureResult.failure(
          errorCode: 'unsupported-file-type',
        );
      }

      final bytes = await pickedImage.readAsBytes();

      if (bytes.isEmpty) {
        return const EvidenceCaptureResult.failure(errorCode: 'empty-file');
      }

      if (bytes.length > maxEvidenceFileSizeBytes) {
        return const EvidenceCaptureResult.failure(errorCode: 'file-too-large');
      }

      final fileName = _safePickedImageName(
        pickedImage.name,
        fallbackExtension: extension,
        source: source,
      );

      final capturedFile = CapturedEvidenceFile(
        id: _generateEvidenceId(
          prefix: source == AccidentEvidenceCaptureSource.camera
              ? 'evidence_camera'
              : 'evidence_gallery',
        ),
        type: AccidentEvidenceType.image,
        bytes: bytes,
        fileName: fileName,
        mimeType: _resolveMimeType(extension),
        sizeBytes: bytes.length,
        capturedAtClient: DateTime.now().toUtc(),
        localPath: _stringOrNull(imagePath),
        captureSource: AccidentEvidenceCaptureSource.normalize(source),
      );

      if (!capturedFile.isValid) {
        return const EvidenceCaptureResult.failure(
          errorCode: 'invalid-evidence',
        );
      }

      return EvidenceCaptureResult.success(file: capturedFile);
    } catch (e, stackTrace) {
      debugPrint('❌ EvidenceCaptureService._pickImageEvidence failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      return const EvidenceCaptureResult.failure(errorCode: 'capture-failed');
    }
  }

  String? _normalizeExtension(String? extension) {
    final safeExtension = extension?.trim().toLowerCase();

    if (safeExtension == null || safeExtension.isEmpty) {
      return null;
    }

    return safeExtension;
  }

  String? _extensionFromPath(String path) {
    final safePath = path.trim();
    final dotIndex = safePath.lastIndexOf('.');

    if (dotIndex < 0 || dotIndex == safePath.length - 1) return null;

    return safePath.substring(dotIndex + 1);
  }

  String _resolveEvidenceType(String extension) {
    if (supportedImageExtensions.contains(extension)) {
      return AccidentEvidenceType.image;
    }

    if (supportedVideoExtensions.contains(extension)) {
      return AccidentEvidenceType.video;
    }

    if (supportedAudioExtensions.contains(extension)) {
      return AccidentEvidenceType.audio;
    }

    return AccidentEvidenceType.image;
  }

  String _resolveMimeType(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'm4v':
        return 'video/x-m4v';
      case 'aac':
        return 'audio/aac';
      case 'm4a':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
    }
  }

  String _safePickedImageName(
    String rawName, {
    required String fallbackExtension,
    required String source,
  }) {
    final safeName = rawName.trim();

    if (safeName.isNotEmpty && safeName.contains('.')) {
      return safeName;
    }

    final prefix = source == AccidentEvidenceCaptureSource.camera
        ? 'camera_evidence'
        : 'gallery_evidence';

    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}.$fallbackExtension';
  }

  String _generateEvidenceId({required String prefix}) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
  }

  String? _stringOrNull(String? value) {
    final trimmed = value?.trim();

    if (trimmed == null || trimmed.isEmpty) return null;

    return trimmed;
  }
}

class CapturedEvidenceFile {
  const CapturedEvidenceFile({
    required this.id,
    required this.type,
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.capturedAtClient,
    this.localPath,
    this.captureSource = AccidentEvidenceCaptureSource.filePicker,
    this.metadata = const {},
  });

  final String id;
  final String type;
  final Uint8List bytes;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final DateTime capturedAtClient;
  final String? localPath;
  final String captureSource;
  final Map<String, dynamic> metadata;

  bool get isValid {
    return id.trim().isNotEmpty &&
        AccidentEvidenceType.isValid(type) &&
        AccidentEvidenceCaptureSource.isValid(captureSource) &&
        bytes.isNotEmpty &&
        fileName.trim().isNotEmpty &&
        mimeType.trim().isNotEmpty &&
        mimeType.contains('/') &&
        sizeBytes > 0;
  }
}

class EvidenceCaptureResult {
  const EvidenceCaptureResult._({
    required this.isSuccess,
    required this.isCancelled,
    this.file,
    this.errorCode,
  });

  const EvidenceCaptureResult.success({required CapturedEvidenceFile file})
    : this._(isSuccess: true, isCancelled: false, file: file);

  const EvidenceCaptureResult.failure({required String errorCode})
    : this._(isSuccess: false, isCancelled: false, errorCode: errorCode);

  const EvidenceCaptureResult.cancelled()
    : this._(isSuccess: false, isCancelled: true);

  final bool isSuccess;
  final bool isCancelled;
  final CapturedEvidenceFile? file;
  final String? errorCode;
}
