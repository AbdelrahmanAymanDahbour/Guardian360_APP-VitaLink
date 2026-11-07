import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../viewmodels/login_viewmodel.dart';

import '../../home/views/home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginViewModel(),
      child: const _LoginContent(),
    );
  }
}

class _LoginContent extends StatelessWidget {
  const _LoginContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LoginViewModel>();

    return Scaffold(
      backgroundColor: AppColors.surfaceWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50),

              /// 🔹 الهيدر (Header)
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withAlpha(13),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: AppColors.primaryDark,
                        size: 50,
                      ),
                    ).animate().scale(
                      duration: 600.ms,
                      curve: Curves.easeOutBack,
                    ),
                    const SizedBox(height: 15),
                    Text(
                          "أهلاً بعودتك",
                          style: GoogleFonts.cairo(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textBlack,
                          ),
                        )
                        .animate()
                        .fadeIn(delay: 200.ms)
                        .slideY(begin: 0.2, end: 0),
                    Text(
                      "سجل دخولك لغرفة العمليات",
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        color: AppColors.textGrey,
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                  ],
                ),
              ),

              const SizedBox(height: 50),

              /// 🔹 البريد الإلكتروني
              Text(
                "البريد الإلكتروني",
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textBlack,
                ),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 8),
              _buildTextField(
                controller: viewModel.emailController,
                hint: "example@guardian.com",
                icon: Icons.email_outlined,
                delay: 400,
              ),

              const SizedBox(height: 20),

              /// 🔹 كلمة المرور
              Text(
                "كلمة المرور",
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textBlack,
                ),
              ).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 8),
              _buildTextField(
                controller: viewModel.passwordController,
                hint: "••••••••",
                icon: Icons.lock_outline,
                isPassword: true,
                delay: 500,
                viewModel: viewModel,
              ),

              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: viewModel.isLoading
                      ? null
                      : () async {
                          bool success = await viewModel.resetPassword();
                          if (context.mounted) {
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني.",
                                    style: GoogleFonts.cairo(),
                                  ),
                                  backgroundColor: AppColors.primaryDark,
                                ),
                              );
                            } else if (viewModel.errorMessage.isNotEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    viewModel.errorMessage,
                                    style: GoogleFonts.cairo(),
                                  ),
                                  backgroundColor: AppColors.primaryRed,
                                ),
                              );
                            }
                          }
                        },
                  child: Text(
                    "نسيت كلمة المرور؟",
                    style: GoogleFonts.cairo(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 600.ms),

              const SizedBox(height: 30),

              /// 🔹 زر تسجيل الدخول الأمني 🚀 (الربط الحقيقي)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: viewModel.isLoading
                      ? null
                      : () async {
                          // 1. فحص الإدخال
                          String? error = viewModel.validateInputs();
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  error,
                                  style: GoogleFonts.cairo(),
                                ),
                                backgroundColor: AppColors.primaryRed,
                              ),
                            );
                            return;
                          }

                          // 2. الاتصال بالسيرفر
                          bool success = await viewModel.login();

                          // 3. المنطق بعد الرد
                          if (context.mounted) {
                            if (success) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const HomeScreen(),
                                ),
                              );
                            } else {
                              // إذا فشل الدخول نعرض رسالة الفايربيس المترجمة
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    viewModel.errorMessage,
                                    style: GoogleFonts.cairo(),
                                  ),
                                  backgroundColor: AppColors.primaryRed,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    elevation: 8,
                    shadowColor: AppColors.primaryDark.withAlpha(100),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: viewModel.isLoading
                      ? const SizedBox(
                          width: 25,
                          height: 25,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          "تسجيل الدخول",
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ).animate().scale(delay: 700.ms),

              const SizedBox(height: 30),

              /// 🔹 الفواصل (Divider)
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      "أو المتابعة عبر",
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ).animate().fadeIn(delay: 800.ms),

              const SizedBox(height: 25),

              /// 🔹 زر جوجل (الربط الحقيقي)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: viewModel.isLoading
                        ? null
                        : () async {
                            bool success = await viewModel.loginWithGoogle();
                            if (context.mounted) {
                              if (success) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const HomeScreen(),
                                  ),
                                );
                              } else if (viewModel.errorMessage.isNotEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      viewModel.errorMessage,
                                      style: GoogleFonts.cairo(),
                                    ),
                                    backgroundColor: AppColors.primaryRed,
                                  ),
                                );
                              }
                            }
                          },
                    child: _buildSocialButton(),
                  ),
                ],
              ).animate().slideY(begin: 0.5, end: 0, delay: 900.ms),

              const SizedBox(height: 30),

              /// 🔗 الانتقال لإنشاء حساب
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "ليس لديك حساب؟",
                    style: GoogleFonts.cairo(color: Colors.grey),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      );
                    },
                    child: Text(
                      "إنشاء حساب",
                      style: GoogleFonts.cairo(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 1000.ms),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔹 ودجت حقل الإدخال مع الـ Controllers
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    required int delay,
    LoginViewModel? viewModel,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? viewModel!.isObscure : false,
        keyboardType: isPassword
            ? TextInputType.visiblePassword
            : TextInputType.emailAddress,
        style: GoogleFonts.cairo(
          color: AppColors.textBlack,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.cairo(
            color: Colors.grey.shade400,
            fontSize: 13,
          ),
          prefixIcon: Icon(icon, color: AppColors.primaryDark.withAlpha(150)),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    viewModel!.isObscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey,
                  ),
                  onPressed: () => viewModel.togglePasswordVisibility(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    ).animate(delay: delay.ms).fadeIn().slideX(begin: 0.1, end: 0);
  }

  /// 🔹 ودجت السوشيال (Google)
  Widget _buildSocialButton() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Image.asset(
        'assets/images/google_logo.png', // تأكد إن الصورة موجودة
        height: 25,
      ),
    );
  }
}
