import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/dashboard_sync_service.dart';

/// ==========================================
/// 🔐 Firebase Auth Service - Guardian 360
/// ==========================================
/// مسؤول عن:
/// - تسجيل الدخول بالبريد وكلمة المرور.
/// - إنشاء حساب بالبريد.
/// - تسجيل الدخول عبر Google.
/// - تسجيل الدخول عبر الهاتف OTP.
/// - مزامنة مستند المستخدم الأساسي في Firestore.
/// - تسجيل الخروج مع تحديث حالة المستخدم للداشبورد.
///
/// غير مسؤول عن:
/// - تحديث السجل الطبي الكامل.
/// - إدارة جهات الطوارئ.
/// - إنشاء بلاغات الحوادث.
/// - منطق الشاشات.
///
/// ملاحظة مهمة:
/// إنشاء/مزامنة مستند المستخدم هنا يجب أن يبقى متوافقاً مع:
/// FirebaseService.createUser()
/// FirebaseService.reportAccident()
/// MedicalRecordViewModel لاحقاً.
class FirebaseAuthService {
  FirebaseAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
    DashboardSyncService? dashboardSyncService,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn(),
       _dashboardSyncService = dashboardSyncService ?? DashboardSyncService();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;
  final DashboardSyncService _dashboardSyncService;

  static const String _usersCollection = 'users';

  static const Duration _authTimeout = Duration(seconds: 20);
  static const Duration _firestoreTimeout = Duration(seconds: 10);
  static const Duration _dashboardSyncTimeout = Duration(seconds: 6);
  static const Duration _googleTimeout = Duration(seconds: 30);
  static const Duration _passwordResetTimeout = Duration(seconds: 12);

  String? _verificationId;

  User? get currentUser => _auth.currentUser;
  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get hasActiveOtpSession {
    final value = _verificationId?.trim();
    return value != null && value.isNotEmpty;
  }

  bool get isPhoneLinked {
    final user = currentUser;
    if (user == null) return false;

    final hasPhoneNumber =
        user.phoneNumber != null && user.phoneNumber!.trim().isNotEmpty;

    final hasPhoneProvider = user.providerData.any(
      (provider) => provider.providerId == 'phone',
    );

    return hasPhoneNumber || hasPhoneProvider;
  }

  // ==========================================
  // Email Verification
  // ==========================================
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification().timeout(_authTimeout);
    }
  }

  Future<void> reloadCurrentUser() async {
    await _auth.currentUser?.reload().timeout(_authTimeout);
  }

  // ==========================================
  // 1. Email Sign In
  // ==========================================

  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final normalizedEmail = _normalizeEmail(email);

      if (normalizedEmail.isEmpty) {
        throw ArgumentError('email-required');
      }

      if (password.isEmpty) {
        throw ArgumentError('password-required');
      }

      final userCredential = await _auth
          .signInWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          )
          .timeout(_authTimeout);

      final user = userCredential.user;

      if (user != null) {
        await _ensureBasicUserDocument(user);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '❌ FirebaseAuthService.signInWithEmail: ${e.code} - ${e.message}',
      );
      rethrow;
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseAuthService.signInWithEmail timeout');
      Error.throwWithStackTrace(Exception('email-sign-in-timeout'), stackTrace);
    } catch (e) {
      debugPrint('❌ FirebaseAuthService.signInWithEmail unexpected error: $e');
      rethrow;
    }
  }

  // ==========================================
  // 2. Email Sign Up
  // ==========================================

  Future<User?> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    UserCredential? userCredential;

    try {
      final normalizedEmail = _normalizeEmail(email);
      final normalizedFullName = _sanitizeFullName(fullName);

      if (normalizedEmail.isEmpty) {
        throw ArgumentError('email-required');
      }

      if (password.isEmpty) {
        throw ArgumentError('password-required');
      }

      userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          )
          .timeout(_authTimeout);

      final user = userCredential.user;
      if (user == null) return null;

      await user.updateDisplayName(normalizedFullName).timeout(_authTimeout);
      await user.reload().timeout(_authTimeout);

      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) return null;

      await _ensureBasicUserDocument(
        refreshedUser,
        overrideFullName: normalizedFullName,
      );

      return refreshedUser;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '❌ FirebaseAuthService.signUpWithEmail: ${e.code} - ${e.message}',
      );
      rethrow;
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseAuthService.signUpWithEmail timeout');

      await _rollbackCreatedAuthUserBestEffort(userCredential?.user);

      Error.throwWithStackTrace(Exception('email-sign-up-timeout'), stackTrace);
    } catch (e) {
      debugPrint('❌ FirebaseAuthService.signUpWithEmail unexpected error: $e');

      await _rollbackCreatedAuthUserBestEffort(userCredential?.user);

      rethrow;
    }
  }

  // ==========================================
  // 3. Google Sign-In
  // ==========================================

  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn().timeout(_googleTimeout);

      if (googleUser == null) {
        debugPrint('⚠️ FirebaseAuthService.signInWithGoogle: user cancelled');
        return null;
      }

      final googleAuth = await googleUser.authentication.timeout(
        _googleTimeout,
      );

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth
          .signInWithCredential(credential)
          .timeout(_authTimeout);

      final user = userCredential.user;
      if (user == null) return null;

      await _ensureBasicUserDocument(user);

      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '❌ FirebaseAuthService.signInWithGoogle Firebase error: ${e.code} - ${e.message}',
      );
      rethrow;
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseAuthService.signInWithGoogle timeout');
      Error.throwWithStackTrace(
        Exception('google-sign-in-timeout'),
        stackTrace,
      );
    } catch (e) {
      debugPrint('❌ FirebaseAuthService.signInWithGoogle unexpected error: $e');
      throw Exception('google-sign-in-failed');
    }
  }

  // ==========================================
  // 4. Send OTP
  // ==========================================

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required VoidCallback onCodeSent,
    required Function(String) onError,
    VoidCallback? onAutoVerified,
  }) async {
    try {
      final normalizedPhone = phoneNumber.trim();

      if (normalizedPhone.isEmpty) {
        onError('phone-required');
        return;
      }

      await _auth.verifyPhoneNumber(
        phoneNumber: normalizedPhone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            debugPrint('🔐 FirebaseAuthService: Auto-verification triggered');

            final userCredential = await (_auth.currentUser != null
                    ? _auth.currentUser!.linkWithCredential(credential)
                    : _auth.signInWithCredential(credential))
                .timeout(_authTimeout);

            final user = userCredential.user;

            if (user != null) {
              await _ensureBasicUserDocument(user);
              debugPrint('✅ FirebaseAuthService: Auto-verification successful');

              // 🔒 CRITICAL FIX: Notify UI to navigate immediately
              onAutoVerified?.call();
            }
          } catch (e, stackTrace) {
            debugPrint(
              '❌ FirebaseAuthService.verifyPhoneNumber auto-verification error: $e',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint(
            '❌ FirebaseAuthService.verifyPhoneNumber failed: ${e.code} - ${e.message}',
          );
          onError(e.message ?? 'phone-verification-failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          onCodeSent();
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '❌ FirebaseAuthService.verifyPhoneNumber Firebase error: ${e.code} - ${e.message}',
      );
      onError(e.message ?? 'phone-verification-failed');
    } catch (e, stackTrace) {
      debugPrint(
        '❌ FirebaseAuthService.verifyPhoneNumber unexpected error: $e',
      );
      debugPrintStack(stackTrace: stackTrace);
      onError('phone-verification-failed');
    }
  }

  // ==========================================
  // 5. Verify OTP and Sign In
  // ==========================================

  Future<User?> verifyOTPAndSignIn(String otpCode) async {
    if (!hasActiveOtpSession) {
      throw Exception('otp-session-expired');
    }

    try {
      final safeOtp = otpCode.trim();

      if (safeOtp.isEmpty) {
        throw Exception('invalid-otp');
      }

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: safeOtp,
      );

      final userCredential = await (_auth.currentUser != null
              ? _auth.currentUser!.linkWithCredential(credential)
              : _auth.signInWithCredential(credential))
          .timeout(_authTimeout);

      final user = userCredential.user;

      if (user != null) {
        await _ensureBasicUserDocument(user);
      }

      _verificationId = null;
      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '❌ FirebaseAuthService.verifyOTPAndSignIn: ${e.code} - ${e.message}',
      );
      throw Exception('invalid-otp');
    } on TimeoutException {
      debugPrint('⏱️ FirebaseAuthService.verifyOTPAndSignIn timeout');
      throw Exception('otp-verification-timeout');
    } catch (e) {
      debugPrint(
        '❌ FirebaseAuthService.verifyOTPAndSignIn unexpected error: $e',
      );
      throw Exception('invalid-otp');
    }
  }

  // ==========================================
  // 6. Reset Password
  // ==========================================

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final normalizedEmail = _normalizeEmail(email);

      if (normalizedEmail.isEmpty) {
        throw ArgumentError('email-required');
      }

      await _auth
          .sendPasswordResetEmail(email: normalizedEmail)
          .timeout(_passwordResetTimeout);
    } on FirebaseAuthException catch (e) {
      debugPrint(
        '❌ FirebaseAuthService.sendPasswordResetEmail: ${e.code} - ${e.message}',
      );
      rethrow;
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseAuthService.sendPasswordResetEmail timeout');
      Error.throwWithStackTrace(
        Exception('password-reset-timeout'),
        stackTrace,
      );
    } catch (e) {
      debugPrint(
        '❌ FirebaseAuthService.sendPasswordResetEmail unexpected error: $e',
      );
      rethrow;
    }
  }

  // ==========================================
  // 7. Ensure Basic Firestore User Doc
  // ==========================================

  Future<void> _ensureBasicUserDocument(
    User user, {
    String? overrideFullName,
  }) async {
    try {
      final userDoc = _firestore.collection(_usersCollection).doc(user.uid);

      final snapshot = await userDoc.get().timeout(_firestoreTimeout);
      final existingData = snapshot.data() ?? <String, dynamic>{};

      final resolvedFullName = _resolveUserFullName(
        overrideFullName: overrideFullName,
        authDisplayName: user.displayName,
        existingData: existingData,
      );

      final resolvedEmail = _firstNotEmpty([
        user.email,
        existingData['email']?.toString(),
      ]);

      final resolvedPhone = _firstNotEmpty([
        user.phoneNumber,
        existingData['phone']?.toString(),
      ]);

      final baseData = _removeNullValues({
        'uid': user.uid,
        'email': resolvedEmail,
        'phone': resolvedPhone,
        'fullName': resolvedFullName,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!snapshot.exists) {
        await userDoc
            .set({
              ...baseData,
              ..._newUserDefaults(),
              'createdAt': FieldValue.serverTimestamp(),
            })
            .timeout(_firestoreTimeout);

        debugPrint(
          '✅ FirebaseAuthService: created basic Firestore user doc for ${user.uid}',
        );
        return;
      }

      final backfillData = _buildMissingUserDefaults(existingData);

      await userDoc
          .set({
            ...baseData,
            ...backfillData,
            if (!existingData.containsKey('createdAt'))
              'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(_firestoreTimeout);

      debugPrint(
        '✅ FirebaseAuthService: synced existing Firestore user doc for ${user.uid}',
      );
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseAuthService._ensureBasicUserDocument timeout');
      Error.throwWithStackTrace(Exception('user-doc-sync-timeout'), stackTrace);
    } catch (e) {
      debugPrint('❌ FirebaseAuthService._ensureBasicUserDocument error: $e');
      rethrow;
    }
  }

  Map<String, dynamic> _newUserDefaults() {
    return {
      'isActive': true,
      'isProfileComplete': false,
      'isMedicalProfileComplete': false,
      'hasEmergencyContacts': false,

      // Medical defaults aligned with FirebaseService.createUser()
      'bloodType': '',
      'chronicDiseases': '',
      'allergies': '',
      'medications': '',
      'notes': '',
      'nationalId': '',
      'address': '',
      'weight': '',
      'height': '',
      'age': null,
      'dateOfBirth': null,
      'isOrganDonor': false,

      // Emergency contacts defaults.
      'primaryEmergencyContact': <String, dynamic>{},
      'extraEmergencyContacts': <Map<String, dynamic>>[],
    };
  }

  Map<String, dynamic> _buildMissingUserDefaults(Map<String, dynamic> data) {
    final defaults = _newUserDefaults();
    final missing = <String, dynamic>{};

    defaults.forEach((key, value) {
      if (!data.containsKey(key)) {
        missing[key] = value;
      }
    });

    return missing;
  }

  // ==========================================
  // 8. Delete Current User
  // ==========================================

  Future<void> deleteCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final uid = user.uid;

    try {
      await _dashboardSyncService
          .setUserOffline(uid)
          .timeout(_dashboardSyncTimeout);
    } catch (e) {
      debugPrint(
        '⚠️ FirebaseAuthService.deleteCurrentUser: dashboard offline sync failed - $e',
      );
    }

    try {
      await _firestore
          .collection(_usersCollection)
          .doc(uid)
          .delete()
          .timeout(_firestoreTimeout);
    } catch (e) {
      debugPrint(
        '⚠️ FirebaseAuthService.deleteCurrentUser: failed to delete Firestore doc - $e',
      );
    }

    await user.delete().timeout(_authTimeout);

    try {
      await _googleSignIn.signOut().timeout(_googleTimeout);
    } catch (e) {
      debugPrint(
        '⚠️ FirebaseAuthService.deleteCurrentUser: Google sign out warning - $e',
      );
    }

    _verificationId = null;
  }

  // ==========================================
  // 9. Sign Out
  // ==========================================

  Future<void> signOut() async {
    final user = _auth.currentUser;

    if (user != null) {
      try {
        final offlineResult = await _dashboardSyncService
            .setUserOffline(user.uid)
            .timeout(_dashboardSyncTimeout);

        if (offlineResult.isFailure) {
          debugPrint(
            '⚠️ FirebaseAuthService.signOut: Failed to set user offline - ${offlineResult.error}',
          );
        }
      } on TimeoutException {
        debugPrint('⏱️ FirebaseAuthService.signOut: Dashboard sync timeout');
      } catch (e) {
        debugPrint('⚠️ FirebaseAuthService.signOut: Dashboard sync error - $e');
      }

      // 🔒 SECURITY FIX: Clear ALL sensitive user caches on sign-out to prevent
      // cross-user data leaks on shared devices (contacts, profile, medical).
      try {
        await _clearAllMedicalCache(user.uid);
        await _clearAllGlobalUserCache();
        debugPrint(
          '✅ FirebaseAuthService.signOut: User caches cleared for uid: ${user.uid}',
        );
      } catch (e) {
        debugPrint(
          '⚠️ FirebaseAuthService.signOut: Failed to clear user caches - $e',
        );
      }
    }

    try {
      await _googleSignIn.signOut().timeout(_googleTimeout);
    } catch (e) {
      debugPrint('⚠️ FirebaseAuthService.signOut Google sign out warning: $e');
    }

    await _auth.signOut().timeout(_authTimeout);
    _verificationId = null;
  }

  /// 🔒 SECURITY: Clears all medical data from SharedPreferences for the given uid
  Future<void> _clearAllMedicalCache(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final uidPrefix = 'med_${uid}_';

    // Get all keys and remove only those belonging to this user
    final allKeys = prefs.getKeys();
    final keysToRemove = allKeys
        .where((key) => key.startsWith(uidPrefix))
        .toList();

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }

    debugPrint(
      '🔒 Cleared ${keysToRemove.length} medical cache keys for uid: $uid',
    );
  }

  /// 🔒 SECURITY: Clears all global (non-uid-scoped) user data caches on sign-out.
  ///
  /// Prevents User B from seeing User A's emergency contacts, profile fields,
  /// or bare medical data after logout on a shared device.
  ///
  /// Keys intentionally NOT cleared here:
  /// - setting_*          : device-level preferences, not PII.
  /// - device_connected   : device pairing state, not user PII.
  /// - connected_device_name : device pairing state, not user PII.
  /// - offline_pending_reports : reports contain original uid inside their
  ///   payload and must go through a separate sync lifecycle review before
  ///   any queue clearing is considered.
  Future<void> _clearAllGlobalUserCache() async {
    final prefs = await SharedPreferences.getInstance();

    // --- Emergency contacts ---
    await prefs.remove('emergency_contacts');
    await prefs.remove('emergency_contacts_pending_sync');

    // --- Profile fields ---
    await prefs.remove('user_name');
    await prefs.remove('user_phone');
    await prefs.remove('user_email');

    // --- Bare medical keys written by MedicalProfileModel.toSharedPreferencesMap() ---
    // These use a plain 'med_*' prefix (no uid segment), so _clearAllMedicalCache
    // does not reach them. Enumerate all and remove any starting with 'med_'.
    final allKeys = prefs.getKeys().toList();
    final bareMedKeys = allKeys.where((key) => key.startsWith('med_')).toList();
    for (final key in bareMedKeys) {
      await prefs.remove(key);
    }

    debugPrint(
      '🔒 FirebaseAuthService: Global user cache cleared '
      '(contacts, profile, ${bareMedKeys.length} bare med keys)',
    );
  }

  // ==========================================
  // 10. Helpers
  // ==========================================

  String _normalizeEmail(String value) {
    return value.trim().toLowerCase();
  }

  String _sanitizeFullName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'مستخدم Guardian';
    return trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }

  String _resolveUserFullName({
    required String? overrideFullName,
    required String? authDisplayName,
    required Map<String, dynamic> existingData,
  }) {
    return _firstNotEmpty([
      overrideFullName,
      authDisplayName,
      existingData['fullName']?.toString(),
      existingData['name']?.toString(),
      existingData['userName']?.toString(),
      'مستخدم Guardian',
    ]);
  }

  String _firstNotEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();

      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }

    return '';
  }

  Map<String, dynamic> _removeNullValues(Map<String, dynamic> map) {
    final result = Map<String, dynamic>.from(map);
    result.removeWhere((_, value) => value == null);
    return result;
  }

  Future<void> _rollbackCreatedAuthUserBestEffort(User? user) async {
    if (user == null) return;

    try {
      await user.delete().timeout(_authTimeout);
      debugPrint(
        '↩️ FirebaseAuthService: rolled back auth user after sign-up failure',
      );
    } catch (e) {
      debugPrint(
        '⚠️ FirebaseAuthService: rollback auth user failed after sign-up error - $e',
      );
    }
  }
}
