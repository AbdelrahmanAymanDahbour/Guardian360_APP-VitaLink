import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../models/vehicle_plate_model.dart';
import 'jordan_plate_validator.dart';

class PlateOcrService {
  PlateOcrService({
    JordanPlateValidator? plateValidator,
    TextRecognizer? textRecognizer,
    ImagePicker? imagePicker,
  }) : _plateValidator = plateValidator ?? const JordanPlateValidator(),
       _textRecognizer =
           textRecognizer ??
           TextRecognizer(script: TextRecognitionScript.latin),
       _imagePicker = imagePicker ?? ImagePicker();

  final JordanPlateValidator _plateValidator;
  final TextRecognizer _textRecognizer;
  final ImagePicker _imagePicker;

  static const Set<String> supportedImageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  Future<PlateOcrResult> pickAndReadVehiclePlate() {
    return pickAndReadVehiclePlateFromGallery();
  }

  Future<PlateOcrResult> pickAndReadVehiclePlateFromGallery() {
    return _pickAndReadVehiclePlate(source: PlateOcrImageSource.gallery);
  }

  Future<PlateOcrResult> captureAndReadVehiclePlateFromCamera() {
    return _pickAndReadVehiclePlate(source: PlateOcrImageSource.camera);
  }

  Future<PlateOcrResult> _pickAndReadVehiclePlate({
    required String source,
  }) async {
    if (kIsWeb) {
      return PlateOcrResult.failure(
        errorCode: 'unsupported-platform',
        source: source,
      );
    }

    try {
      final pickedImage = await _imagePicker.pickImage(
        source: source == PlateOcrImageSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 92,
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (pickedImage == null) {
        return PlateOcrResult.cancelled(source: source);
      }

      final imagePath = pickedImage.path.trim();

      if (imagePath.isEmpty) {
        return PlateOcrResult.failure(
          errorCode: 'image-path-unavailable',
          source: source,
        );
      }

      final extension = _normalizeExtension(_extensionFromPath(imagePath));

      if (extension == null || !supportedImageExtensions.contains(extension)) {
        return PlateOcrResult.failure(
          errorCode: 'unsupported-image-type',
          source: source,
          imagePath: imagePath,
        );
      }

      final imageBytes = await pickedImage.readAsBytes();

      if (imageBytes.isEmpty) {
        return PlateOcrResult.failure(
          errorCode: 'empty-image-file',
          source: source,
          imagePath: imagePath,
        );
      }

      return readVehiclePlateFromImagePath(
        imagePath,
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
      debugPrint('❌ PlateOcrService._pickAndReadVehiclePlate failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      return PlateOcrResult.failure(errorCode: 'ocr-failed', source: source);
    }
  }

  Future<PlateOcrResult> readVehiclePlateFromImagePath(
    String imagePath, {
    String source = PlateOcrImageSource.gallery,
    String? imageName,
    Uint8List? imageBytes,
    String? imageMimeType,
  }) async {
    final safeImagePath = imagePath.trim();

    if (safeImagePath.isEmpty) {
      return PlateOcrResult.failure(
        errorCode: 'image-path-unavailable',
        source: source,
      );
    }

    try {
      final inputImage = InputImage.fromFilePath(safeImagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final rawText = recognizedText.text.trim();

      if (rawText.isEmpty) {
        return PlateOcrResult.failure(
          errorCode: 'no-text-detected',
          source: source,
          imagePath: safeImagePath,
        );
      }

      final parsedPlate = _parseJordanVehiclePlate(rawText, source: source);

      if (parsedPlate == null) {
        return PlateOcrResult.failure(
          errorCode: 'no-plate-detected',
          rawText: rawText,
          source: source,
          imagePath: safeImagePath,
        );
      }

      return PlateOcrResult.success(
        plate: parsedPlate,
        rawText: rawText,
        source: source,
        imagePath: safeImagePath,
        imageName: imageName,
        imageBytes: imageBytes,
        imageMimeType: imageMimeType,
        capturedAtClient: DateTime.now().toUtc(),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ PlateOcrService.readVehiclePlateFromImagePath failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      return PlateOcrResult.failure(errorCode: 'ocr-failed', source: source);
    }
  }

  VehiclePlateModel? _parseJordanVehiclePlate(
    String rawText, {
    required String source,
  }) {
    final tokens = _extractDigitTokens(rawText);

    if (tokens.isEmpty) return null;

    final candidates = <_PlateCandidate>[];

    for (var i = 0; i < tokens.length; i++) {
      final codeToken = tokens[i];

      if (codeToken.value.length > 2) continue;

      for (var j = 0; j < tokens.length; j++) {
        if (i == j) continue;

        final numberToken = tokens[j];

        if (numberToken.value.length > 5) continue;

        final score = _scoreTokenPair(
          codeToken: codeToken,
          numberToken: numberToken,
        );

        candidates.add(
          _PlateCandidate(
            code: codeToken.value,
            number: numberToken.value,
            rawText: rawText,
            score: score,
          ),
        );
      }
    }

    for (final token in tokens) {
      if (token.value.length < 3 || token.value.length > 7) continue;

      for (final codeLength in const [1, 2]) {
        if (token.value.length <= codeLength) continue;

        final numberBeforeCode = token.value.substring(
          0,
          token.value.length - codeLength,
        );
        final codeAtEnd = token.value.substring(
          token.value.length - codeLength,
        );

        if (numberBeforeCode.length <= 5) {
          candidates.add(
            _PlateCandidate(
              code: codeAtEnd,
              number: numberBeforeCode,
              rawText: rawText,
              score: 86 - codeLength,
            ),
          );
        }

        final codeAtStart = token.value.substring(0, codeLength);
        final numberAfterCode = token.value.substring(codeLength);

        if (numberAfterCode.length <= 5) {
          candidates.add(
            _PlateCandidate(
              code: codeAtStart,
              number: numberAfterCode,
              rawText: rawText,
              score: 76 - codeLength,
            ),
          );
        }
      }
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));

    final seenKeys = <String>{};

    for (final candidate in candidates) {
      final candidateKey = '${candidate.code}-${candidate.number}';

      if (!seenKeys.add(candidateKey)) continue;

      final validation = _plateValidator.validate(
        rawCode: candidate.code,
        rawNumber: candidate.number,
        required: true,
        source: PlateOcrImageSource.toVehiclePlateInputSource(source),
        confidence: _confidenceFromScore(candidate.score),
        rawText: rawText,
      );

      if (validation.isValid && validation.plate != null) {
        return validation.plate;
      }
    }

    return null;
  }

  List<_DigitToken> _extractDigitTokens(String rawText) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map(_removePlateNoiseWords)
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);

    final tokens = <_DigitToken>[];
    final tokenPattern = RegExp(r'[0-9٠-٩۰-۹OoIl|SsBbgG]+');

    for (var lineIndex = 0; lineIndex < lines.length; lineIndex++) {
      final line = lines[lineIndex];
      final matches = tokenPattern.allMatches(line).toList(growable: false);

      for (var tokenIndex = 0; tokenIndex < matches.length; tokenIndex++) {
        final rawToken = matches[tokenIndex].group(0) ?? '';

        if (!_containsRealDigit(rawToken)) continue;

        final normalized = _normalizeOcrDigitToken(rawToken);

        if (normalized.isEmpty || normalized.length > 7) continue;
        if (!RegExp(r'^[0-9]+$').hasMatch(normalized)) continue;

        tokens.add(
          _DigitToken(
            value: normalized,
            lineIndex: lineIndex,
            tokenIndex: tokenIndex,
          ),
        );
      }
    }

    return tokens;
  }

  String _removePlateNoiseWords(String value) {
    return value
        .replaceAll(RegExp('JORDAN', caseSensitive: false), ' ')
        .replaceAll(RegExp('JO', caseSensitive: false), ' ')
        .replaceAll('الأردن', ' ')
        .replaceAll('الاردن', ' ')
        .replaceAll('أردن', ' ')
        .replaceAll('اردن', ' ');
  }

  bool _containsRealDigit(String value) {
    return RegExp(r'[0-9٠-٩۰-۹]').hasMatch(value);
  }

  String _normalizeOcrDigitToken(String value) {
    const digitMap = {
      '٠': '0',
      '١': '1',
      '٢': '2',
      '٣': '3',
      '٤': '4',
      '٥': '5',
      '٦': '6',
      '٧': '7',
      '٨': '8',
      '٩': '9',
      '۰': '0',
      '۱': '1',
      '۲': '2',
      '۳': '3',
      '۴': '4',
      '۵': '5',
      '۶': '6',
      '۷': '7',
      '۸': '8',
      '۹': '9',
      'O': '0',
      'o': '0',
      'I': '1',
      'l': '1',
      '|': '1',
      'S': '5',
      's': '5',
      'B': '8',
      'b': '6',
      'G': '6',
      'g': '9',
    };

    final buffer = StringBuffer();

    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(digitMap[char] ?? char);
    }

    return buffer.toString().replaceAll(RegExp(r'[^0-9]'), '');
  }

  int _scoreTokenPair({
    required _DigitToken codeToken,
    required _DigitToken numberToken,
  }) {
    var score = 35;

    if (codeToken.value.length <= 2) score += 20;
    if (numberToken.value.length >= 3 && numberToken.value.length <= 5) {
      score += 20;
    }
    if (numberToken.value.length > codeToken.value.length) score += 12;
    if (codeToken.lineIndex == numberToken.lineIndex) score += 10;
    if (codeToken.tokenIndex > numberToken.tokenIndex) score += 4;

    return score;
  }

  double _confidenceFromScore(int score) {
    final normalized = score / 100;

    if (normalized < 0.35) return 0.35;
    if (normalized > 0.99) return 0.99;

    return double.parse(normalized.toStringAsFixed(2));
  }

  String? _normalizeExtension(String? extension) {
    final safeExtension = extension?.trim().toLowerCase();

    if (safeExtension == null || safeExtension.isEmpty) return null;

    return safeExtension;
  }

  String? _extensionFromPath(String path) {
    final safePath = path.trim();
    final dotIndex = safePath.lastIndexOf('.');

    if (dotIndex < 0 || dotIndex == safePath.length - 1) return null;

    return safePath.substring(dotIndex + 1);
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
      default:
        return 'application/octet-stream';
    }
  }

  String _safeImageName(
    String rawName, {
    required String fallbackExtension,
    required String source,
  }) {
    final safeName = rawName.trim();

    if (safeName.isNotEmpty && safeName.contains('.')) {
      return safeName;
    }

    final prefix = source == PlateOcrImageSource.camera
        ? 'plate_camera'
        : 'plate_gallery';

    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}.$fallbackExtension';
  }

  Future<void> dispose() async {
    await _textRecognizer.close();
  }
}

class PlateOcrResult {
  const PlateOcrResult._({
    required this.isSuccess,
    required this.isCancelled,
    required this.source,
    this.plate,
    this.rawText,
    this.imagePath,
    this.imageName,
    this.imageBytes,
    this.imageMimeType,
    this.capturedAtClient,
    this.errorCode,
  });

  const PlateOcrResult.success({
    required VehiclePlateModel plate,
    required String rawText,
    required String source,
    required String imagePath,
    String? imageName,
    Uint8List? imageBytes,
    String? imageMimeType,
    DateTime? capturedAtClient,
  }) : this._(
         isSuccess: true,
         isCancelled: false,
         plate: plate,
         rawText: rawText,
         source: source,
         imagePath: imagePath,
         imageName: imageName,
         imageBytes: imageBytes,
         imageMimeType: imageMimeType,
         capturedAtClient: capturedAtClient,
       );

  const PlateOcrResult.failure({
    required String errorCode,
    String source = PlateOcrImageSource.gallery,
    String? rawText,
    String? imagePath,
  }) : this._(
         isSuccess: false,
         isCancelled: false,
         source: source,
         errorCode: errorCode,
         rawText: rawText,
         imagePath: imagePath,
       );

  const PlateOcrResult.cancelled({String source = PlateOcrImageSource.gallery})
    : this._(isSuccess: false, isCancelled: true, source: source);

  final bool isSuccess;
  final bool isCancelled;
  final String source;
  final VehiclePlateModel? plate;
  final String? rawText;
  final String? imagePath;
  final String? imageName;
  final Uint8List? imageBytes;
  final String? imageMimeType;
  final DateTime? capturedAtClient;
  final String? errorCode;
}

class PlateOcrImageSource {
  const PlateOcrImageSource._();

  static const String camera = 'camera';
  static const String gallery = 'gallery';

  static const Set<String> values = {camera, gallery};

  static bool isValid(String value) {
    return values.contains(value.trim());
  }

  static String normalize(String value) {
    final safeValue = value.trim();

    if (isValid(safeValue)) return safeValue;

    return gallery;
  }

  static String toVehiclePlateInputSource(String value) {
    switch (normalize(value)) {
      case camera:
        return VehiclePlateInputSource.ocrCamera;
      case gallery:
      default:
        return VehiclePlateInputSource.ocrGallery;
    }
  }
}

class _DigitToken {
  const _DigitToken({
    required this.value,
    required this.lineIndex,
    required this.tokenIndex,
  });

  final String value;
  final int lineIndex;
  final int tokenIndex;
}

class _PlateCandidate {
  const _PlateCandidate({
    required this.code,
    required this.number,
    required this.rawText,
    required this.score,
  });

  final String code;
  final String number;
  final String rawText;
  final int score;
}
