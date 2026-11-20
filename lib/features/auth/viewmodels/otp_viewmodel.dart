import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';

/// ==========================================
/// 🧠 ViewModel: OTP Verification Logic
/// ==========================================
/// Refactored to handle auto-verification navigation and prevent UI freeze
class OTPViewModel extends ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();

  // 📞 Core variables
  final String phoneNumber;
  final VoidCallback? onAutoVerificationSuccess;

  // ⏱️ Timer and state variables
  int resendCountdown = 60;
  Timer? _timer;
  bool isVerifying = false;
  bool canResend = false;
  String currentCode = "";
  String errorMessage = "";
  bool _isAutoVerified = false;

  // 🏗️ Constructor
  OTPViewModel({required this.phoneNumber, this.onAutoVerificationSuccess}) {
    _initiateVerification();
  }

  // ==========================================
  // 📩 1. Send OTP / Resend Logic
  // ==========================================
  void _initiateVerification() {
    isVerifying = true;
    errorMessage = "";
    _isAutoVerified = false;
    notifyListeners();

    // Format Jordanian phone number (e.g., 079 to +96279)
    String formattedPhone = phoneNumber.startsWith('+')
        ? phoneNumber
        : '+962${phoneNumber.substring(1)}';

    _authService.verifyPhoneNumber(
      phoneNumber: formattedPhone,
      onCodeSent: () {
        isVerifying = false;
        startResendTimer();
      },
      onError: (String error) {
        isVerifying = false;
        errorMessage = _translatePhoneError(error);
        notifyListeners();
      },
      onAutoVerified: () {
        // 🔒 CRITICAL FIX: Auto-verification successful
        debugPrint('🎉 OTPViewModel: Auto-verification detected');
        _isAutoVerified = true;
        isVerifying = false;
        errorMessage = "";
        notifyListeners();

        // Notify UI to navigate immediately
        onAutoVerificationSuccess?.call();
      },
    );
  }

  void resendOTP() {
    if (canResend) {
      _initiateVerification();
    }
  }

  // ==========================================
  // ⏱️ 2. Resend Timer Management
  // ==========================================
  void startResendTimer() {
    resendCountdown = 60;
    canResend = false;
    errorMessage = "";
    notifyListeners();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendCountdown > 0) {
        resendCountdown--;
        notifyListeners();
      } else {
        canResend = true;
        timer.cancel();
        notifyListeners();
      }
    });
  }

  // ==========================================
  // 🛡️ 3. Manual Code Verification
  // ==========================================
  Future<bool> verifyCode() async {
    if (currentCode.length < 6) return false;
    if (isVerifying) return false;

    // 🔒 CRITICAL FIX: If already auto-verified, skip manual verification
    if (_isAutoVerified) {
      debugPrint(
        '⚠️ OTPViewModel: Skipping manual verification (already auto-verified)',
      );
      return true;
    }

    isVerifying = true;
    errorMessage = "";
    notifyListeners();

    try {
      final user = await _authService.verifyOTPAndSignIn(currentCode);

      isVerifying = false;
      notifyListeners();

      return user != null;
    } on Exception catch (e) {
      // 🔒 CRITICAL FIX: Gracefully handle "code already used" error
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('invalid-verification-code') ||
          errorStr.contains('session-expired')) {
        // Code was likely consumed by auto-verification
        if (_isAutoVerified) {
          debugPrint('✅ OTPViewModel: Code already used by auto-verification');
          return true;
        }
        errorMessage = "الرمز الذي أدخلته غير صحيح أو انتهت صلاحيته.";
      } else {
        errorMessage = "حدث خطأ أثناء التحقق. يرجى المحاولة مرة أخرى.";
      }

      isVerifying = false;
      currentCode = "";
      notifyListeners();
      return false;
    }
  }

  // Update code from UI
  void updateCode(String code) {
    currentCode = code;
    errorMessage = "";
    notifyListeners();
  }

  // Format time display (00:59)
  String get formattedTime {
    int minutes = resendCountdown ~/ 60;
    int seconds = resendCountdown % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // 🌍 Error translator
  String _translatePhoneError(String error) {
    if (error.contains('too-many-requests')) {
      return 'تم حظر الرقم مؤقتاً لكثرة المحاولات، جرب بعد ساعة.';
    }
    if (error.contains('invalid-phone-number')) {
      return 'صيغة رقم الهاتف غير صحيحة.';
    }
    return error;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
