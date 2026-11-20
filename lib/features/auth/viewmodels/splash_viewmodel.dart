import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_auth_service.dart';

/// ==========================================
/// 🧠 ViewModel: Splash Logic (شرطي المرور المطور)
/// ==========================================
class SplashViewModel extends ChangeNotifier {
  // 🧭 وجهات المستخدم:
  // 1: الرئيسية (Home)، 2: تسجيل الدخول (Login)، 3: التعريف (Onboarding)
  int _nextRoute = 0;
  int get nextRoute => _nextRoute;

  // 🚀 دالة التهيئة المدمجة (وقتك القديم + المنطق الجديد)
  Future<void> startInitialization() async {
    // ⏳ 1. الانتظار المخصص (3.8 ثواني) - زي ما كنت عامل بالضبط
    await Future.delayed(const Duration(milliseconds: 3800));

    try {
      // 💾 2. فحص ذاكرة التلفون (هل أكمل الـ Onboarding؟)
      final prefs = await SharedPreferences.getInstance();
      bool onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

      if (!onboardingCompleted) {
        // إذا لم يكمل الـ Onboarding -> للتعريف
        _nextRoute = 3;
      } else {
        // ☁️ 3. فحص الفايربيس (هل اليوزر مسجل دخول؟)
        User? currentUser = FirebaseAuth.instance.currentUser;

        if (currentUser != null) {
          final authService = FirebaseAuthService();
          
          if (currentUser.email != null && !currentUser.emailVerified) {
            if (!authService.isPhoneLinked) {
              // 🔒 المستخدم بدأ التسجيل ولم يكمل ربط الهاتف (خرج من التطبيق)
              // نسجل خروجه ونوجهه لتسجيل الدخول مرة أخرى لحماية العملية
              await authService.signOut();
              _nextRoute = 2; // مش مسجل -> للدخول
            } else {
              _nextRoute = 4; // مسجل لكن لم يتم التحقق من البريد
            }
          } else {
            _nextRoute = 1; // مسجل -> للرئيسية
          }
        } else {
          _nextRoute = 2; // مش مسجل -> للدخول
        }
      }
    } catch (e) {
      debugPrint('❌ System Alert (Splash): $e');
      _nextRoute = 2; // في حال الخطأ نوديه للدخول كأمان
    }

    notifyListeners();
  }
}
