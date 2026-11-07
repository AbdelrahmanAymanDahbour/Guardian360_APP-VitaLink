class VehiclePlateModel {
  const VehiclePlateModel({
    required this.code,
    required this.number,
    required this.normalizedKey,
    this.countryCode = defaultCountryCode,
    this.source = VehiclePlateInputSource.manual,
    this.confidence,
    this.rawText,
  });

  static const String defaultCountryCode = 'JO';

  final int code;
  final int number;
  final String normalizedKey;

  /// Country identifier for plate normalization.
  /// Current implementation is aligned with Jordanian plates.
  final String countryCode;

  /// Describes how this plate value entered the system.
  /// Examples: manual, ocr_camera, ocr_gallery, edited_after_ocr.
  final String source;

  /// Optional OCR confidence when the source is OCR-based.
  final double? confidence;

  /// Optional raw OCR text before validation/cleanup.
  final String? rawText;

  factory VehiclePlateModel.normalized({
    required int code,
    required int number,
    String countryCode = defaultCountryCode,
    String source = VehiclePlateInputSource.manual,
    double? confidence,
    String? rawText,
  }) {
    final safeCountryCode = _normalizeCountryCode(countryCode);
    final safeSource = VehiclePlateInputSource.normalize(source);

    return VehiclePlateModel(
      code: code,
      number: number,
      countryCode: safeCountryCode,
      source: safeSource,
      confidence: _safeConfidence(confidence),
      rawText: _stringOrNull(rawText),
      normalizedKey: buildNormalizedKey(
        countryCode: safeCountryCode,
        code: code,
        number: number,
      ),
    );
  }

  String get displayLabel => '$code - $number';

  static String buildNormalizedKey({
    String countryCode = defaultCountryCode,
    required int code,
    required int number,
  }) {
    final safeCountryCode = _normalizeCountryCode(countryCode);
    return '$safeCountryCode-$code-$number';
  }

  VehiclePlateModel copyWith({
    int? code,
    int? number,
    String? normalizedKey,
    String? countryCode,
    String? source,
    double? confidence,
    String? rawText,
  }) {
    final safeCountryCode = _normalizeCountryCode(
      countryCode ?? this.countryCode,
    );

    final safeCode = code ?? this.code;
    final safeNumber = number ?? this.number;

    return VehiclePlateModel(
      code: safeCode,
      number: safeNumber,
      countryCode: safeCountryCode,
      source: source == null
          ? this.source
          : VehiclePlateInputSource.normalize(source),
      confidence: confidence ?? this.confidence,
      rawText: rawText ?? this.rawText,
      normalizedKey:
          normalizedKey ??
          buildNormalizedKey(
            countryCode: safeCountryCode,
            code: safeCode,
            number: safeNumber,
          ),
    );
  }

  Map<String, dynamic> toMap() {
    return _removeNullValues({
      'countryCode': countryCode,
      'code': code,
      'number': number,
      'normalizedKey': normalizedKey,
      'displayLabel': displayLabel,
      'source': source,
      'confidence': confidence,
      'rawText': _stringOrNull(rawText),
    });
  }

  factory VehiclePlateModel.fromMap(Map<String, dynamic> map) {
    final code = _intFromMapValue(map['code']);
    final number = _intFromMapValue(map['number']);

    final countryCode = _normalizeCountryCode(
      _stringOrDefault(map['countryCode'], defaultCountryCode),
    );

    final existingKey = map['normalizedKey']?.toString().trim();

    return VehiclePlateModel(
      code: code,
      number: number,
      countryCode: countryCode,
      normalizedKey: existingKey != null && existingKey.isNotEmpty
          ? existingKey
          : buildNormalizedKey(
              countryCode: countryCode,
              code: code,
              number: number,
            ),
      source: VehiclePlateInputSource.normalize(
        _stringOrDefault(map['source'], VehiclePlateInputSource.manual),
      ),
      confidence: _safeConfidence(_doubleFromMapValue(map['confidence'])),
      rawText: _stringOrNull(map['rawText']?.toString()),
    );
  }

  static int _intFromMapValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString().trim() ?? '') ?? 0;
  }

  static double? _doubleFromMapValue(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString().trim() ?? '');
  }

  static double? _safeConfidence(double? value) {
    if (value == null || value.isNaN || value.isInfinite) return null;
    if (value < 0.0 || value > 1.0) return null;

    return value;
  }

  static String _normalizeCountryCode(String value) {
    final safeValue = value.trim().toUpperCase();

    if (safeValue.isEmpty) return defaultCountryCode;

    return safeValue;
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

  static Map<String, dynamic> _removeNullValues(Map<String, dynamic> map) {
    final output = Map<String, dynamic>.from(map);
    output.removeWhere((_, value) => value == null);
    return output;
  }
}

class VehiclePlateInputSource {
  const VehiclePlateInputSource._();

  static const String manual = 'manual';
  static const String ocr = 'ocr';
  static const String ocrCamera = 'ocr_camera';
  static const String ocrGallery = 'ocr_gallery';
  static const String editedAfterOcr = 'edited_after_ocr';

  static const Set<String> values = {
    manual,
    ocr,
    ocrCamera,
    ocrGallery,
    editedAfterOcr,
  };

  static bool isValid(String value) {
    return values.contains(value.trim());
  }

  static bool isOcr(String value) {
    final safeValue = normalize(value);

    return safeValue == ocr ||
        safeValue == ocrCamera ||
        safeValue == ocrGallery ||
        safeValue == editedAfterOcr;
  }

  static String normalize(String value) {
    final safeValue = value.trim();

    if (isValid(safeValue)) return safeValue;

    return manual;
  }
}
