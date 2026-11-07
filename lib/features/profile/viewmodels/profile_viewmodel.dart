import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/services/firebase_service.dart';
import '../../auth/services/firebase_auth_service.dart';

/// ==========================================
/// 👤 Profile ViewModel - Guardian 360
/// ==========================================
/// مسؤول عن بيانات الملف الشخصي العامة فقط:
/// - الاسم الكامل
/// - رقم الهاتف
/// - البريد الإلكتروني للعرض فقط
/// - حالة اكتمال السجل الطبي
///
/// غير مسؤول عن:
/// - تعديل السجل الطبي.
/// - تعديل جهات الطوارئ.
/// - تسجيل الخروج.
/// - منطق Firebase Auth العميق لتغيير البريد الإلكتروني.
class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({
    FirebaseAuthService? authService,
    FirebaseService? firebaseService,
  }) : _authService = authService ?? FirebaseAuthService(),
       _firebaseService = firebaseService ?? FirebaseService() {
    unawaited(loadProfileData());
  }

  final FirebaseAuthService _authService;
  final FirebaseService _firebaseService;

  static const Duration _loadTimeout = Duration(seconds: 10);
  static const Duration _saveTimeout = Duration(seconds: 10);

  String userName = '';
  String userPhone = '';
  String userEmail = '';

  bool isLoading = true;
  bool isSaving = false;
  bool isMedicalProfileComplete = false;
  bool hasEmergencyContacts = false;

  String errorMessage = '';
  String successMessage = '';

  final editNameCtrl = TextEditingController();
  final editPhoneCtrl = TextEditingController();

  /// البريد للعرض فقط حالياً.
  ///
  /// تغييره من Firestore فقط بدون Firebase Auth سيكون مضللاً،
  /// لذلك لا نسمح بتعديله من شاشة البروفايل الآن.
  final editEmailCtrl = TextEditingController();

  bool _isDisposed = false;

  // ==========================================
  // Getters
  // ==========================================

  bool get canEditEmail => false;

  bool get isNewUser => userName.trim().isEmpty;

  bool get hasPhone => userPhone.trim().isNotEmpty;

  bool get hasEmail => userEmail.trim().isNotEmpty;

  String get displayName {
    final name = userName.trim();
    return name;
  }

  String get displayPhone {
    final phone = userPhone.trim();
    return phone;
  }

  String get displayEmail {
    final email = userEmail.trim();
    return email;
  }

  String get initials {
    final name = displayName.trim();
    if (name.isEmpty) return 'G';

    final parts = name
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'G';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();

    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  String get accountStatusText {
    if (isMedicalProfileComplete && hasEmergencyContacts) {
      return 'profile.status.account_ready';
    }

    if (isMedicalProfileComplete) {
      return 'profile.status.medical_complete';
    }

    return 'profile.status.medical_incomplete';
  }

  Color get medicalStatusColor {
    return isMedicalProfileComplete ? Colors.green : Colors.orange;
  }

  String get medicalStatusTitle {
    return isMedicalProfileComplete
        ? 'profile.status.medical_title_complete'
        : 'profile.status.medical_title_required';
  }

  String get medicalStatusSubtitle {
    return isMedicalProfileComplete
        ? 'profile.status.medical_subtitle_complete'
        : 'profile.status.medical_subtitle_required';
  }

  Color get contactsStatusColor {
    return hasEmergencyContacts ? Colors.green : Colors.orange;
  }

  String get contactsStatusTitle {
    return hasEmergencyContacts
        ? 'profile.status.contacts_title_complete'
        : 'profile.status.contacts_title_required';
  }

  String get contactsStatusSubtitle {
    return hasEmergencyContacts
        ? 'profile.status.contacts_subtitle_complete'
        : 'profile.status.contacts_subtitle_required';
  }

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // ==========================================
  // Loading
  // ==========================================

  Future<void> loadProfileData() async {
    isLoading = true;
    errorMessage = '';
    successMessage = '';
    _safeNotify();

    try {
      final prefs = await SharedPreferences.getInstance();

      final localName = prefs.getString('user_name') ?? '';
      final localPhone = prefs.getString('user_phone') ?? '';
      final localEmail = prefs.getString('user_email') ?? '';

      final currentUser = _authService.currentUser;

      final authDisplayName = currentUser?.displayName?.trim() ?? '';
      final authEmail = currentUser?.email?.trim() ?? '';
      final authPhone = currentUser?.phoneNumber?.trim() ?? '';

      String resolvedName = _firstNonEmpty([localName, authDisplayName]);

      String resolvedPhone = _firstNonEmpty([localPhone, authPhone]);

      String resolvedEmail = _firstNonEmpty([localEmail, authEmail]);

      if (currentUser != null) {
        final userResult = await _firebaseService
            .getUser(currentUser.uid)
            .timeout(_loadTimeout);

        if (userResult.isSuccess && userResult.data != null) {
          final data = userResult.data!;

          resolvedName = _firstNonEmpty([
            data['fullName']?.toString(),
            data['name']?.toString(),
            data['userName']?.toString(),
            resolvedName,
          ]);

          resolvedPhone = _firstNonEmpty([
            data['phone']?.toString(),
            data['userPhone']?.toString(),
            resolvedPhone,
          ]);

          resolvedEmail = _firstNonEmpty([
            data['email']?.toString(),
            data['userEmail']?.toString(),
            resolvedEmail,
          ]);

          isMedicalProfileComplete = _toBool(
            data['isMedicalProfileComplete'],
            fallback: false,
          );

          hasEmergencyContacts = _hasAnyEmergencyContact(data);
        } else {
          isMedicalProfileComplete = false;
          hasEmergencyContacts = false;
        }
      } else {
        isMedicalProfileComplete = false;
        hasEmergencyContacts = false;
      }

      userName = _sanitizeName(resolvedName);
      userPhone = _normalizePhoneForDisplay(resolvedPhone);
      userEmail = resolvedEmail.trim().toLowerCase();

      editNameCtrl.text = userName;
      editPhoneCtrl.text = userPhone;
      editEmailCtrl.text = userEmail;

      await _cacheProfileLocally(
        name: userName,
        phone: userPhone,
        email: userEmail,
      );
    } on TimeoutException {
      errorMessage = 'profile.errors.load_timeout';
      debugPrint('⏱️ ProfileViewModel loadProfileData timeout');

      await _loadLocalFallback();
    } catch (e, stackTrace) {
      errorMessage = 'profile.errors.load_failed';
      debugPrint('❌ ProfileViewModel loadProfileData error: $e');
      debugPrintStack(stackTrace: stackTrace);

      await _loadLocalFallback();
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  Future<void> refreshProfileData() async {
    await loadProfileData();
  }

  Future<void> _loadLocalFallback() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      userName = prefs.getString('user_name') ?? userName;
      userPhone = prefs.getString('user_phone') ?? userPhone;
      userEmail = prefs.getString('user_email') ?? userEmail;

      editNameCtrl.text = userName;
      editPhoneCtrl.text = userPhone;
      editEmailCtrl.text = userEmail;
    } catch (e) {
      debugPrint('⚠️ ProfileViewModel local fallback failed: $e');
    }
  }

  // ==========================================
  // Validation
  // ==========================================

  String? validateInputs() {
    final safeName = _sanitizeName(editNameCtrl.text);
    final safePhone = editPhoneCtrl.text.trim();

    if (safeName.length < 3) {
      return 'profile.validation.name_too_short';
    }

    if (_containsDigits(safeName)) {
      return 'profile.validation.name_has_digits';
    }

    final normalizedPhone = normalizeJordanPhone(safePhone);

    if (normalizedPhone == null) {
      return 'profile.validation.invalid_phone_example';
    }

    final email = editEmailCtrl.text.trim();
    if (email.isNotEmpty && !_isValidEmail(email)) {
      return 'profile.validation.invalid_email';
    }

    return null;
  }

  /// يحوّل أرقام الأردن إلى صيغة موحدة E.164:
  /// +9627XXXXXXXX
  ///
  /// يقبل:
  /// 0791234567
  /// +962791234567
  /// 00962791234567
  /// 962791234567
  String? normalizeJordanPhone(String input) {
    var phone = input.trim();

    if (phone.isEmpty) return null;

    phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (phone.startsWith('00')) {
      phone = '+${phone.substring(2)}';
    }

    if (phone.startsWith('962')) {
      phone = '+$phone';
    }

    if (RegExp(r'^07[789]\d{7}$').hasMatch(phone)) {
      return '+962${phone.substring(1)}';
    }

    if (RegExp(r'^\+9627[789]\d{7}$').hasMatch(phone)) {
      return phone;
    }

    return null;
  }

  // ==========================================
  // Saving
  // ==========================================

  Future<bool> saveProfileData() async {
    final validationError = validateInputs();

    if (validationError != null) {
      errorMessage = validationError;
      successMessage = '';
      _safeNotify();
      return false;
    }

    final currentUser = _authService.currentUser;

    if (currentUser == null) {
      errorMessage = AppStrings.errorUserNotLoggedIn;
      successMessage = '';
      _safeNotify();
      return false;
    }

    isSaving = true;
    errorMessage = '';
    successMessage = '';
    _safeNotify();

    try {
      final safeName = _sanitizeName(editNameCtrl.text);
      final normalizedPhone = normalizeJordanPhone(editPhoneCtrl.text.trim());

      if (normalizedPhone == null) {
        errorMessage = 'profile.validation.invalid_phone';
        successMessage = '';
        return false;
      }

      final resolvedEmail = _firstNonEmpty([
        currentUser.email,
        userEmail,
        editEmailCtrl.text,
      ]).trim().toLowerCase();

      await _cacheProfileLocally(
        name: safeName,
        phone: normalizedPhone,
        email: resolvedEmail,
      );

      final result = await _firebaseService
          .updateUser(currentUser.uid, {
            'fullName': safeName,
            'phone': normalizedPhone,
            'email': resolvedEmail,
          })
          .timeout(_saveTimeout);

      if (result.isFailure) {
        errorMessage = 'profile.errors.cloud_update_failed_local_saved';
        successMessage = '';
        return false;
      }

      await _updateAuthDisplayNameBestEffort(safeName);

      userName = safeName;
      userPhone = normalizedPhone;
      userEmail = resolvedEmail;

      editNameCtrl.text = userName;
      editPhoneCtrl.text = userPhone;
      editEmailCtrl.text = userEmail;

      successMessage = 'profile.messages.save_success';
      errorMessage = '';

      return true;
    } on TimeoutException {
      errorMessage = 'profile.errors.save_timeout';
      successMessage = '';
      debugPrint('⏱️ ProfileViewModel saveProfileData timeout');
      return false;
    } catch (e, stackTrace) {
      errorMessage = 'profile.errors.save_failed';
      successMessage = '';
      debugPrint('❌ ProfileViewModel saveProfileData error: $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    } finally {
      isSaving = false;
      _safeNotify();
    }
  }

  Future<void> _updateAuthDisplayNameBestEffort(String fullName) async {
    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) return;

      if ((currentUser.displayName ?? '').trim() == fullName.trim()) {
        return;
      }

      await currentUser
          .updateDisplayName(fullName)
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('⚠️ ProfileViewModel: update displayName skipped - $e');
    }
  }

  Future<void> _cacheProfileLocally({
    required String name,
    required String phone,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('user_name', name.trim());
    await prefs.setString('user_phone', phone.trim());
    await prefs.setString('user_email', email.trim().toLowerCase());
  }

  void clearMessages() {
    errorMessage = '';
    successMessage = '';
    _safeNotify();
  }

  void prepareEditControllers() {
    editNameCtrl.text = userName;
    editPhoneCtrl.text = userPhone;
    editEmailCtrl.text = userEmail;
    clearMessages();
  }

  // ==========================================
  // Helpers
  // ==========================================

  String _sanitizeName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _containsDigits(String value) {
    return RegExp(r'\d').hasMatch(value);
  }

  bool _isValidEmail(String value) {
    final email = value.trim();

    if (email.isEmpty) return true;

    final emailRegex = RegExp(
      r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$',
    );

    return emailRegex.hasMatch(email);
  }

  String _normalizePhoneForDisplay(String value) {
    final normalized = normalizeJordanPhone(value);
    return normalized ?? value.trim();
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final text = value?.trim();

      if (text != null && text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }

  bool _toBool(dynamic value, {required bool fallback}) {
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

  bool _hasAnyEmergencyContact(Map<String, dynamic> data) {
    final primary = data['primaryEmergencyContact'];

    if (primary is Map) {
      final name = primary['name']?.toString().trim() ?? '';
      final phone = primary['phone']?.toString().trim() ?? '';

      if (name.isNotEmpty || phone.isNotEmpty) return true;
    }

    final extra = data['extraEmergencyContacts'];

    if (extra is List) {
      for (final item in extra) {
        if (item is! Map) continue;

        final name = item['name']?.toString().trim() ?? '';
        final phone = item['phone']?.toString().trim() ?? '';

        if (name.isNotEmpty || phone.isNotEmpty) return true;
      }
    }

    return false;
  }

  @override
  void dispose() {
    _isDisposed = true;

    editNameCtrl.dispose();
    editPhoneCtrl.dispose();
    editEmailCtrl.dispose();

    super.dispose();
  }
}
