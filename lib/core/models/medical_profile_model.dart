import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';

/// ==========================================
/// 🏥 Medical Profile Model - Guardian 360
/// ==========================================
/// Data model الرسمي للسجل الطبي.
///
/// ملاحظة معمارية:
/// - الشاشة الرسمية هي MedicalRecordScreen.
/// - المنطق الرسمي هو MedicalRecordViewModel.
/// - هذا الملف ليس شاشة وليس مسار onboarding.
/// - لا يحفظ قيماً افتراضية مضللة مثل "غير محدد" أو "لا يوجد".
/// - يسمح للمستخدم بكتابة "لا يوجد" بنفسه في الحقول الطبية الحرجة إذا كانت فعلاً لا تنطبق عليه.
class MedicalProfileModel {
  static const Object _unset = Object();

  /// الرقم الوطني الأردني يستخدم في التطبيق كـ 10 أرقام.
  /// هذا يمنع قيم غير منطقية مثل 322 أو أرقام ناقصة.
  static const int nationalIdLength = 10;

  /// نطاقات بشرية منطقية وليست تشخيصاً طبياً.
  /// الهدف منع الإدخالات العبثية مثل 50000 كغم أو 9999 سم.
  static const int minAge = 0;
  static const int maxAge = 120;

  static const double minWeightKg = 2;
  static const double maxWeightKg = 300;

  static const double minHeightCm = 45;
  static const double maxHeightCm = 250;

  static const int minFullNameLength = 3;
  static const int maxFullNameLength = 80;
  static const int minAddressLength = 3;
  static const int maxAddressLength = 160;
  static const int minMedicalTextLength = 2;
  static const int maxMedicalTextLength = 500;
  static const int maxNotesLength = 1000;

  final String userId;
  final String? fullName;
  final String? nationalId;
  final String? address;

  final DateTime? dateOfBirth;
  final int? age;

  final String? bloodType;
  final String? weight;
  final String? height;

  final String? chronicDiseases;
  final String? medications;
  final String? allergies;
  final String? notes;
  final String? gender;

  final bool isOrganDonor;
  final DateTime? lastUpdated;
  final double completionPercentage;

  const MedicalProfileModel({
    required this.userId,
    this.fullName,
    this.nationalId,
    this.address,
    this.dateOfBirth,
    this.age,
    this.bloodType,
    this.weight,
    this.height,
    this.chronicDiseases,
    this.medications,
    this.allergies,
    this.notes,
    this.gender,
    this.isOrganDonor = false,
    this.lastUpdated,
    this.completionPercentage = 0.0,
  });

  // ==========================================
  // Factory Constructors
  // ==========================================

  factory MedicalProfileModel.empty(String userId) {
    return MedicalProfileModel(
      userId: _cleanText(userId),
      completionPercentage: 0.0,
    );
  }

  factory MedicalProfileModel.fromMap(Map<String, dynamic> map) {
    final parsedDateOfBirth = _toDateTime(map['dateOfBirth']);

    final parsedAge =
        _toIntOrNull(map['age']) ??
        (parsedDateOfBirth != null ? calculateAge(parsedDateOfBirth) : null);

    final explicitCompletion = _toCompletionOrNull(
      map['completionPercentage'] ?? map['medicalProfileCompletion'],
    );

    final profile = MedicalProfileModel(
      userId: _stringOrEmpty(map['userId'] ?? map['uid']),
      fullName: normalizeFullName(map['fullName']),
      nationalId: normalizeNationalId(map['nationalId']),
      address: normalizeAddress(map['address']),
      dateOfBirth: _normalizeDateOfBirth(parsedDateOfBirth),
      age: normalizeAge(parsedAge),
      bloodType: normalizeBloodType(_trimToNull(map['bloodType'])),
      weight: normalizeWeight(map['weight']),
      height: normalizeHeight(map['height']),
      chronicDiseases: normalizeMedicalText(map['chronicDiseases']),
      medications: normalizeMedicalText(map['medications']),
      allergies: normalizeMedicalText(map['allergies']),
      notes: normalizeOptionalNotes(map['notes'] ?? map['medicalNotes']),
      gender: normalizeGender(_trimToNull(map['gender'])),
      isOrganDonor: _toBool(map['isOrganDonor'], fallback: false),
      lastUpdated: _toDateTime(
        map['lastUpdated'] ??
            map['updatedAt'] ??
            map['medicalProfileUpdatedAt'],
      ),
      completionPercentage: explicitCompletion ?? 0.0,
    );

    return profile.copyWith(
      completionPercentage: explicitCompletion ?? profile.calculateCompletion(),
    );
  }

  factory MedicalProfileModel.fromSharedPreferences(
    String userId,
    Map<String, Object?> prefs,
  ) {
    final dateOfBirth = _toDateTime(prefs['med_date_of_birth']);

    final parsedAge =
        _toIntOrNull(prefs['med_age']) ??
        (dateOfBirth != null ? calculateAge(dateOfBirth) : null);

    final profile = MedicalProfileModel(
      userId: _cleanText(userId),
      fullName: normalizeFullName(prefs['med_name']),
      nationalId: normalizeNationalId(prefs['med_national_id']),
      address: normalizeAddress(prefs['med_address']),
      dateOfBirth: _normalizeDateOfBirth(dateOfBirth),
      age: normalizeAge(parsedAge),
      bloodType: normalizeBloodType(_trimToNull(prefs['med_blood'])),
      weight: normalizeWeight(prefs['med_weight']),
      height: normalizeHeight(prefs['med_height']),
      chronicDiseases: normalizeMedicalText(prefs['med_diseases']),
      medications: normalizeMedicalText(prefs['med_meds']),
      allergies: normalizeMedicalText(prefs['med_allergies']),
      notes: normalizeOptionalNotes(prefs['med_notes']),
      gender: normalizeGender(_trimToNull(prefs['med_gender'])),
      isOrganDonor: _toBool(prefs['med_donor'], fallback: false),
      lastUpdated: _toDateTime(prefs['med_last_updated']),
    );

    return profile.copyWith(
      completionPercentage: profile.calculateCompletion(),
    );
  }

  // ==========================================
  // Serialization
  // ==========================================

  Map<String, dynamic> toMap() {
    return _removeNullValues({
      'userId': userId,
      'fullName': normalizedFullName,
      'nationalId': normalizedNationalId,
      'address': normalizedAddress,
      'dateOfBirth': validDateOfBirth?.toIso8601String(),
      'age': effectiveAge,
      'bloodType': normalizedBloodType,
      'weight': normalizedWeight,
      'height': normalizedHeight,
      'chronicDiseases': normalizedChronicDiseases,
      'medications': normalizedMedications,
      'allergies': normalizedAllergies,
      'notes': normalizedNotes,
      'gender': normalizedGender,
      'isOrganDonor': isOrganDonor,
      'lastUpdated': lastUpdated?.toIso8601String(),
      'completionPercentage': calculateCompletion(),
      'isMedicalProfileComplete': hasRequiredEmergencyData,
    });
  }

  Map<String, dynamic> toFirestoreMap() {
    return _removeNullValues({
      'userId': userId,
      'fullName': normalizedFullName ?? '',
      'nationalId': normalizedNationalId ?? '',
      'address': normalizedAddress ?? '',
      'dateOfBirth': validDateOfBirth != null
          ? Timestamp.fromDate(validDateOfBirth!)
          : null,
      'age': effectiveAge,
      'bloodType': normalizedBloodType ?? '',
      'weight': normalizedWeight ?? '',
      'height': normalizedHeight ?? '',
      'chronicDiseases': normalizedChronicDiseases ?? '',
      'medications': normalizedMedications ?? '',
      'allergies': normalizedAllergies ?? '',
      'notes': normalizedNotes ?? '',
      'gender': normalizedGender ?? '',
      'isOrganDonor': isOrganDonor,
      'completionPercentage': calculateCompletion(),
      'isMedicalProfileComplete': hasRequiredEmergencyData,
      'medicalProfileUpdatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Map<String, dynamic> toFirebaseUpdateMap() {
    return toFirestoreMap();
  }

  Map<String, String> toSharedPreferencesMap() {
    return {
      'med_name': normalizedFullName ?? '',
      'med_national_id': normalizedNationalId ?? '',
      'med_address': normalizedAddress ?? '',
      'med_date_of_birth': validDateOfBirth?.toIso8601String() ?? '',
      'med_age': effectiveAge?.toString() ?? '',
      'med_blood': normalizedBloodType ?? '',
      'med_weight': normalizedWeight ?? '',
      'med_height': normalizedHeight ?? '',
      'med_diseases': normalizedChronicDiseases ?? '',
      'med_meds': normalizedMedications ?? '',
      'med_allergies': normalizedAllergies ?? '',
      'med_notes': normalizedNotes ?? '',
      'med_gender': normalizedGender ?? '',
      'med_donor': isOrganDonor.toString(),
      'med_last_updated': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toEmergencySnapshot() {
    return _removeNullValues({
      'fullName': normalizedFullName ?? '',
      'nationalId': normalizedNationalId ?? '',
      'bloodType': normalizedBloodType ?? '',
      'chronicDiseases': normalizedChronicDiseases ?? '',
      'medications': normalizedMedications ?? '',
      'allergies': normalizedAllergies ?? '',
      'notes': normalizedNotes ?? '',
      'address': normalizedAddress ?? '',
      'weight': normalizedWeight ?? '',
      'height': normalizedHeight ?? '',
      'gender': normalizedGender ?? '',
      'dateOfBirth': validDateOfBirth?.toIso8601String(),
      'age': effectiveAge,
      'isOrganDonor': isOrganDonor,
      'isMedicalProfileComplete': hasRequiredEmergencyData,
    });
  }

  /// Backward compatibility.
  Map<String, dynamic> toSnapshot() => toEmergencySnapshot();

  // ==========================================
  // Copy With
  // ==========================================

  MedicalProfileModel copyWith({
    String? userId,
    Object? fullName = _unset,
    Object? nationalId = _unset,
    Object? address = _unset,
    Object? dateOfBirth = _unset,
    Object? age = _unset,
    Object? bloodType = _unset,
    Object? weight = _unset,
    Object? height = _unset,
    Object? chronicDiseases = _unset,
    Object? medications = _unset,
    Object? allergies = _unset,
    Object? notes = _unset,
    Object? gender = _unset,
    bool? isOrganDonor,
    Object? lastUpdated = _unset,
    double? completionPercentage,
  }) {
    return MedicalProfileModel(
      userId: userId ?? this.userId,
      fullName: identical(fullName, _unset)
          ? this.fullName
          : normalizeFullName(fullName),
      nationalId: identical(nationalId, _unset)
          ? this.nationalId
          : normalizeNationalId(nationalId),
      address: identical(address, _unset)
          ? this.address
          : normalizeAddress(address),
      dateOfBirth: identical(dateOfBirth, _unset)
          ? this.dateOfBirth
          : _normalizeDateOfBirth(dateOfBirth as DateTime?),
      age: identical(age, _unset) ? this.age : normalizeAge(age as int?),
      bloodType: identical(bloodType, _unset)
          ? this.bloodType
          : normalizeBloodType(_trimToNull(bloodType)),
      weight: identical(weight, _unset) ? this.weight : normalizeWeight(weight),
      height: identical(height, _unset) ? this.height : normalizeHeight(height),
      chronicDiseases: identical(chronicDiseases, _unset)
          ? this.chronicDiseases
          : normalizeMedicalText(chronicDiseases),
      medications: identical(medications, _unset)
          ? this.medications
          : normalizeMedicalText(medications),
      allergies: identical(allergies, _unset)
          ? this.allergies
          : normalizeMedicalText(allergies),
      notes: identical(notes, _unset)
          ? this.notes
          : normalizeOptionalNotes(notes),
      gender: identical(gender, _unset)
          ? this.gender
          : normalizeGender(_trimToNull(gender)),
      isOrganDonor: isOrganDonor ?? this.isOrganDonor,
      lastUpdated: identical(lastUpdated, _unset)
          ? this.lastUpdated
          : lastUpdated as DateTime?,
      completionPercentage: completionPercentage ?? this.completionPercentage,
    );
  }

  // ==========================================
  // Normalized Getters
  // ==========================================

  String? get normalizedFullName => normalizeFullName(fullName);

  String? get normalizedNationalId => normalizeNationalId(nationalId);

  String? get normalizedAddress => normalizeAddress(address);

  DateTime? get validDateOfBirth => _normalizeDateOfBirth(dateOfBirth);

  String? get normalizedBloodType => normalizeBloodType(bloodType);

  String? get normalizedWeight => normalizeWeight(weight);

  String? get normalizedHeight => normalizeHeight(height);

  String? get normalizedChronicDiseases =>
      normalizeMedicalText(chronicDiseases);

  String? get normalizedMedications => normalizeMedicalText(medications);

  String? get normalizedAllergies => normalizeMedicalText(allergies);

  String? get normalizedNotes => normalizeOptionalNotes(notes);

  String? get normalizedGender => normalizeGender(gender);

  int? get effectiveAge {
    if (validDateOfBirth != null) return calculateAge(validDateOfBirth!);
    return normalizeAge(age);
  }

  // ==========================================
  // Completion / Validation
  // ==========================================

  bool get hasValidFullName => isValidFullName(fullName);

  bool get hasValidNationalId => isValidNationalId(nationalId);

  bool get hasValidBloodType => BloodTypes.isValid(bloodType);

  bool get hasValidBirthInfo =>
      validDateOfBirth != null || effectiveAge != null;

  bool get hasValidWeight {
    final value = normalizedWeight;
    return value == null || isValidWeight(value);
  }

  bool get hasValidHeight {
    final value = normalizedHeight;
    return value == null || isValidHeight(value);
  }

  bool get hasRequiredEmergencyData {
    return hasValidFullName &&
        hasValidNationalId &&
        hasValidBloodType &&
        _isFilled(normalizedChronicDiseases) &&
        _isFilled(normalizedMedications) &&
        _isFilled(normalizedAllergies);
  }

  bool get hasBirthInfo => hasValidBirthInfo;

  bool get hasAnyData {
    return [
          normalizedFullName,
          normalizedNationalId,
          normalizedAddress,
          normalizedBloodType,
          normalizedWeight,
          normalizedHeight,
          normalizedChronicDiseases,
          normalizedMedications,
          normalizedAllergies,
          normalizedNotes,
        ].any(_isFilled) ||
        validDateOfBirth != null ||
        effectiveAge != null ||
        isOrganDonor;
  }

  bool get isComplete => hasRequiredEmergencyData;

  bool get isEmpty => !hasAnyData;

  bool get hasCriticalInfo =>
      _isFilled(normalizedChronicDiseases) ||
      _isFilled(normalizedMedications) ||
      _isFilled(normalizedAllergies);

  double calculateCompletion() {
    const total = 10;
    var filled = 0;

    if (hasValidFullName) filled++;
    if (hasValidNationalId) filled++;
    if (hasValidBloodType) filled++;
    if (_isFilled(normalizedChronicDiseases)) filled++;
    if (_isFilled(normalizedMedications)) filled++;
    if (_isFilled(normalizedAllergies)) filled++;
    if (hasValidBirthInfo) filled++;
    if (_isFilled(normalizedWeight) && isValidWeight(normalizedWeight))
      filled++;
    if (_isFilled(normalizedHeight) && isValidHeight(normalizedHeight))
      filled++;
    if (_isFilled(normalizedAddress)) filled++;

    return (filled / total).clamp(0.0, 1.0);
  }

  List<String> validateForEmergencySave() {
    final errors = <String>[];

    if (!isValidFullName(fullName)) {
      errors.add('medical.validation.full_name_invalid'.tr());
    }

    if (!isValidNationalId(nationalId)) {
      errors.add(
        'medical.validation.national_id_invalid'.tr(
          namedArgs: {'length': nationalIdLength.toString()},
        ),
      );
    }

    if (!BloodTypes.isValid(bloodType)) {
      errors.add('medical.validation.blood_type_required'.tr());
    }

    if (!_isFilled(normalizedAllergies)) {
      errors.add('medical.validation.allergies_required'.tr());
    } else if (!isValidMedicalText(allergies)) {
      errors.add('medical.validation.allergies_invalid'.tr());
    }

    if (!_isFilled(normalizedMedications)) {
      errors.add('medical.validation.medications_required'.tr());
    } else if (!isValidMedicalText(medications)) {
      errors.add('medical.validation.medications_invalid'.tr());
    }

    if (!_isFilled(normalizedChronicDiseases)) {
      errors.add('medical.validation.chronic_diseases_required'.tr());
    } else if (!isValidMedicalText(chronicDiseases)) {
      errors.add('medical.validation.chronic_diseases_invalid'.tr());
    }

    if (_isFilled(address) && !isValidAddress(address)) {
      errors.add('medical.validation.address_invalid'.tr());
    }

    if (_isFilled(weight) && !isValidWeight(weight)) {
      errors.add(
        'medical.validation.weight_invalid'.tr(
          namedArgs: {
            'min': minWeightKg.toInt().toString(),
            'max': maxWeightKg.toInt().toString(),
          },
        ),
      );
    }

    if (_isFilled(height) && !isValidHeight(height)) {
      errors.add(
        'medical.validation.height_invalid'.tr(
          namedArgs: {
            'min': minHeightCm.toInt().toString(),
            'max': maxHeightCm.toInt().toString(),
          },
        ),
      );
    }

    if (dateOfBirth != null && !isValidBirthDate(dateOfBirth)) {
      errors.add('medical.validation.birth_date_invalid'.tr());
    }

    if (age != null && !isValidAge(age)) {
      errors.add('medical.validation.age_invalid'.tr());
    }

    return errors;
  }

  static List<String> validateRawOptionalInputs({
    String? age,
    String? weight,
    String? height,
    String? address,
    String? notes,
  }) {
    final errors = <String>[];

    if (_isFilled(age) && !isValidAgeText(age)) {
      errors.add('medical.validation.age_invalid'.tr());
    }

    if (_isFilled(weight) && !isValidWeightText(weight)) {
      errors.add(
        'medical.validation.weight_invalid'.tr(
          namedArgs: {
            'min': minWeightKg.toInt().toString(),
            'max': maxWeightKg.toInt().toString(),
          },
        ),
      );
    }

    if (_isFilled(height) && !isValidHeightText(height)) {
      errors.add(
        'medical.validation.height_invalid'.tr(
          namedArgs: {
            'min': minHeightCm.toInt().toString(),
            'max': maxHeightCm.toInt().toString(),
          },
        ),
      );
    }

    if (_isFilled(address) && !isValidAddress(address)) {
      errors.add('medical.validation.address_invalid'.tr());
    }

    if (_isFilled(notes) && !isValidNotes(notes)) {
      errors.add('medical.validation.notes_invalid'.tr());
    }

    return errors;
  }

  String get statusText {
    final completion = calculateCompletion();

    if (completion == 0.0) return 'لم يتم البدء';
    if (!hasRequiredEmergencyData) return 'غير مكتمل';
    if (completion < 0.9) return 'مكتمل للطوارئ';
    return 'مكتمل';
  }

  String get completionText {
    return '${(calculateCompletion() * 100).round()}%';
  }

  // ==========================================
  // Public Validation Helpers for ViewModel/UI
  // ==========================================

  static bool isValidFullName(String? value) {
    final text = normalizeFullName(value);
    if (text == null || text.length < minFullNameLength) return false;
    if (text.length > maxFullNameLength) return false;
    if (_hasUnsafeControlCharacters(text)) return false;
    if (!_hasLetter(text)) return false;
    if (!_hasOnlyNameCharacters(text)) return false;
    return !_containsDigits(text);
  }

  static bool isValidNationalId(String? value) {
    final text = _trimToNull(value);
    if (text == null) return false;

    final normalized = _normalizeArabicDigits(text);
    return RegExp(r'^\d{10}$').hasMatch(normalized);
  }

  static bool isValidAddress(String? value) {
    final text = normalizeAddress(value);
    if (text == null) return false;
    if (text.length < minAddressLength || text.length > maxAddressLength) {
      return false;
    }
    if (_hasUnsafeControlCharacters(text)) return false;
    return _hasMeaningfulContent(text);
  }

  static bool isValidWeight(String? value) {
    final parsed = _toPositiveDoubleOrNull(normalizeWeight(value));
    if (parsed == null) return false;
    return parsed >= minWeightKg && parsed <= maxWeightKg;
  }

  static bool isValidWeightText(String? value) {
    final parsed = _toStrictPositiveDoubleOrNull(value);
    if (parsed == null) return false;
    return parsed >= minWeightKg && parsed <= maxWeightKg;
  }

  static bool isValidHeight(String? value) {
    final parsed = _toPositiveDoubleOrNull(normalizeHeight(value));
    if (parsed == null) return false;
    return parsed >= minHeightCm && parsed <= maxHeightCm;
  }

  static bool isValidHeightText(String? value) {
    final parsed = _toStrictPositiveDoubleOrNull(value);
    if (parsed == null) return false;
    return parsed >= minHeightCm && parsed <= maxHeightCm;
  }

  static bool isValidAge(int? value) {
    return value != null && value >= minAge && value <= maxAge;
  }

  static bool isValidAgeText(String? value) {
    final text = _trimToNull(value);
    if (text == null) return false;

    final normalized = _normalizeArabicDigits(text);
    if (!RegExp(r'^\d+$').hasMatch(normalized)) return false;

    return isValidAge(int.tryParse(normalized));
  }

  static bool isValidBirthDate(DateTime? value) {
    final date = _normalizeDateOnly(value);
    if (date == null) return false;

    final now = _normalizeDateOnly(DateTime.now())!;
    final oldestAllowed = DateTime(now.year - maxAge, now.month, now.day);

    return !date.isAfter(now) && !date.isBefore(oldestAllowed);
  }

  static bool isValidMedicalText(String? value) {
    final text = normalizeMedicalText(value);
    if (text == null || text.length < minMedicalTextLength) return false;
    if (text.length > maxMedicalTextLength) return false;
    if (_hasUnsafeControlCharacters(text)) return false;
    return _hasMeaningfulContent(text);
  }

  static bool isValidNotes(String? value) {
    final text = normalizeOptionalNotes(value);
    if (text == null) return true;
    if (text.length > maxNotesLength) return false;
    return !_hasUnsafeControlCharacters(text);
  }

  // ==========================================
  // Public Normalizers
  // ==========================================

  static String? normalizeFullName(dynamic value) {
    final text = _trimToNull(value);
    if (text == null) return null;
    return text;
  }

  static String? normalizeNationalId(dynamic value) {
    final text = _trimToNull(value);
    if (text == null) return null;

    final digits = _normalizeArabicDigits(text).replaceAll(RegExp(r'\D'), '');
    return digits.isEmpty ? null : digits;
  }

  static String? normalizeAddress(dynamic value) {
    final text = _trimToNull(value);
    if (text == null) return null;
    return text;
  }

  static String? normalizeWeight(dynamic value) {
    return _normalizeDecimalText(value);
  }

  static String? normalizeHeight(dynamic value) {
    return _normalizeDecimalText(value);
  }

  static String? normalizeMedicalText(dynamic value) {
    final text = _trimToNull(value);
    if (text == null) return null;
    return text;
  }

  static String? normalizeOptionalNotes(dynamic value) {
    final text = _trimToNull(value);
    if (text == null) return null;
    return text;
  }

  static String? normalizeBloodType(String? value) {
    final safeValue = value?.trim();
    if (safeValue == null || safeValue.isEmpty) return null;

    if (BloodTypes.all.contains(safeValue)) return safeValue;

    return null;
  }

  static String? normalizeGender(String? value) {
    final safeValue = value?.trim();
    if (safeValue == null || safeValue.isEmpty) return null;

    if (Genders.all.contains(safeValue)) return safeValue;

    return null;
  }

  // ==========================================
  // Static Helpers
  // ==========================================

  static int calculateAge(DateTime dateOfBirth) {
    final validDate = _normalizeDateOfBirth(dateOfBirth);
    if (validDate == null) return 0;

    final now = DateTime.now();

    var calculatedAge = now.year - validDate.year;

    final hadBirthdayThisYear =
        now.month > validDate.month ||
        (now.month == validDate.month && now.day >= validDate.day);

    if (!hadBirthdayThisYear) {
      calculatedAge--;
    }

    return calculatedAge.clamp(minAge, maxAge);
  }

  static bool _isFilled(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  static String _stringOrEmpty(dynamic value) {
    return _trimToNull(value) ?? '';
  }

  static String _cleanText(dynamic value) {
    return value?.toString().trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
  }

  static String? _trimToNull(dynamic value) {
    final text = _cleanText(value);
    return text.isEmpty ? null : text;
  }

  static bool _containsDigits(String value) {
    return RegExp(r'\d').hasMatch(_normalizeArabicDigits(value));
  }

  static bool _hasLetter(String value) {
    return RegExp(r'[A-Za-z\u0600-\u06FF]').hasMatch(value);
  }

  static bool _hasMeaningfulContent(String value) {
    return RegExp(
      r'[A-Za-z0-9\u0600-\u06FF]',
    ).hasMatch(_normalizeArabicDigits(value));
  }

  static bool _hasOnlyNameCharacters(String value) {
    return RegExp(r"^[A-Za-z\u0600-\u06FF\s\-'’.,]+$").hasMatch(value);
  }

  static bool _hasUnsafeControlCharacters(String value) {
    for (final unit in value.codeUnits) {
      final allowedWhitespace = unit == 9 || unit == 10 || unit == 13;
      if (unit < 32 && !allowedWhitespace) return true;
      if (unit == 127) return true;
    }

    return false;
  }

  static bool _toBool(dynamic value, {required bool fallback}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;

    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (['true', '1', 'yes', 'y'].contains(normalized)) return true;
      if (['false', '0', 'no', 'n'].contains(normalized)) return false;
    }

    return fallback;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return _normalizeDateOnly(value);
    if (value is Timestamp) return _normalizeDateOnly(value.toDate());
    if (value is int) {
      return _normalizeDateOnly(DateTime.fromMillisecondsSinceEpoch(value));
    }
    if (value is num) {
      return _normalizeDateOnly(
        DateTime.fromMillisecondsSinceEpoch(value.toInt()),
      );
    }
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return null;
      return _normalizeDateOnly(DateTime.tryParse(text));
    }
    return null;
  }

  static DateTime? _normalizeDateOnly(DateTime? value) {
    if (value == null) return null;
    return DateTime(value.year, value.month, value.day);
  }

  static DateTime? _normalizeDateOfBirth(DateTime? value) {
    final date = _normalizeDateOnly(value);
    if (date == null) return null;

    if (!isValidBirthDate(date)) return null;

    return date;
  }

  static int? _toIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();

    if (value is String) {
      final normalized = _normalizeArabicDigits(value.trim());
      return int.tryParse(normalized);
    }

    return null;
  }

  static int? normalizeAge(int? value) {
    if (!isValidAge(value)) return null;
    return value;
  }

  static double? _toCompletionOrNull(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      final result = value.toDouble();
      if (result.isNaN || result.isInfinite) return null;
      return result.clamp(0.0, 1.0).toDouble();
    }
    if (value is String) {
      final result = double.tryParse(_normalizeArabicDigits(value.trim()));
      if (result == null || result.isNaN || result.isInfinite) return null;
      return result.clamp(0.0, 1.0).toDouble();
    }
    return null;
  }

  static double? _toPositiveDoubleOrNull(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;

    final parsed = double.tryParse(_normalizeArabicDigits(text));
    if (parsed == null || parsed.isNaN || parsed.isInfinite || parsed <= 0) {
      return null;
    }

    return parsed;
  }

  static double? _toStrictPositiveDoubleOrNull(String? value) {
    final text = _trimToNull(value);
    if (text == null) return null;

    final normalized = _normalizeArabicDigits(text).replaceAll(',', '.');

    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(normalized)) return null;

    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed.isNaN || parsed.isInfinite || parsed <= 0) {
      return null;
    }

    return parsed;
  }

  static String? _normalizeDecimalText(dynamic value) {
    final text = _trimToNull(value);
    if (text == null) return null;

    var normalized = _normalizeArabicDigits(
      text,
    ).replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');

    if (normalized.isEmpty) return null;

    final firstDot = normalized.indexOf('.');
    if (firstDot != -1) {
      final beforeDot = normalized.substring(0, firstDot + 1);
      final afterDot = normalized.substring(firstDot + 1).replaceAll('.', '');
      normalized = beforeDot + afterDot;
    }

    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed.isNaN || parsed.isInfinite || parsed <= 0) {
      return null;
    }

    if (parsed % 1 == 0) {
      return parsed.toInt().toString();
    }

    return parsed.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
  }

  static String _normalizeArabicDigits(String value) {
    const arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const easternArabicIndic = [
      '۰',
      '۱',
      '۲',
      '۳',
      '۴',
      '۵',
      '۶',
      '۷',
      '۸',
      '۹',
    ];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    var result = value;

    for (var i = 0; i < englishDigits.length; i++) {
      result = result.replaceAll(arabicIndic[i], englishDigits[i]);
      result = result.replaceAll(easternArabicIndic[i], englishDigits[i]);
    }

    return result;
  }

  static Map<String, dynamic> _removeNullValues(Map<String, dynamic> map) {
    final result = Map<String, dynamic>.from(map);
    result.removeWhere((_, value) => value == null);
    return result;
  }
}

/// ==========================================
/// 🩸 Blood Types Constants
/// ==========================================
class BloodTypes {
  static const String aPositive = 'A+';
  static const String aNegative = 'A-';
  static const String bPositive = 'B+';
  static const String bNegative = 'B-';
  static const String oPositive = 'O+';
  static const String oNegative = 'O-';
  static const String abPositive = 'AB+';
  static const String abNegative = 'AB-';

  /// للعرض فقط، لا يُحفظ كقيمة افتراضية.
  static const String unknown = 'غير محدد';

  static const List<String> all = [
    aPositive,
    aNegative,
    bPositive,
    bNegative,
    oPositive,
    oNegative,
    abPositive,
    abNegative,
  ];

  static const List<String> allWithUnknown = [unknown, ...all];

  static bool isValid(String? value) {
    final safeValue = value?.trim();
    if (safeValue == null || safeValue.isEmpty) return false;
    return all.contains(safeValue);
  }
}

/// ==========================================
/// 👤 Gender Constants
/// ==========================================
class Genders {
  static const String male = 'male';
  static const String female = 'female';

  static const List<String> all = [male, female];

  static bool isValid(String? value) {
    final safeValue = value?.trim();
    if (safeValue == null || safeValue.isEmpty) return false;
    return all.contains(safeValue);
  }
}
