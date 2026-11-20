import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';
import '../../../core/services/dashboard_sync_service.dart';

class LoginViewModel extends ChangeNotifier {
  // 🛡️ 1. استدعاء خدمة السيرفر (البوابة)
  final FirebaseAuthService _authService = FirebaseAuthService();
  final DashboardSyncService _dashboardSyncService = DashboardSyncService();

  // 📝 2. متحكمات الحقول
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  // ⚙️ 3. متغيرات الحالة
  bool isObscure = true;
  bool isLoading = false;
  String errorMessage = '';

  // 👁️ دالة تغيير حالة الباسورد (إظهار/إخفاء)
  void togglePasswordVisibility() {
    isObscure = !isObscure;
    notifyListeners();
  }

  // 🛡️ 4. دالة التحقق الأمني (Validation)
  String? validateInputs() {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      return "يرجى تعبئة البريد الإلكتروني وكلمة المرور";
    }

    // 📧 التحقق من صحة صيغة الإيميل
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      return "صيغة البريد الإلكتروني غير صحيحة";
    }

    // 🔒 الفايربيس يرفض أي كلمة مرور أقل من 6 أحرف
    if (password.length < 6) {
      return "كلمة المرور يجب أن تكون 6 أحرف على الأقل";
    }

    return null; // كل إشي تمام التمام
  }

  // 🚀 5. دالة تسجيل الدخول بالإيميل (مربوطة بالمنطق صح)
  Future<bool> login() async {
    // 🛑 الخطوة الذهبية: لا تكلم السيرفر إذا الحقول فيها مشكلة!
    final validationError = validateInputs();
    if (validationError != null) {
      errorMessage = validationError;
      notifyListeners();
      return false; // نوقف العملية فوراً
    }

    // إذا كل شي صح، شغل مؤشر التحميل
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    try {
      final user = await _authService.signInWithEmail(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Initialize dashboard sync after successful login
      if (user != null) {
        await _initializeDashboardSync(user.uid);
      }

      isLoading = false;
      notifyListeners();
      return user != null; // ✅ الدخول ناجح
    } catch (e) {
      errorMessage = _translateFirebaseError(e.toString());
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 🌐 6. دالة الدخول السريع بواسطة جوجل
  Future<bool> loginWithGoogle() async {
    isLoading = true;
    errorMessage = '';
    notifyListeners();

    try {
      final user = await _authService.signInWithGoogle();

      // Initialize dashboard sync after successful Google login
      if (user != null) {
        await _initializeDashboardSync(user.uid);
      }

      isLoading = false;
      notifyListeners();
      return user != null;
    } catch (e) {
      errorMessage = 'تعذر تسجيل الدخول بواسطة جوجل. تأكد من الإنترنت.';
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 🔑 7. دالة استعادة كلمة المرور
  Future<bool> resetPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      errorMessage = 'يرجى كتابة بريدك الإلكتروني أولاً لاستعادة كلمة المرور.';
      notifyListeners();
      return false;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      errorMessage = 'صيغة البريد الإلكتروني غير صحيحة';
      notifyListeners();
      return false;
    }

    isLoading = true;
    errorMessage = '';
    notifyListeners();

    try {
      await _authService.sendPasswordResetEmail(email);
      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'تعذر إرسال رابط الاستعادة. تأكد من بريدك والإنترنت.';
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // 📊 Dashboard sync initialization (non-blocking)
  Future<void> _initializeDashboardSync(String userId) async {
    try {
      // Set user online status
      final onlineResult = await _dashboardSyncService.setUserOnline(userId);
      if (onlineResult.isFailure) {
        debugPrint(
          '⚠️ LoginViewModel: Failed to set user online - ${onlineResult.error}',
        );
      }

      // Initialize FCM token
      final tokenResult = await _dashboardSyncService.initializeFCMToken(
        userId,
      );
      if (tokenResult.isFailure) {
        debugPrint(
          '⚠️ LoginViewModel: Failed to initialize FCM token - ${tokenResult.error}',
        );
      }
    } catch (e) {
      // Dashboard sync failure should not break login flow
      debugPrint('⚠️ LoginViewModel: Dashboard sync error - $e');
    }
  }

  // 🌍 7. مترجم الأخطاء الذكي
  String _translateFirebaseError(String error) {
    if (error.contains('user-not-found') ||
        error.contains('wrong-password') ||
        error.contains('invalid-credential')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
    }
    if (error.contains('network-request-failed')) {
      return 'لا يوجد اتصال بالإنترنت.';
    }
    if (error.contains('too-many-requests')) {
      return 'تم حظر الدخول مؤقتاً لكثرة المحاولات الخاطئة.';
    }
    return 'حدث خطأ في الاتصال، حاول مجدداً.';
  }

  // 🗑️ 8. تنظيف الذاكرة (مهم جداً لمنع تسريب الرامات)
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
