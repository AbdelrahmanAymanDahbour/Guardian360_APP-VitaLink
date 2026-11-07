import 'dart:async';
import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';

class EmailVerificationViewModel extends ChangeNotifier {
  bool isLoading = false;
  bool isResending = false;
  String? message;
  String? errorMessage;
  
  // Timer for resend cooldown
  int resendCooldown = 0;
  Timer? _timer;

  // Track if we sent once
  bool _hasSentOnce = false;

  void startCooldown(int seconds) {
    resendCooldown = seconds;
    notifyListeners();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendCooldown > 0) {
        resendCooldown--;
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> sendVerificationEmail(FirebaseAuthService authService, {bool isAuto = false}) async {
    if (isAuto && _hasSentOnce) return;
    if (resendCooldown > 0) {
      errorMessage = "email_verification.resend_wait";
      notifyListeners();
      return;
    }

    if (isAuto) {
      isLoading = true;
    } else {
      isResending = true;
    }
    
    errorMessage = null;
    message = null;
    notifyListeners();

    try {
      await authService.sendEmailVerification();
      message = "email_verification.sent_success";
      _hasSentOnce = true;
      startCooldown(30);
    } catch (e) {
      errorMessage = "email_verification.error";
    } finally {
      isLoading = false;
      isResending = false;
      notifyListeners();
    }
  }

  Future<bool> checkVerification(FirebaseAuthService authService) async {
    isLoading = true;
    errorMessage = null;
    message = null;
    notifyListeners();

    try {
      await authService.reloadCurrentUser();
      bool verified = authService.isEmailVerified;
      if (!verified) {
        errorMessage = "email_verification.not_verified_yet";
      }
      return verified;
    } catch (e) {
      errorMessage = "email_verification.error";
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
