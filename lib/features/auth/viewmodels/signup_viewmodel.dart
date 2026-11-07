import 'package:flutter/material.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/dashboard_sync_service.dart';
import '../services/firebase_auth_service.dart';

class SignupViewModel extends ChangeNotifier {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirebaseService _firebaseService = FirebaseService();
  final DashboardSyncService _dashboardSyncService = DashboardSyncService();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isObscure = true;
  bool isLoading = false;

  /// نخزن مفتاح الترجمة بدل نص ثابت
  String errorKey = '';

  void togglePasswordVisibility() {
    isObscure = !isObscure;
    notifyListeners();
  }

  String? validateInputs() {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (name.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      return 'signup.errors.required_fields';
    }

    if (name.length < 3) {
      return 'signup.errors.invalid_name';
    }

    final phoneRegex = RegExp(r'^07[789]\d{7}$');
    if (!phoneRegex.hasMatch(phone)) {
      return 'signup.errors.invalid_phone';
    }

    // Strict email validation with comprehensive regex pattern
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(email)) {
      return 'errors.invalid_email';
    }

    // Strict password validation: min 8 chars, 1 letter, 1 number, 1 special char
    if (password.length < 8) {
      return 'errors.password_min_length';
    }

    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecialChar = RegExp(
      r'[@$!%*?&#^()_+=\-\[\]{}|\\:;"<>,.~/`]',
    ).hasMatch(password);

    if (!hasLetter) {
      return 'errors.password_needs_letter';
    }

    if (!hasNumber) {
      return 'errors.password_needs_number';
    }

    if (!hasSpecialChar) {
      return 'errors.password_needs_special';
    }

    if (password != confirmPassword) {
      return 'signup.errors.passwords_do_not_match';
    }

    return null;
  }

  Future<bool> createAccount() async {
    final validationError = validateInputs();
    if (validationError != null) {
      errorKey = validationError;
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorKey = '';
    notifyListeners();

    try {
      final user = await _authService.signUpWithEmail(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        fullName: nameController.text.trim(),
      );

      if (user == null) {
        errorKey = 'errors.unknown';
        return false;
      }

      final result = await _firebaseService.createUser(
        uid: user.uid,
        fullName: nameController.text.trim(),
        phone: phoneController.text.trim(),
        email: emailController.text.trim(),
      );

      if (!result.isSuccess) {
        await user.delete();
        errorKey = 'signup.errors.profile_setup_failed';
        return false;
      }

      // Initialize dashboard sync after successful signup and profile creation
      await _initializeDashboardSync(user.uid);

      return true;
    } catch (e) {
      errorKey = _translateFirebaseError(e.toString());
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // 📊 Dashboard sync initialization (non-blocking)
  Future<void> _initializeDashboardSync(String userId) async {
    try {
      // Set user online status
      final onlineResult = await _dashboardSyncService.setUserOnline(userId);
      if (onlineResult.isFailure) {
        debugPrint(
          '⚠️ SignupViewModel: Failed to set user online - ${onlineResult.error}',
        );
      }

      // Initialize FCM token
      final tokenResult = await _dashboardSyncService.initializeFCMToken(
        userId,
      );
      if (tokenResult.isFailure) {
        debugPrint(
          '⚠️ SignupViewModel: Failed to initialize FCM token - ${tokenResult.error}',
        );
      }
    } catch (e) {
      // Dashboard sync failure should not break signup flow
      debugPrint('⚠️ SignupViewModel: Dashboard sync error - $e');
    }
  }

  String _translateFirebaseError(String error) {
    if (error.contains('email-already-in-use')) {
      return 'errors.email_in_use';
    }
    if (error.contains('invalid-email')) {
      return 'errors.invalid_email';
    }
    if (error.contains('network-request-failed')) {
      return 'errors.network_error';
    }
    return 'errors.unknown';
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}
