import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// ==========================================
/// 🔐 Biometric Service - Guardian 360
/// ==========================================
/// مسؤول فقط عن التحقق المحلي من هوية المستخدم عبر نظام الجهاز.
///
/// ملاحظات مهمة:
/// - هذه الخدمة لا تعرض UI خاص بالتطبيق.
/// - نافذة البصمة/الوجه/رمز الجهاز تظهر من نظام Android/iOS نفسه.
/// - تستخدم للسجل الطبي والملفات الحساسة فقط.
/// - لا تحفظ أي بيانات حساسة ولا تتعامل مع Firebase.
class BiometricService {
  BiometricService({LocalAuthentication? localAuthentication})
    : _auth = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// فحص مختصر هل الجهاز يدعم أي نوع تحقق محلي.
  Future<BiometricAvailabilityResult> checkAvailability() async {
    try {
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      final biometrics = await _auth.getAvailableBiometrics();

      final canAuthenticate = canCheckBiometrics || isDeviceSupported;

      if (!canAuthenticate) {
        return BiometricAvailabilityResult.unavailable(
          message:
              'هذا الجهاز لا يدعم التحقق الآمن. فعّل قفل الشاشة أو استخدم جهازاً يدعم التحقق.',
          availableBiometrics: biometrics,
        );
      }

      return BiometricAvailabilityResult.available(
        canCheckBiometrics: canCheckBiometrics,
        isDeviceSupported: isDeviceSupported,
        availableBiometrics: biometrics,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ BiometricService checkAvailability error: $e');
      debugPrintStack(stackTrace: stackTrace);

      return BiometricAvailabilityResult.unavailable(
        message: 'تعذر فحص التحقق الآمن على هذا الجهاز.',
        availableBiometrics: const [],
      );
    }
  }

  /// يفتح نافذة التحقق الأصلية من نظام الجهاز.
  ///
  /// إذا كان الجهاز يدعم بصمة/وجه سيتم عرضها.
  /// وإذا كان يدعم PIN/Pattern/Password يسمح النظام بها لأن biometricOnly=false.
  Future<BiometricAuthResult> authenticateForMedicalRecord() async {
    try {
      final availability = await checkAvailability();

      if (!availability.canAuthenticate) {
        return BiometricAuthResult.failure(
          message: availability.message,
          code: 'not_available',
        );
      }

      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'يرجى تأكيد هويتك للوصول إلى السجل الطبي الحساس',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (didAuthenticate) {
        return BiometricAuthResult.success();
      }

      return BiometricAuthResult.failure(
        message: 'لم يتم تأكيد الهوية.',
        code: 'not_authenticated',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ BiometricService authenticate error: $e');
      debugPrintStack(stackTrace: stackTrace);

      final raw = e.toString().toLowerCase();

      if (raw.contains('notavailable') || raw.contains('not_available')) {
        return BiometricAuthResult.failure(
          message: 'التحقق غير متاح حالياً على هذا الجهاز.',
          code: 'not_available',
        );
      }

      if (raw.contains('notenrolled') || raw.contains('not_enrolled')) {
        return BiometricAuthResult.failure(
          message:
              'لا توجد بصمة أو قفل جهاز مفعّل. فعّل بصمة الإصبع أو قفل الشاشة من إعدادات الهاتف.',
          code: 'not_enrolled',
        );
      }

      if (raw.contains('lockedout') || raw.contains('lockout')) {
        return BiometricAuthResult.failure(
          message:
              'تم إيقاف التحقق مؤقتاً بسبب محاولات متكررة. حاول لاحقاً أو استخدم رمز قفل الجهاز.',
          code: 'locked_out',
        );
      }

      if (raw.contains('passcode') || raw.contains('devicecredential')) {
        return BiometricAuthResult.failure(
          message:
              'قفل الجهاز غير مفعّل. فعّل رمز القفل أو البصمة من إعدادات الهاتف.',
          code: 'device_credential_missing',
        );
      }

      return BiometricAuthResult.failure(
        message: 'تعذر فتح نافذة التحقق. تأكد من إعدادات البصمة وقفل الجهاز.',
        code: 'auth_failed',
      );
    }
  }
}

class BiometricAvailabilityResult {
  final bool canAuthenticate;
  final bool canCheckBiometrics;
  final bool isDeviceSupported;
  final List<BiometricType> availableBiometrics;
  final String message;

  const BiometricAvailabilityResult._({
    required this.canAuthenticate,
    required this.canCheckBiometrics,
    required this.isDeviceSupported,
    required this.availableBiometrics,
    required this.message,
  });

  factory BiometricAvailabilityResult.available({
    required bool canCheckBiometrics,
    required bool isDeviceSupported,
    required List<BiometricType> availableBiometrics,
  }) {
    return BiometricAvailabilityResult._(
      canAuthenticate: true,
      canCheckBiometrics: canCheckBiometrics,
      isDeviceSupported: isDeviceSupported,
      availableBiometrics: availableBiometrics,
      message: '',
    );
  }

  factory BiometricAvailabilityResult.unavailable({
    required String message,
    required List<BiometricType> availableBiometrics,
  }) {
    return BiometricAvailabilityResult._(
      canAuthenticate: false,
      canCheckBiometrics: false,
      isDeviceSupported: false,
      availableBiometrics: availableBiometrics,
      message: message,
    );
  }

  bool get hasEnrolledBiometrics => availableBiometrics.isNotEmpty;
}

class BiometricAuthResult {
  final bool isSuccess;
  final String message;
  final String code;

  const BiometricAuthResult._({
    required this.isSuccess,
    required this.message,
    required this.code,
  });

  factory BiometricAuthResult.success() {
    return const BiometricAuthResult._(
      isSuccess: true,
      message: '',
      code: 'success',
    );
  }

  factory BiometricAuthResult.failure({
    required String message,
    required String code,
  }) {
    return BiometricAuthResult._(
      isSuccess: false,
      message: message,
      code: code,
    );
  }
}
