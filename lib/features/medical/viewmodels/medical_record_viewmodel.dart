import 'dart:async';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/models/medical_profile_model.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../auth/services/firebase_auth_service.dart';

class MedicalRecordViewModel extends ChangeNotifier {
  MedicalRecordViewModel({
    FirebaseAuthService? authService,
    FirebaseService? firebaseService,
    BiometricService? biometricService,
  }) : _authService = authService ?? FirebaseAuthService(),
       _firebaseService = firebaseService ?? FirebaseService(),
       _biometricService = biometricService ?? BiometricService() {
    unawaited(_init());
  }

  final FirebaseAuthService _authService;
  final FirebaseService _firebaseService;
  final BiometricService _biometricService;

  final nameController = TextEditingController();
  final nationalIdController = TextEditingController();
  final addressController = TextEditingController();
  final ageController = TextEditingController();
  final weightController = TextEditingController();
  final heightController = TextEditingController();
  final allergiesController = TextEditingController();
  final medicationsController = TextEditingController();
  final diseasesController = TextEditingController();
  final notesController = TextEditingController();

  DateTime? dateOfBirth;
  String? selectedBloodType;
  String? selectedGender;
  bool isOrganDonor = false;

  bool isAuthenticated = false;
  bool isAuthChecking = true;
  bool isSaving = false;
  bool hasExistingSecureRecord = false;

  String errorMessage = '';
  String successMessage = '';

  final List<String> bloodTypes = BloodTypes.all;

  bool _isDisposed = false;
  bool _listenersAttached = false;

  // ==========================================
  // Core getters
  // ==========================================

  bool get hasDateOfBirth => dateOfBirth != null;

  int? get calculatedAge {
    if (dateOfBirth != null) {
      return MedicalProfileModel.calculateAge(dateOfBirth!);
    }

    return _parseAge(ageController.text);
  }

  MedicalProfileModel get currentProfile => _buildProfileFromControllers();

  bool get isMedicalReadyForEmergency =>
      currentProfile.hasRequiredEmergencyData;

  double get completionPercentage => currentProfile.calculateCompletion();

  bool get hasUnsavedInput => currentProfile.hasAnyData;

  // ==========================================
  // Field state helpers for UI
  // ==========================================
  // هذه الدوال لا تحفظ ولا تعدل بيانات.
  // فقط تساعد الشاشة على تلوين الأيقونات والحقول بشكل منطقي.

  MedicalFieldState getFieldState(MedicalRecordField field) {
    switch (field) {
      case MedicalRecordField.fullName:
        return _stateForRequiredText(
          nameController.text,
          MedicalProfileModel.isValidFullName,
        );

      case MedicalRecordField.nationalId:
        return _stateForRequiredText(
          nationalIdController.text,
          MedicalProfileModel.isValidNationalId,
        );

      case MedicalRecordField.address:
        return _stateForOptionalText(
          addressController.text,
          MedicalProfileModel.isValidAddress,
        );

      case MedicalRecordField.dateOfBirth:
        if (dateOfBirth == null) return MedicalFieldState.empty;
        return MedicalProfileModel.isValidBirthDate(dateOfBirth)
            ? MedicalFieldState.valid
            : MedicalFieldState.invalid;

      case MedicalRecordField.age:
        final age = _parseAge(ageController.text);
        if (ageController.text.trim().isEmpty) return MedicalFieldState.empty;
        return MedicalProfileModel.isValidAge(age)
            ? MedicalFieldState.valid
            : MedicalFieldState.invalid;

      case MedicalRecordField.weight:
        return _stateForOptionalText(
          weightController.text,
          MedicalProfileModel.isValidWeight,
        );

      case MedicalRecordField.height:
        return _stateForOptionalText(
          heightController.text,
          MedicalProfileModel.isValidHeight,
        );

      case MedicalRecordField.bloodType:
        if ((selectedBloodType ?? '').trim().isEmpty) {
          return MedicalFieldState.empty;
        }
        return BloodTypes.isValid(selectedBloodType)
            ? MedicalFieldState.valid
            : MedicalFieldState.invalid;

      case MedicalRecordField.allergies:
        return _stateForRequiredText(
          allergiesController.text,
          MedicalProfileModel.isValidMedicalText,
        );

      case MedicalRecordField.medications:
        return _stateForRequiredText(
          medicationsController.text,
          MedicalProfileModel.isValidMedicalText,
        );

      case MedicalRecordField.chronicDiseases:
        return _stateForRequiredText(
          diseasesController.text,
          MedicalProfileModel.isValidMedicalText,
        );

      case MedicalRecordField.notes:
        return notesController.text.trim().isEmpty
            ? MedicalFieldState.empty
            : MedicalFieldState.valid;

      case MedicalRecordField.gender:
        if ((selectedGender ?? '').trim().isEmpty) {
          return MedicalFieldState.empty;
        }
        return Genders.isValid(selectedGender)
            ? MedicalFieldState.valid
            : MedicalFieldState.invalid;
    }
  }

  bool isFieldValid(MedicalRecordField field) {
    return getFieldState(field) == MedicalFieldState.valid;
  }

  bool isFieldInvalid(MedicalRecordField field) {
    return getFieldState(field) == MedicalFieldState.invalid;
  }

  bool isFieldFilled(MedicalRecordField field) {
    return getFieldState(field) != MedicalFieldState.empty;
  }

  MedicalFieldState _stateForRequiredText(
    String value,
    bool Function(String?) validator,
  ) {
    if (value.trim().isEmpty) return MedicalFieldState.empty;
    return validator(value)
        ? MedicalFieldState.valid
        : MedicalFieldState.invalid;
  }

  MedicalFieldState _stateForOptionalText(
    String value,
    bool Function(String?) validator,
  ) {
    if (value.trim().isEmpty) return MedicalFieldState.empty;
    return validator(value)
        ? MedicalFieldState.valid
        : MedicalFieldState.invalid;
  }

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // ==========================================
  // Init / Authentication
  // ==========================================

  Future<void> _init() async {
    isAuthChecking = true;
    errorMessage = '';
    successMessage = '';
    isAuthenticated = false;
    _safeNotify();

    _attachProgressListeners();

    try {
      await _detectExistingRecord();

      // لا نفتح السجل الطبي مباشرة.
      // السجل الطبي حساس، لذلك يبقى مقفلاً حتى يضغط المستخدم زر فتح السجل
      // وتظهر نافذة النظام الأصلية للبصمة/الوجه/رمز الجهاز.
      isAuthenticated = false;
    } catch (e, stackTrace) {
      errorMessage = 'medical.errors.init_failed'.tr();
      isAuthenticated = false;
      debugPrint('❌ MedicalRecordViewModel init error: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      isAuthChecking = false;
      _safeNotify();
    }
  }

  void _attachProgressListeners() {
    if (_listenersAttached) return;

    for (final controller in [
      nameController,
      nationalIdController,
      addressController,
      ageController,
      weightController,
      heightController,
      allergiesController,
      medicationsController,
      diseasesController,
      notesController,
    ]) {
      controller.addListener(_updateProgress);
    }

    _listenersAttached = true;
  }

  void _updateProgress() {
    _safeNotify();
  }

  Future<void> _detectExistingRecord() async {
    final user = _authService.currentUser;

    // 🔒 SECURITY FIX: Only proceed if user is authenticated
    if (user == null) {
      hasExistingSecureRecord = false;
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // 🔒 SECURITY FIX: Use uid-prefixed keys for complete data isolation
    final uidPrefix = 'med_${user.uid}_';

    final localProfile = MedicalProfileModel.fromSharedPreferences(user.uid, {
      'med_name': prefs.getString('${uidPrefix}name'),
      'med_national_id': prefs.getString('${uidPrefix}national_id'),
      'med_address': prefs.getString('${uidPrefix}address'),
      'med_date_of_birth': prefs.getString('${uidPrefix}date_of_birth'),
      'med_age': prefs.getString('${uidPrefix}age'),
      'med_blood': prefs.getString('${uidPrefix}blood'),
      'med_weight': prefs.getString('${uidPrefix}weight'),
      'med_height': prefs.getString('${uidPrefix}height'),
      'med_allergies': prefs.getString('${uidPrefix}allergies'),
      'med_meds': prefs.getString('${uidPrefix}meds'),
      'med_diseases': prefs.getString('${uidPrefix}diseases'),
      'med_notes': prefs.getString('${uidPrefix}notes'),
      'med_gender': prefs.getString('${uidPrefix}gender'),
      'med_donor': prefs.getBool('${uidPrefix}donor'),
    });

    var hasRemoteMedicalRecord = false;

    // 🔒 SECURITY FIX: Query Firestore ONLY by uid (never by phone/email)
    final userResult = await _firebaseService.getUser(user.uid);

    if (userResult.isSuccess && userResult.data != null) {
      final remoteProfile = MedicalProfileModel.fromMap({
        ...userResult.data!,
        'userId': user.uid,
      });

      hasRemoteMedicalRecord =
          userResult.data!['isMedicalProfileComplete'] == true ||
          remoteProfile.hasAnyData;
    }

    hasExistingSecureRecord = localProfile.hasAnyData || hasRemoteMedicalRecord;
  }

  Future<void> authenticateUser() async {
    if (isAuthChecking) return;

    isAuthChecking = true;
    errorMessage = '';
    successMessage = '';
    _safeNotify();

    try {
      final authResult = await _biometricService.authenticateForMedicalRecord();

      if (!authResult.isSuccess) {
        isAuthenticated = false;
        errorMessage = authResult.message;
        return;
      }

      isAuthenticated = true;
      errorMessage = '';
      await loadData();
    } catch (e, stackTrace) {
      isAuthenticated = false;
      errorMessage = 'medical.errors.auth_failed'.tr();
      debugPrint('❌ MedicalRecordViewModel auth error: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      isAuthChecking = false;
      _safeNotify();
    }
  }

  Future<void> retryAuth() async {
    await authenticateUser();
  }

  // ==========================================
  // Loading
  // ==========================================

  Future<void> loadData() async {
    try {
      final user = _authService.currentUser;

      // 🔒 SECURITY FIX: Only proceed if user is authenticated
      if (user == null) {
        errorMessage = 'medical.errors.user_not_signed_in'.tr();
        _safeNotify();
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // 🔒 SECURITY FIX: Use uid-prefixed keys for complete data isolation
      final uidPrefix = 'med_${user.uid}_';

      var profile = MedicalProfileModel.fromSharedPreferences(user.uid, {
        'med_name': prefs.getString('${uidPrefix}name'),
        'med_national_id': prefs.getString('${uidPrefix}national_id'),
        'med_address': prefs.getString('${uidPrefix}address'),
        'med_date_of_birth': prefs.getString('${uidPrefix}date_of_birth'),
        'med_age': prefs.getString('${uidPrefix}age'),
        'med_blood': prefs.getString('${uidPrefix}blood'),
        'med_weight': prefs.getString('${uidPrefix}weight'),
        'med_height': prefs.getString('${uidPrefix}height'),
        'med_allergies': prefs.getString('${uidPrefix}allergies'),
        'med_meds': prefs.getString('${uidPrefix}meds'),
        'med_diseases': prefs.getString('${uidPrefix}diseases'),
        'med_notes': prefs.getString('${uidPrefix}notes'),
        'med_gender': prefs.getString('${uidPrefix}gender'),
        'med_donor': prefs.getBool('${uidPrefix}donor'),
      });

      // 🔒 SECURITY FIX: Query Firestore ONLY by uid (never by phone/email)
      final userResult = await _firebaseService.getUser(user.uid);

      if (userResult.isSuccess && userResult.data != null) {
        final remoteProfile = MedicalProfileModel.fromMap({
          ...userResult.data!,
          'userId': user.uid,
        });

        profile = _mergeRemoteOverLocal(local: profile, remote: remoteProfile);
      }

      _applyProfileToControllers(profile);
    } catch (e, stackTrace) {
      errorMessage = 'medical.errors.load_failed'.tr();
      debugPrint('❌ MedicalRecordViewModel loadData error: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _safeNotify();
    }
  }

  MedicalProfileModel _mergeRemoteOverLocal({
    required MedicalProfileModel local,
    required MedicalProfileModel remote,
  }) {
    return local.copyWith(
      userId: remote.userId.isNotEmpty ? remote.userId : local.userId,
      fullName: _preferValidText(
        remote.normalizedFullName,
        local.normalizedFullName,
        MedicalProfileModel.isValidFullName,
      ),
      nationalId: _preferValidText(
        remote.normalizedNationalId,
        local.normalizedNationalId,
        MedicalProfileModel.isValidNationalId,
      ),
      address: _preferOptionalText(
        remote.normalizedAddress,
        local.normalizedAddress,
      ),
      dateOfBirth: remote.validDateOfBirth ?? local.validDateOfBirth,
      age: remote.effectiveAge ?? local.effectiveAge,
      bloodType: BloodTypes.isValid(remote.normalizedBloodType)
          ? remote.normalizedBloodType
          : local.normalizedBloodType,
      weight: _preferValidText(
        remote.normalizedWeight,
        local.normalizedWeight,
        MedicalProfileModel.isValidWeight,
      ),
      height: _preferValidText(
        remote.normalizedHeight,
        local.normalizedHeight,
        MedicalProfileModel.isValidHeight,
      ),
      chronicDiseases: _preferOptionalText(
        remote.normalizedChronicDiseases,
        local.normalizedChronicDiseases,
      ),
      medications: _preferOptionalText(
        remote.normalizedMedications,
        local.normalizedMedications,
      ),
      allergies: _preferOptionalText(
        remote.normalizedAllergies,
        local.normalizedAllergies,
      ),
      notes: _preferOptionalText(remote.normalizedNotes, local.normalizedNotes),
      gender: Genders.isValid(remote.normalizedGender)
          ? remote.normalizedGender
          : local.normalizedGender,
      isOrganDonor: remote.isOrganDonor || local.isOrganDonor,
      completionPercentage: remote.calculateCompletion(),
      lastUpdated: remote.lastUpdated ?? local.lastUpdated,
    );
  }

  String? _preferValidText(
    String? remoteValue,
    String? localValue,
    bool Function(String?) validator,
  ) {
    final remote = remoteValue?.trim();
    if (remote != null && remote.isNotEmpty && validator(remote)) {
      return remote;
    }

    final local = localValue?.trim();
    if (local != null && local.isNotEmpty && validator(local)) {
      return local;
    }

    return null;
  }

  String? _preferOptionalText(String? remoteValue, String? localValue) {
    final remote = remoteValue?.trim();
    if (remote != null && remote.isNotEmpty) return remote;

    final local = localValue?.trim();
    if (local != null && local.isNotEmpty) return local;

    return null;
  }

  void _applyProfileToControllers(MedicalProfileModel profile) {
    nameController.text = profile.normalizedFullName ?? '';
    nationalIdController.text = profile.normalizedNationalId ?? '';
    addressController.text = profile.normalizedAddress ?? '';

    dateOfBirth = profile.validDateOfBirth;

    ageController.text = profile.effectiveAge?.toString() ?? '';
    selectedBloodType = profile.normalizedBloodType;
    selectedGender = profile.normalizedGender;

    weightController.text = profile.normalizedWeight ?? '';
    heightController.text = profile.normalizedHeight ?? '';

    allergiesController.text = profile.normalizedAllergies ?? '';
    medicationsController.text = profile.normalizedMedications ?? '';
    diseasesController.text = profile.normalizedChronicDiseases ?? '';
    notesController.text = profile.normalizedNotes ?? '';

    isOrganDonor = profile.isOrganDonor;
  }

  // ==========================================
  // Validation / Saving
  // ==========================================

  String? validateForm() {
    final profile = _buildProfileFromControllers();
    final errors = [
      ...profile.validateForEmergencySave(),
      ...MedicalProfileModel.validateRawOptionalInputs(
        age: dateOfBirth == null ? ageController.text : null,
        weight: weightController.text,
        height: heightController.text,
        address: addressController.text,
        notes: notesController.text,
      ),
    ];

    if (errors.isNotEmpty) {
      return errors.first;
    }

    return null;
  }

  Future<bool> saveData() async {
    final validationError = validateForm();

    if (validationError != null) {
      errorMessage = validationError;
      successMessage = '';
      _safeNotify();
      return false;
    }

    final user = _authService.currentUser;

    if (user == null) {
      errorMessage = 'medical.errors.user_not_signed_in'.tr();
      successMessage = '';
      _safeNotify();
      return false;
    }

    isSaving = true;
    errorMessage = '';
    successMessage = '';
    _safeNotify();

    try {
      _normalizeControllersForSave();

      final profile = _buildProfileFromControllers(userId: user.uid);

      final normalizedProfile = profile.copyWith(
        fullName: profile.normalizedFullName,
        nationalId: profile.normalizedNationalId,
        address: profile.normalizedAddress,
        dateOfBirth: profile.validDateOfBirth,
        age: profile.effectiveAge,
        bloodType: profile.normalizedBloodType,
        weight: profile.normalizedWeight,
        height: profile.normalizedHeight,
        allergies: profile.normalizedAllergies,
        medications: profile.normalizedMedications,
        chronicDiseases: profile.normalizedChronicDiseases,
        notes: profile.normalizedNotes,
        completionPercentage: profile.calculateCompletion(),
      );

      await _saveProfileLocally(normalizedProfile);

      final result = await _firebaseService.updateMedicalDetails(
        userId: user.uid,
        fullName: normalizedProfile.normalizedFullName ?? '',
        nationalId: normalizedProfile.normalizedNationalId ?? '',
        bloodType: normalizedProfile.normalizedBloodType ?? '',
        allergies: normalizedProfile.normalizedAllergies ?? '',
        medications: normalizedProfile.normalizedMedications ?? '',
        chronicDiseases: normalizedProfile.normalizedChronicDiseases ?? '',
        address: normalizedProfile.normalizedAddress,
        weight: normalizedProfile.normalizedWeight,
        height: normalizedProfile.normalizedHeight,
        notes: normalizedProfile.normalizedNotes,
        gender: normalizedProfile.normalizedGender,
        dateOfBirth: normalizedProfile.validDateOfBirth,
        age: normalizedProfile.effectiveAge,
        isOrganDonor: normalizedProfile.isOrganDonor,
      );

      if (!result.isSuccess) {
        errorMessage = 'medical.errors.cloud_update_failed_local_saved'.tr();
        successMessage = '';
        return false;
      }

      hasExistingSecureRecord = true;
      successMessage = 'medical.messages.save_success'.tr();
      return true;
    } catch (e, stackTrace) {
      errorMessage = 'medical.errors.save_exception'.tr();
      successMessage = '';
      debugPrint('❌ MedicalRecordViewModel saveData error: $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    } finally {
      isSaving = false;
      _safeNotify();
    }
  }

  Future<void> _saveProfileLocally(MedicalProfileModel profile) async {
    final user = _authService.currentUser;

    // 🔒 SECURITY FIX: Only save if user is authenticated
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();

    // 🔒 SECURITY FIX: Use uid-prefixed keys for complete data isolation
    final uidPrefix = 'med_${user.uid}_';
    final localMap = profile.toSharedPreferencesMap();

    for (final entry in localMap.entries) {
      if (entry.key == 'med_donor') continue;

      // Extract the field name after 'med_' prefix
      final fieldName = entry.key.replaceFirst('med_', '');
      await prefs.setString('$uidPrefix$fieldName', entry.value);
    }

    await prefs.setBool('${uidPrefix}donor', profile.isOrganDonor);
  }

  void _normalizeControllersForSave() {
    nameController.text =
        MedicalProfileModel.normalizeFullName(nameController.text) ?? '';

    nationalIdController.text =
        MedicalProfileModel.normalizeNationalId(nationalIdController.text) ??
        '';

    addressController.text =
        MedicalProfileModel.normalizeAddress(addressController.text) ?? '';

    weightController.text =
        MedicalProfileModel.normalizeWeight(weightController.text) ?? '';

    heightController.text =
        MedicalProfileModel.normalizeHeight(heightController.text) ?? '';

    allergiesController.text =
        MedicalProfileModel.normalizeMedicalText(allergiesController.text) ??
        '';

    medicationsController.text =
        MedicalProfileModel.normalizeMedicalText(medicationsController.text) ??
        '';

    diseasesController.text =
        MedicalProfileModel.normalizeMedicalText(diseasesController.text) ?? '';

    notesController.text =
        MedicalProfileModel.normalizeOptionalNotes(notesController.text) ?? '';

    if (dateOfBirth != null &&
        !MedicalProfileModel.isValidBirthDate(dateOfBirth)) {
      dateOfBirth = null;
    }

    if (dateOfBirth != null) {
      ageController.text = MedicalProfileModel.calculateAge(
        dateOfBirth!,
      ).toString();
    } else {
      final age = _parseAge(ageController.text);
      ageController.text = age?.toString() ?? '';
    }

    selectedBloodType = BloodTypes.isValid(selectedBloodType)
        ? selectedBloodType?.trim()
        : null;
  }

  MedicalProfileModel _buildProfileFromControllers({String? userId}) {
    final currentUserId = userId ?? _authService.currentUser?.uid ?? '';

    final explicitAge = dateOfBirth == null
        ? _parseAge(ageController.text)
        : MedicalProfileModel.calculateAge(dateOfBirth!);

    return MedicalProfileModel(
      userId: currentUserId,
      fullName: MedicalProfileModel.normalizeFullName(nameController.text),
      nationalId: MedicalProfileModel.normalizeNationalId(
        nationalIdController.text,
      ),
      address: MedicalProfileModel.normalizeAddress(addressController.text),
      dateOfBirth: dateOfBirth,
      age: explicitAge,
      bloodType: selectedBloodType?.trim(),
      weight: MedicalProfileModel.normalizeWeight(weightController.text),
      height: MedicalProfileModel.normalizeHeight(heightController.text),
      allergies: MedicalProfileModel.normalizeMedicalText(
        allergiesController.text,
      ),
      medications: MedicalProfileModel.normalizeMedicalText(
        medicationsController.text,
      ),
      chronicDiseases: MedicalProfileModel.normalizeMedicalText(
        diseasesController.text,
      ),
      notes: MedicalProfileModel.normalizeOptionalNotes(notesController.text),
      gender: selectedGender?.trim(),
      isOrganDonor: isOrganDonor,
    );
  }

  // ==========================================
  // Mutations from UI
  // ==========================================

  void setBloodType(String? type) {
    selectedBloodType = BloodTypes.isValid(type) ? type?.trim() : null;
    _safeNotify();
  }

  void setDateOfBirth(DateTime? value) {
    if (value == null) {
      clearDateOfBirth();
      return;
    }

    final normalized = DateTime(value.year, value.month, value.day);

    if (!MedicalProfileModel.isValidBirthDate(normalized)) {
      dateOfBirth = null;
      ageController.clear();
      errorMessage = 'medical.validation.birth_date_invalid'.tr();
      _safeNotify();
      return;
    }

    dateOfBirth = normalized;
    ageController.text = MedicalProfileModel.calculateAge(
      normalized,
    ).toString();
    errorMessage = '';
    _safeNotify();
  }

  void clearDateOfBirth() {
    dateOfBirth = null;
    ageController.clear();
    _safeNotify();
  }

  void setGender(String? value) {
    selectedGender = Genders.isValid(value) ? value?.trim() : null;
    _safeNotify();
  }

  void toggleDonor(bool value) {
    isOrganDonor = value;
    _safeNotify();
  }

  void clearMessages() {
    errorMessage = '';
    successMessage = '';
    _safeNotify();
  }

  // ==========================================
  // Internal parsing helpers
  // ==========================================

  int? _parseAge(String value) {
    final digits = _normalizeArabicDigits(value).replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    final parsed = int.tryParse(digits);
    if (!MedicalProfileModel.isValidAge(parsed)) return null;

    return parsed;
  }

  String _normalizeArabicDigits(String value) {
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

  @override
  void dispose() {
    _isDisposed = true;

    nameController.dispose();
    nationalIdController.dispose();
    addressController.dispose();
    ageController.dispose();
    weightController.dispose();
    heightController.dispose();
    allergiesController.dispose();
    medicationsController.dispose();
    diseasesController.dispose();
    notesController.dispose();

    super.dispose();
  }
}

enum MedicalRecordField {
  fullName,
  nationalId,
  address,
  dateOfBirth,
  age,
  weight,
  height,
  bloodType,
  gender,
  allergies,
  medications,
  chronicDiseases,
  notes,
}

enum MedicalFieldState { empty, valid, invalid }
