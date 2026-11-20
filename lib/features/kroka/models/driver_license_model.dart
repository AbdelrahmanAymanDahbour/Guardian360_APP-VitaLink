class DriverLicenseModel {
  const DriverLicenseModel({
    required this.driverRole,
    required this.status,
    required this.scannedAtClient,
    this.fullName,
    this.nationalId,
    this.licenseNumber,
    this.expiryDate,
    this.licenseClass,
    this.source = DriverLicenseCaptureSource.manual,
    this.confidence,
    this.rawText,
    this.evidenceId,
    this.evidenceUrl,
    this.storagePath,
    this.reviewedAtClient,
    this.skipReason,
    this.metadata = const {},
  });

  final String driverRole;
  final String status;
  final DateTime scannedAtClient;
  final String? fullName;
  final String? nationalId;
  final String? licenseNumber;
  final DateTime? expiryDate;
  final String? licenseClass;
  final String source;
  final double? confidence;
  final String? rawText;
  final String? evidenceId;
  final String? evidenceUrl;
  final String? storagePath;
  final DateTime? reviewedAtClient;
  final String? skipReason;
  final Map<String, dynamic> metadata;

  bool get isScanned {
    return status == DriverLicenseVerificationStatus.pendingReview ||
        status == DriverLicenseVerificationStatus.verified;
  }

  bool get isVerified {
    return status == DriverLicenseVerificationStatus.verified;
  }

  bool get isSkipped {
    return status == DriverLicenseVerificationStatus.skipped ||
        status == DriverLicenseVerificationStatus.refused;
  }

  bool get hasUsefulData {
    return _hasText(fullName) ||
        _hasText(nationalId) ||
        _hasText(licenseNumber);
  }

  bool get hasEvidence {
    return _hasText(evidenceId) ||
        _hasText(evidenceUrl) ||
        _hasText(storagePath);
  }

  bool get isValid {
    if (!DriverLicenseRole.isValid(driverRole)) return false;
    if (!DriverLicenseVerificationStatus.isValid(status)) return false;
    if (!DriverLicenseCaptureSource.isValid(source)) return false;

    if (isScanned && !hasUsefulData) return false;

    return true;
  }

  DriverLicenseModel copyWith({
    String? driverRole,
    String? status,
    DateTime? scannedAtClient,
    String? fullName,
    String? nationalId,
    String? licenseNumber,
    DateTime? expiryDate,
    String? licenseClass,
    String? source,
    double? confidence,
    String? rawText,
    String? evidenceId,
    String? evidenceUrl,
    String? storagePath,
    DateTime? reviewedAtClient,
    String? skipReason,
    Map<String, dynamic>? metadata,
  }) {
    return DriverLicenseModel(
      driverRole: driverRole == null
          ? this.driverRole
          : DriverLicenseRole.normalize(driverRole),
      status: status == null
          ? this.status
          : DriverLicenseVerificationStatus.normalize(status),
      scannedAtClient: scannedAtClient ?? this.scannedAtClient,
      fullName: fullName ?? this.fullName,
      nationalId: nationalId ?? this.nationalId,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      licenseClass: licenseClass ?? this.licenseClass,
      source: source == null
          ? this.source
          : DriverLicenseCaptureSource.normalize(source),
      confidence: confidence ?? this.confidence,
      rawText: rawText ?? this.rawText,
      evidenceId: evidenceId ?? this.evidenceId,
      evidenceUrl: evidenceUrl ?? this.evidenceUrl,
      storagePath: storagePath ?? this.storagePath,
      reviewedAtClient: reviewedAtClient ?? this.reviewedAtClient,
      skipReason: skipReason ?? this.skipReason,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return _removeNullValues({
      'driverRole': DriverLicenseRole.normalize(driverRole),
      'status': DriverLicenseVerificationStatus.normalize(status),
      'scannedAtClient': scannedAtClient.toUtc().toIso8601String(),
      'fullName': _stringOrNull(fullName),
      'nationalId': _stringOrNull(nationalId),
      'licenseNumber': _stringOrNull(licenseNumber),
      'expiryDate': expiryDate?.toUtc().toIso8601String(),
      'licenseClass': _stringOrNull(licenseClass),
      'source': DriverLicenseCaptureSource.normalize(source),
      'confidence': _safeConfidence(confidence),
      'rawText': _stringOrNull(rawText),
      'evidenceId': _stringOrNull(evidenceId),
      'evidenceUrl': _stringOrNull(evidenceUrl),
      'storagePath': _stringOrNull(storagePath),
      'reviewedAtClient': reviewedAtClient?.toUtc().toIso8601String(),
      'skipReason': _stringOrNull(skipReason),
      'metadata': _safeMetadataOrNull(metadata),
    });
  }

  factory DriverLicenseModel.fromMap(Map<String, dynamic> map) {
    return DriverLicenseModel(
      driverRole: DriverLicenseRole.normalize(
        _stringOrDefault(map['driverRole'], DriverLicenseRole.myDriver),
      ),
      status: DriverLicenseVerificationStatus.normalize(
        _stringOrDefault(
          map['status'],
          DriverLicenseVerificationStatus.notProvided,
        ),
      ),
      scannedAtClient: _dateTimeFromValue(map['scannedAtClient']),
      fullName: _stringOrNull(map['fullName']?.toString()),
      nationalId: _stringOrNull(map['nationalId']?.toString()),
      licenseNumber: _stringOrNull(map['licenseNumber']?.toString()),
      expiryDate: _dateTimeOrNull(map['expiryDate']),
      licenseClass: _stringOrNull(map['licenseClass']?.toString()),
      source: DriverLicenseCaptureSource.normalize(
        _stringOrDefault(map['source'], DriverLicenseCaptureSource.manual),
      ),
      confidence: _safeConfidence(_doubleFromValue(map['confidence'])),
      rawText: _stringOrNull(map['rawText']?.toString()),
      evidenceId: _stringOrNull(map['evidenceId']?.toString()),
      evidenceUrl: _stringOrNull(map['evidenceUrl']?.toString()),
      storagePath: _stringOrNull(map['storagePath']?.toString()),
      reviewedAtClient: _dateTimeOrNull(map['reviewedAtClient']),
      skipReason: _stringOrNull(map['skipReason']?.toString()),
      metadata: map['metadata'] is Map
          ? _safeMetadata(Map<String, dynamic>.from(map['metadata'] as Map))
          : const {},
    );
  }

  static DateTime _dateTimeFromValue(dynamic value) {
    final parsed = _dateTimeOrNull(value);
    return parsed ?? DateTime.now().toUtc();
  }

  static DateTime? _dateTimeOrNull(dynamic value) {
    if (value is DateTime) return value.toUtc();

    final parsed = DateTime.tryParse(value?.toString().trim() ?? '');
    return parsed?.toUtc();
  }

  static double? _doubleFromValue(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString().trim() ?? '');
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  static String _stringOrDefault(dynamic value, String fallback) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }

  static String? _stringOrNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static double? _safeConfidence(double? value) {
    if (value == null || value.isNaN || value.isInfinite) return null;
    if (value < 0.0 || value > 1.0) return null;
    return double.parse(value.toStringAsFixed(2));
  }

  static Map<String, dynamic>? _safeMetadataOrNull(Map<String, dynamic> value) {
    final safe = _safeMetadata(value);
    if (safe.isEmpty) return null;
    return safe;
  }

  static Map<String, dynamic> _safeMetadata(Map<String, dynamic> value) {
    final output = <String, dynamic>{};

    for (final entry in value.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;

      final safeValue = _safeMetadataValue(entry.value);
      if (safeValue != null) output[key] = safeValue;
    }

    return Map<String, dynamic>.unmodifiable(output);
  }

  static dynamic _safeMetadataValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return _stringOrNull(value);
    if (value is bool) return value;
    if (value is int) return value;
    if (value is double) {
      if (value.isNaN || value.isInfinite) return null;
      return value;
    }
    if (value is num) return value;
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is Map) return _safeMetadata(Map<String, dynamic>.from(value));
    if (value is Iterable) {
      return value
          .map(_safeMetadataValue)
          .where((item) => item != null)
          .toList(growable: false);
    }

    return _stringOrNull(value.toString());
  }

  static Map<String, dynamic> _removeNullValues(Map<String, dynamic> map) {
    final output = Map<String, dynamic>.from(map);
    output.removeWhere((_, value) => value == null);
    return output;
  }
}

class DriverLicenseRole {
  const DriverLicenseRole._();

  static const String myDriver = 'my_driver';
  static const String otherDriver = 'other_driver';

  static const Set<String> values = {myDriver, otherDriver};

  static bool isValid(String value) => values.contains(value.trim());

  static String normalize(String value) {
    final safe = value.trim();
    if (isValid(safe)) return safe;
    return myDriver;
  }
}

class DriverLicenseVerificationStatus {
  const DriverLicenseVerificationStatus._();

  static const String notProvided = 'not_provided';
  static const String pendingReview = 'pending_review';
  static const String verified = 'verified';
  static const String skipped = 'skipped';
  static const String refused = 'refused';

  static const Set<String> values = {
    notProvided,
    pendingReview,
    verified,
    skipped,
    refused,
  };

  static bool isValid(String value) => values.contains(value.trim());

  static String normalize(String value) {
    final safe = value.trim();
    if (isValid(safe)) return safe;
    return notProvided;
  }
}

class DriverLicenseCaptureSource {
  const DriverLicenseCaptureSource._();

  static const String manual = 'manual';
  static const String camera = 'camera';
  static const String gallery = 'gallery';
  static const String editedAfterOcr = 'edited_after_ocr';

  static const Set<String> values = {manual, camera, gallery, editedAfterOcr};

  static bool isValid(String value) => values.contains(value.trim());

  static String normalize(String value) {
    final safe = value.trim();
    if (isValid(safe)) return safe;
    return manual;
  }
}
