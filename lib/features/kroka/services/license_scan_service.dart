import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../models/driver_license_model.dart';

class LicenseScanService {
  LicenseScanService({TextRecognizer? textRecognizer, ImagePicker? imagePicker})
    : _textRecognizer =
          textRecognizer ?? TextRecognizer(script: TextRecognitionScript.latin),
      _imagePicker = imagePicker ?? ImagePicker();

  final TextRecognizer _textRecognizer;
  final ImagePicker _imagePicker;

  static const Set<String> supportedImageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  Future<DriverLicenseScanResult> captureFromCamera({required String role}) {
    return _pickAndReadLicense(
      role: role,
      source: DriverLicenseCaptureSource.camera,
    );
  }

  Future<DriverLicenseScanResult> pickFromGallery({required String role}) {
    return _pickAndReadLicense(
      role: role,
      source: DriverLicenseCaptureSource.gallery,
    );
  }

  Future<DriverLicenseScanResult> _pickAndReadLicense({
    required String role,
    required String source,
  }) async {
    if (kIsWeb) {
      return DriverLicenseScanResult.failure(
        role: role,
        source: source,
        errorCode: 'unsupported-platform',
      );
    }

    try {
      final pickedImage = await _imagePicker.pickImage(
        source: source == DriverLicenseCaptureSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 92,
        maxWidth: 2200,
        maxHeight: 2200,
      );

      if (pickedImage == null) {
        return DriverLicenseScanResult.cancelled(role: role, source: source);
      }

      final imagePath = pickedImage.path.trim();

      if (imagePath.isEmpty) {
        return DriverLicenseScanResult.failure(
          role: role,
          source: source,
          errorCode: 'image-path-unavailable',
        );
      }

      final extension = _normalizeExtension(_extensionFromPath(imagePath));

      if (extension == null || !supportedImageExtensions.contains(extension)) {
        return DriverLicenseScanResult.failure(
          role: role,
          source: source,
          imagePath: imagePath,
          errorCode: 'unsupported-image-type',
        );
      }

      final imageBytes = await pickedImage.readAsBytes();

      if (imageBytes.isEmpty) {
        return DriverLicenseScanResult.failure(
          role: role,
          source: source,
          imagePath: imagePath,
          errorCode: 'empty-image-file',
        );
      }

      return readLicenseFromImagePath(
        imagePath,
        role: role,
        source: source,
        imageName: _safeImageName(
          pickedImage.name,
          fallbackExtension: extension,
          source: source,
        ),
        imageBytes: imageBytes,
        imageMimeType: _resolveMimeType(extension),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ LicenseScanService._pickAndReadLicense failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      return DriverLicenseScanResult.failure(
        role: role,
        source: source,
        errorCode: 'scan-failed',
      );
    }
  }

  Future<DriverLicenseScanResult> readLicenseFromImagePath(
    String imagePath, {
    required String role,
    required String source,
    String? imageName,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    final safeImagePath = imagePath.trim();

    if (safeImagePath.isEmpty) {
      return DriverLicenseScanResult.failure(
        role: role,
        source: source,
        errorCode: 'image-path-unavailable',
      );
    }

    try {
      final inputImage = InputImage.fromFilePath(safeImagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final rawText = recognizedText.text.trim();

      if (rawText.isEmpty) {
        return DriverLicenseScanResult.failure(
          role: role,
          source: source,
          imagePath: safeImagePath,
          errorCode: 'no-text-detected',
        );
      }

      final parsedLicense = _parseDriverLicense(
        rawText: rawText,
        role: role,
        source: source,
      );

      if (parsedLicense == null || !parsedLicense.hasUsefulData) {
        return DriverLicenseScanResult.failure(
          role: role,
          source: source,
          imagePath: safeImagePath,
          rawText: rawText,
          errorCode: 'no-license-data-detected',
        );
      }

      return DriverLicenseScanResult.success(
        license: parsedLicense,
        rawText: rawText,
        role: role,
        source: source,
        imagePath: safeImagePath,
        imageName: imageName,
        imageBytes: imageBytes,
        imageMimeType: imageMimeType,
        capturedAtClient: DateTime.now().toUtc(),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ LicenseScanService.readLicenseFromImagePath failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      return DriverLicenseScanResult.failure(
        role: role,
        source: source,
        errorCode: 'scan-failed',
      );
    }
  }

  DriverLicenseModel? _parseDriverLicense({
    required String rawText,
    required String role,
    required String source,
  }) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final normalizedText = rawText.replaceAll(RegExp(r'[\t\n\r]+'), ' ');
    final digitGroups = RegExp(r'\d{4,12}')
        .allMatches(normalizedText)
        .map((match) => match.group(0) ?? '')
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    final nationalId = _pickNationalId(digitGroups);
    final licenseNumber = _pickLicenseNumber(digitGroups, nationalId);
    final expiryDate = _pickExpiryDate(normalizedText);
    final licenseClass = _pickLicenseClass(normalizedText);
    final fullName = _pickName(lines);

    final detectedFields = [
      fullName,
      nationalId,
      licenseNumber,
      expiryDate?.toIso8601String(),
      licenseClass,
    ].where((value) => value != null && value.trim().isNotEmpty).length;

    if (detectedFields == 0) return null;

    final confidence = (detectedFields / 5).clamp(0.2, 1.0).toDouble();

    return DriverLicenseModel(
      driverRole: DriverLicenseRole.normalize(role),
      status: DriverLicenseVerificationStatus.pendingReview,
      scannedAtClient: DateTime.now().toUtc(),
      fullName: fullName,
      nationalId: nationalId,
      licenseNumber: licenseNumber,
      expiryDate: expiryDate,
      licenseClass: licenseClass,
      source: DriverLicenseCaptureSource.normalize(source),
      confidence: double.parse(confidence.toStringAsFixed(2)),
      rawText: rawText,
      metadata: {
        'detectedFieldCount': detectedFields,
        'requiresHumanReview': true,
        'extractionMode': 'mlkit_latin_heuristic',
      },
    );
  }

  String? _pickNationalId(List<String> digitGroups) {
    for (final group in digitGroups) {
      final digits = _digitsOnly(group);
      if (digits.length == 10) return digits;
    }

    return null;
  }

  String? _pickLicenseNumber(List<String> digitGroups, String? nationalId) {
    for (final group in digitGroups) {
      final digits = _digitsOnly(group);
      if (digits == nationalId) continue;
      if (digits.length >= 5 && digits.length <= 9) return digits;
    }

    return null;
  }

  DateTime? _pickExpiryDate(String text) {
    final match = RegExp(
      r'(\d{1,2})[\-\/.](\d{1,2})[\-\/.](\d{2,4})',
    ).firstMatch(text);

    if (match != null) {
      final day = int.tryParse(match.group(1) ?? '');
      final month = int.tryParse(match.group(2) ?? '');
      final yearRaw = int.tryParse(match.group(3) ?? '');

      if (day != null && month != null && yearRaw != null) {
        final year = yearRaw < 100 ? 2000 + yearRaw : yearRaw;
        return _safeDate(year, month, day);
      }
    }

    final isoMatch = RegExp(
      r'(20\d{2})[\-\/.](\d{1,2})[\-\/.](\d{1,2})',
    ).firstMatch(text);

    if (isoMatch != null) {
      final year = int.tryParse(isoMatch.group(1) ?? '');
      final month = int.tryParse(isoMatch.group(2) ?? '');
      final day = int.tryParse(isoMatch.group(3) ?? '');

      if (year != null && month != null && day != null) {
        return _safeDate(year, month, day);
      }
    }

    return null;
  }

  String? _pickLicenseClass(String text) {
    final classMatch = RegExp(
      r'(?:class|category|cat|الفئة)\s*[:\-]?\s*([A-Z0-9]{1,4})',
      caseSensitive: false,
    ).firstMatch(text);

    final value = classMatch?.group(1)?.trim().toUpperCase();

    if (value != null && value.isNotEmpty) return value;

    final compactMatch = RegExp(r'\b[A-E][1-3]?\b').firstMatch(text);
    return compactMatch?.group(0)?.trim().toUpperCase();
  }

  String? _pickName(List<String> lines) {
    const blockedWords = {
      'kingdom',
      'jordan',
      'license',
      'licence',
      'driving',
      'driver',
      'traffic',
      'department',
      'expiry',
      'expire',
      'date',
      'class',
      'category',
      'national',
      'id',
      'hashemite',
    };

    for (final line in lines) {
      final normalized = line.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (normalized.length < 4 || normalized.length > 80) continue;
      if (RegExp(r'\d').hasMatch(normalized)) continue;
      if (!RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(normalized)) continue;

      final lower = normalized.toLowerCase();
      if (blockedWords.any((word) => lower.contains(word))) continue;

      return normalized;
    }

    return null;
  }

  DateTime? _safeDate(int year, int month, int day) {
    if (year < 2000 || year > 2100) return null;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;

    try {
      return DateTime.utc(year, month, day);
    } catch (_) {
      return null;
    }
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String? _extensionFromPath(String path) {
    final cleanPath = path.split('?').first.trim();
    final dotIndex = cleanPath.lastIndexOf('.');

    if (dotIndex < 0 || dotIndex == cleanPath.length - 1) return null;

    return cleanPath.substring(dotIndex + 1);
  }

  String? _normalizeExtension(String? value) {
    final extension = value?.trim().toLowerCase();
    if (extension == null || extension.isEmpty) return null;
    return extension == 'jpg' ? 'jpeg' : extension;
  }

  String _resolveMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }

  String _safeImageName(
    String rawName, {
    required String fallbackExtension,
    required String source,
  }) {
    final safeRawName = rawName.trim();

    if (safeRawName.isNotEmpty && safeRawName.contains('.')) {
      return safeRawName;
    }

    final sourceLabel = source == DriverLicenseCaptureSource.camera
        ? 'camera'
        : 'gallery';

    return 'driver_license_${sourceLabel}_${DateTime.now().microsecondsSinceEpoch}.$fallbackExtension';
  }

  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}

class DriverLicenseScanResult {
  const DriverLicenseScanResult._({
    required this.isSuccess,
    required this.isCancelled,
    required this.role,
    required this.source,
    this.license,
    this.rawText,
    this.imagePath,
    this.imageName,
    this.imageBytes,
    this.imageMimeType,
    this.capturedAtClient,
    this.errorCode,
  });

  const DriverLicenseScanResult.success({
    required DriverLicenseModel license,
    required String rawText,
    required String role,
    required String source,
    String? imagePath,
    String? imageName,
    Uint8List? imageBytes,
    String? imageMimeType,
    DateTime? capturedAtClient,
  }) : this._(
         isSuccess: true,
         isCancelled: false,
         license: license,
         rawText: rawText,
         role: role,
         source: source,
         imagePath: imagePath,
         imageName: imageName,
         imageBytes: imageBytes,
         imageMimeType: imageMimeType,
         capturedAtClient: capturedAtClient,
       );

  const DriverLicenseScanResult.failure({
    required String role,
    required String source,
    required String errorCode,
    String? rawText,
    String? imagePath,
  }) : this._(
         isSuccess: false,
         isCancelled: false,
         role: role,
         source: source,
         errorCode: errorCode,
         rawText: rawText,
         imagePath: imagePath,
       );

  const DriverLicenseScanResult.cancelled({
    required String role,
    required String source,
  }) : this._(isSuccess: false, isCancelled: true, role: role, source: source);

  final bool isSuccess;
  final bool isCancelled;
  final String role;
  final String source;
  final DriverLicenseModel? license;
  final String? rawText;
  final String? imagePath;
  final String? imageName;
  final Uint8List? imageBytes;
  final String? imageMimeType;
  final DateTime? capturedAtClient;
  final String? errorCode;
}
