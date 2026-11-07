class GeneratedReportModel {
  const GeneratedReportModel({
    required this.reportId,
    required this.referenceCode,
    required this.reportVersion,
    required this.fileName,
    required this.storagePath,
    required this.downloadUrl,
    required this.generatedAtClient,
    required this.sizeBytes,
    this.qrPayload,
    this.metadata = const {},
  });

  final String reportId;
  final String referenceCode;
  final int reportVersion;
  final String fileName;
  final String storagePath;
  final String downloadUrl;
  final DateTime generatedAtClient;
  final int sizeBytes;
  final String? qrPayload;
  final Map<String, dynamic> metadata;

  static const int currentVersion = 1;
  static const String format = 'pdf';
  static const String mimeType = 'application/pdf';

  bool get isValid {
    return reportId.trim().isNotEmpty &&
        referenceCode.trim().isNotEmpty &&
        fileName.trim().isNotEmpty &&
        storagePath.trim().isNotEmpty &&
        downloadUrl.trim().isNotEmpty &&
        reportVersion > 0 &&
        sizeBytes > 0;
  }

  Map<String, dynamic> toMap() {
    return _removeNullValues({
      'reportId': reportId.trim(),
      'referenceCode': referenceCode.trim(),
      'reportVersion': reportVersion,
      'format': format,
      'mimeType': mimeType,
      'fileName': fileName.trim(),
      'storagePath': storagePath.trim(),
      'downloadUrl': downloadUrl.trim(),
      'generatedAtClient': generatedAtClient.toUtc().toIso8601String(),
      'sizeBytes': sizeBytes,
      'qrPayload': _stringOrNull(qrPayload),
      'metadata': _safeMetadataOrNull(metadata),
    });
  }

  factory GeneratedReportModel.fromMap(Map<String, dynamic> map) {
    return GeneratedReportModel(
      reportId: _stringOrDefault(map['reportId'], ''),
      referenceCode: _stringOrDefault(map['referenceCode'], ''),
      reportVersion: _intFromValue(map['reportVersion']) ?? currentVersion,
      fileName: _stringOrDefault(map['fileName'], ''),
      storagePath: _stringOrDefault(map['storagePath'], ''),
      downloadUrl: _stringOrDefault(map['downloadUrl'], ''),
      generatedAtClient: _dateTimeFromValue(map['generatedAtClient']),
      sizeBytes: _intFromValue(map['sizeBytes']) ?? 0,
      qrPayload: _stringOrNull(map['qrPayload']?.toString()),
      metadata: map['metadata'] is Map
          ? _safeMetadata(Map<String, dynamic>.from(map['metadata'] as Map))
          : const {},
    );
  }

  static DateTime _dateTimeFromValue(dynamic value) {
    if (value is DateTime) return value.toUtc();

    final parsed = DateTime.tryParse(value?.toString().trim() ?? '');
    return parsed?.toUtc() ?? DateTime.now().toUtc();
  }

  static int? _intFromValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
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
