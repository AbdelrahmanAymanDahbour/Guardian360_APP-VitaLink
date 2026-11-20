class AccidentEvidenceModel {
  const AccidentEvidenceModel({
    required this.id,
    required this.type,
    required this.status,
    required this.capturedAtClient,
    this.storagePath,
    this.downloadUrl,
    this.localPath,
    this.fileName,
    this.mimeType,
    this.sizeBytes,
    this.durationSeconds,
    this.width,
    this.height,
    this.note,
    this.witness,
    this.sortOrder = 0,
    this.purpose = AccidentEvidencePurpose.general,
    this.captureSource,
    this.metadata = const {},
  });

  final String id;

  /// Supported evidence types:
  /// image, video, audio, witness_statement.
  final String type;

  /// Evidence lifecycle:
  /// local / uploaded.
  final String status;

  /// Client-side capture time.
  /// This is useful for building a timeline of accident evidence.
  final DateTime capturedAtClient;

  /// Firebase Storage path after upload.
  final String? storagePath;

  /// Public or secured download URL after upload.
  final String? downloadUrl;

  /// Local device path.
  /// This must not be stored in Firestore unless explicitly used for local draft storage.
  final String? localPath;

  final String? fileName;
  final String? mimeType;
  final int? sizeBytes;
  final double? durationSeconds;
  final int? width;
  final int? height;
  final String? note;

  /// Professional evidence purpose inside the accident report.
  /// Examples: general, vehicle_plate, driver_license, damage_photo.
  final String purpose;

  /// How this evidence entered the report: camera, gallery, file_picker,
  /// ocr_camera, ocr_gallery.
  final String? captureSource;

  /// Firestore-safe extra context for insurance/police review.
  /// Examples: location snapshot, speed, OCR raw text, vehicle role.
  final Map<String, dynamic> metadata;

  /// Structured witness data when [type] is witness_statement.
  final AccidentWitnessModel? witness;

  /// Used to keep evidence ordered inside the report timeline.
  final int sortOrder;

  bool get isMedia {
    return type == AccidentEvidenceType.image ||
        type == AccidentEvidenceType.video ||
        type == AccidentEvidenceType.audio;
  }

  bool get isWitnessStatement {
    return type == AccidentEvidenceType.witnessStatement;
  }

  bool get isVehiclePlateEvidence {
    return purpose == AccidentEvidencePurpose.vehiclePlate;
  }

  bool get isUploaded {
    return status == AccidentEvidenceStatus.uploaded &&
        _hasText(storagePath) &&
        _hasText(downloadUrl);
  }

  bool get hasLocalReference {
    return _hasText(localPath);
  }

  bool get hasRemoteReference {
    return _hasText(storagePath) && _hasText(downloadUrl);
  }

  bool get isValid {
    if (!_hasText(id)) return false;
    if (!AccidentEvidenceType.isValid(type)) return false;
    if (!AccidentEvidenceStatus.isValid(status)) return false;
    if (!AccidentEvidencePurpose.isValid(purpose)) return false;

    final safeCaptureSource = captureSource?.trim();
    if (safeCaptureSource != null &&
        safeCaptureSource.isNotEmpty &&
        !AccidentEvidenceCaptureSource.isValid(safeCaptureSource)) {
      return false;
    }

    if (isMedia && !hasLocalReference && !hasRemoteReference) {
      return false;
    }

    if (isWitnessStatement && witness == null) {
      return false;
    }

    if (witness != null && !witness!.isValid) {
      return false;
    }

    return true;
  }

  AccidentEvidenceModel copyWith({
    String? id,
    String? type,
    String? status,
    DateTime? capturedAtClient,
    String? storagePath,
    String? downloadUrl,
    String? localPath,
    String? fileName,
    String? mimeType,
    int? sizeBytes,
    double? durationSeconds,
    int? width,
    int? height,
    String? note,
    AccidentWitnessModel? witness,
    int? sortOrder,
    String? purpose,
    String? captureSource,
    Map<String, dynamic>? metadata,
  }) {
    return AccidentEvidenceModel(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      capturedAtClient: capturedAtClient ?? this.capturedAtClient,
      storagePath: storagePath ?? this.storagePath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      localPath: localPath ?? this.localPath,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      width: width ?? this.width,
      height: height ?? this.height,
      note: note ?? this.note,
      witness: witness ?? this.witness,
      sortOrder: sortOrder ?? this.sortOrder,
      purpose: purpose == null
          ? this.purpose
          : AccidentEvidencePurpose.normalize(purpose),
      captureSource: captureSource == null
          ? this.captureSource
          : AccidentEvidenceCaptureSource.normalize(captureSource),
      metadata: metadata ?? this.metadata,
    );
  }

  /// Safe map for Firestore.
  ///
  /// By default, local device paths are not included to protect privacy and
  /// avoid saving device-specific paths in cloud documents.
  Map<String, dynamic> toMap({bool includeLocalPath = false}) {
    return _removeNullValues({
      'id': _stringOrNull(id),
      'type': AccidentEvidenceType.normalize(type),
      'status': AccidentEvidenceStatus.normalize(status),
      'purpose': AccidentEvidencePurpose.normalize(purpose),
      'captureSource': _normalizedCaptureSourceOrNull(captureSource),
      'capturedAtClient': capturedAtClient.toUtc().toIso8601String(),
      'storagePath': _stringOrNull(storagePath),
      'downloadUrl': _stringOrNull(downloadUrl),
      if (includeLocalPath) 'localPath': _stringOrNull(localPath),
      'fileName': _stringOrNull(fileName),
      'mimeType': _stringOrNull(mimeType),
      'sizeBytes': _validPositiveIntOrNull(sizeBytes),
      'durationSeconds': _validPositiveDoubleOrNull(durationSeconds),
      'width': _validPositiveIntOrNull(width),
      'height': _validPositiveIntOrNull(height),
      'note': _stringOrNull(note),
      'metadata': _safeMetadataOrNull(metadata),
      'witness': witness?.toMap(),
      'sortOrder': sortOrder < 0 ? 0 : sortOrder,
    });
  }

  factory AccidentEvidenceModel.fromMap(Map<String, dynamic> map) {
    return AccidentEvidenceModel(
      id: _stringOrDefault(map['id'], ''),
      type: AccidentEvidenceType.normalize(
        _stringOrDefault(map['type'], AccidentEvidenceType.image),
      ),
      status: AccidentEvidenceStatus.normalize(
        _stringOrDefault(map['status'], AccidentEvidenceStatus.local),
      ),
      capturedAtClient: _dateTimeFromValue(map['capturedAtClient']),
      storagePath: _stringOrNull(map['storagePath']?.toString()),
      downloadUrl: _stringOrNull(map['downloadUrl']?.toString()),
      localPath: _stringOrNull(map['localPath']?.toString()),
      fileName: _stringOrNull(map['fileName']?.toString()),
      mimeType: _stringOrNull(map['mimeType']?.toString()),
      sizeBytes: _validPositiveIntOrNull(_intFromValue(map['sizeBytes'])),
      durationSeconds: _validPositiveDoubleOrNull(
        _doubleFromValue(map['durationSeconds']),
      ),
      width: _validPositiveIntOrNull(_intFromValue(map['width'])),
      height: _validPositiveIntOrNull(_intFromValue(map['height'])),
      note: _stringOrNull(map['note']?.toString()),
      purpose: AccidentEvidencePurpose.normalize(
        _stringOrDefault(map['purpose'], AccidentEvidencePurpose.general),
      ),
      captureSource: _normalizedCaptureSourceOrNull(
        map['captureSource']?.toString(),
      ),
      metadata: map['metadata'] is Map
          ? _safeMetadata(Map<String, dynamic>.from(map['metadata'] as Map))
          : const {},
      witness: map['witness'] is Map<String, dynamic>
          ? AccidentWitnessModel.fromMap(
              Map<String, dynamic>.from(map['witness'] as Map),
            )
          : null,
      sortOrder: _intFromValue(map['sortOrder']) ?? 0,
    );
  }

  static DateTime _dateTimeFromValue(dynamic value) {
    if (value is DateTime) return value.toUtc();

    final parsed = DateTime.tryParse(value?.toString().trim() ?? '');

    if (parsed == null) return DateTime.now().toUtc();

    return parsed.toUtc();
  }

  static int? _intFromValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString().trim() ?? '');
  }

  static double? _doubleFromValue(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return double.tryParse(value?.toString().trim() ?? '');
  }

  static int? _validPositiveIntOrNull(int? value) {
    if (value == null || value < 0) return null;

    return value;
  }

  static double? _validPositiveDoubleOrNull(double? value) {
    if (value == null || value.isNaN || value.isInfinite || value < 0) {
      return null;
    }

    return value;
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

  static String? _normalizedCaptureSourceOrNull(String? value) {
    final safeValue = value?.trim();

    if (safeValue == null || safeValue.isEmpty) return null;

    return AccidentEvidenceCaptureSource.normalize(safeValue);
  }

  static Map<String, dynamic>? _safeMetadataOrNull(Map<String, dynamic> value) {
    final safeValue = _safeMetadata(value);

    if (safeValue.isEmpty) return null;

    return safeValue;
  }

  static Map<String, dynamic> _safeMetadata(Map<String, dynamic> value) {
    final output = <String, dynamic>{};

    for (final entry in value.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;

      final safeValue = _safeMetadataValue(entry.value);
      if (safeValue != null) {
        output[key] = safeValue;
      }
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
    if (value is Map) {
      return _safeMetadata(Map<String, dynamic>.from(value));
    }
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

class AccidentWitnessModel {
  const AccidentWitnessModel({this.name, this.phone, this.statement});

  final String? name;
  final String? phone;
  final String? statement;

  bool get isValid {
    return _hasText(name) || _hasText(phone) || _hasText(statement);
  }

  Map<String, dynamic> toMap() {
    return _removeNullValues({
      'name': _stringOrNull(name),
      'phone': _stringOrNull(phone),
      'statement': _stringOrNull(statement),
    });
  }

  factory AccidentWitnessModel.fromMap(Map<String, dynamic> map) {
    return AccidentWitnessModel(
      name: _stringOrNull(map['name']?.toString()),
      phone: _stringOrNull(map['phone']?.toString()),
      statement: _stringOrNull(map['statement']?.toString()),
    );
  }

  static bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
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

class AccidentEvidenceType {
  const AccidentEvidenceType._();

  static const String image = 'image';
  static const String video = 'video';
  static const String audio = 'audio';
  static const String witnessStatement = 'witness_statement';

  static const Set<String> values = {image, video, audio, witnessStatement};

  static bool isValid(String value) {
    return values.contains(value.trim());
  }

  static String normalize(String value) {
    final safeValue = value.trim();

    if (isValid(safeValue)) return safeValue;

    return image;
  }
}

class AccidentEvidenceStatus {
  const AccidentEvidenceStatus._();

  static const String local = 'local';
  static const String uploaded = 'uploaded';

  static const Set<String> values = {local, uploaded};

  static bool isValid(String value) {
    return values.contains(value.trim());
  }

  static String normalize(String value) {
    final safeValue = value.trim();

    if (isValid(safeValue)) return safeValue;

    return local;
  }
}

class AccidentEvidencePurpose {
  const AccidentEvidencePurpose._();

  static const String general = 'general';
  static const String vehiclePlate = 'vehicle_plate';
  static const String damagePhoto = 'damage_photo';
  static const String driverLicense = 'driver_license';
  static const String witness = 'witness';

  static const Set<String> values = {
    general,
    vehiclePlate,
    damagePhoto,
    driverLicense,
    witness,
  };

  static bool isValid(String value) {
    return values.contains(value.trim());
  }

  static String normalize(String value) {
    final safeValue = value.trim();

    if (isValid(safeValue)) return safeValue;

    return general;
  }
}

class AccidentEvidenceCaptureSource {
  const AccidentEvidenceCaptureSource._();

  static const String camera = 'camera';
  static const String gallery = 'gallery';
  static const String filePicker = 'file_picker';
  static const String ocrCamera = 'ocr_camera';
  static const String ocrGallery = 'ocr_gallery';

  static const Set<String> values = {
    camera,
    gallery,
    filePicker,
    ocrCamera,
    ocrGallery,
  };

  static bool isValid(String value) {
    return values.contains(value.trim());
  }

  static String normalize(String value) {
    final safeValue = value.trim();

    if (isValid(safeValue)) return safeValue;

    return filePicker;
  }
}
