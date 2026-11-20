import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../viewmodels/splash_viewmodel.dart';

// استدعاء الشاشات المحتملة للتوجه إليها
import 'onboarding_screen.dart';
import 'login_screen.dart';
import 'email_verification_screen.dart';
import '../../home/views/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // 🧠 الربط الاحترافي بين الـ View والـ ViewModel
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final viewModel = context.read<SplashViewModel>();

      // ⏳ تشغيل عداد الـ 3.8 ثواني + فحص حالة المستخدم بالسيرفر
      await viewModel.startInitialization();

      if (!mounted) return;

      // 🚦 التوجيه الذكي (شرطي المرور)
      // بناءً على قيمة nextRoute اللي حددها الـ ViewModel
      Widget destination;

      if (viewModel.nextRoute == 1) {
        destination = const HomeScreen(); // مسجل دخول مسبقاً
      } else if (viewModel.nextRoute == 2) {
        destination = const LoginScreen(); // مش مسجل دخول
      } else if (viewModel.nextRoute == 4) {
        destination = const EmailVerificationScreen(); // تأكيد الإيميل
      } else {
        destination = const OnboardingScreen(); // أول مرة يفتح التطبيق
      }

      // الانتقال السلس للوجهة المحددة
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => destination),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. الأيقونة: "نبض الحياة" ❤️ (شغلك الفخم)
            ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primaryRed],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds),
                  child: const Icon(Icons.spa, size: 120, color: Colors.white),
                )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(
                  begin: 0.95,
                  end: 1.05,
                  duration: 1500.ms,
                  curve: Curves.easeInOut,
                ),

            const SizedBox(height: 20),

            // 2. النص: "لمعة الفخامة" ✨
            Text(
                  "G360",
                  style: GoogleFonts.montserrat(
                    fontSize: 52,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                    letterSpacing: 5,
                  ),
                )
                .animate()
                .fadeIn(duration: 1000.ms)
                .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuart)
                .then()
                .animate(onPlay: (c) => c.repeat(period: 2500.ms))
                .shimmer(
                  duration: 1200.ms,
                  color: AppColors.primaryRed.withOpacity(0.5),
                  angle: -30,
                ),

            const SizedBox(height: 5),

            // النص الفرعي
            Text(
              "GUARDIAN SYSTEM",
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textGrey,
                letterSpacing: 4,
              ),
            ).animate().fadeIn(delay: 800.ms, duration: 1000.ms),
          ],
        ),
      ),
    );
  }
}
