import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/app_colors.dart';
import '../services/firebase_auth_service.dart';
import '../viewmodels/email_verification_viewmodel.dart';
import '../../home/views/home_screen.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends StatelessWidget {
  const EmailVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EmailVerificationViewModel(),
      child: const _EmailVerificationContent(),
    );
  }
}

class _EmailVerificationContent extends StatefulWidget {
  const _EmailVerificationContent();

  @override
  State<_EmailVerificationContent> createState() => _EmailVerificationContentState();
}

class _EmailVerificationContentState extends State<_EmailVerificationContent> {
  final FirebaseAuthService _authService = FirebaseAuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmailVerificationViewModel>().sendVerificationEmail(_authService, isAuto: true);
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message.tr(),
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFE53935) : AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        elevation: 6,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    try {
      await _authService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      _showSnackBar("email_verification.error", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<EmailVerificationViewModel>();
    final currentUserEmail = _authService.currentUser?.email;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Spacer(flex: 1),

                        // Hero Icon Section
                        Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mark_email_unread_rounded,
                            size: 70,
                            color: AppColors.primaryDark,
                          )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scaleXY(begin: 1, end: 1.1, duration: 1.seconds),
                        ).animate().fadeIn().slideY(begin: -0.2, end: 0),

                        const SizedBox(height: 30),

                        // Title
                        Text(
                          "email_verification.title".tr(),
                          style: GoogleFonts.cairo(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textBlack,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

                        const SizedBox(height: 12),

                        // Description
                        Text(
                          "email_verification.description".tr(),
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 300.ms),

                        const SizedBox(height: 25),

                        // Email Pill
                        if (currentUserEmail != null && currentUserEmail.isNotEmpty)
                          Column(
                            children: [
                              Text(
                                "email_verification.email_label".tr(),
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.email_rounded, size: 20, color: Colors.grey.shade600),
                                    const SizedBox(width: 10),
                                    Text(
                                      currentUserEmail,
                                      style: GoogleFonts.cairo(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ).animate().fadeIn(delay: 400.ms),

                        const SizedBox(height: 25),

                        // Soft Informational Hint Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark.withAlpha(15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline_rounded, color: AppColors.primaryDark.withAlpha(200), size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "email_verification.spam_note".tr(),
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    color: AppColors.primaryDark.withAlpha(220),
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 500.ms),

                        const SizedBox(height: 40),
                        
                        // Verified Button
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: viewModel.isLoading
                                ? null
                                : () async {
                                    bool verified = await viewModel.checkVerification(_authService);
                                    if (verified && context.mounted) {
                                      Navigator.pushAndRemoveUntil(
                                        context,
                                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                                        (route) => false,
                                      );
                                    } else if (viewModel.errorMessage != null && context.mounted) {
                                      _showSnackBar(viewModel.errorMessage!, isError: true);
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              disabledBackgroundColor: AppColors.primaryDark.withAlpha(150),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: viewModel.isLoading ? 0 : 4,
                            ),
                            child: viewModel.isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    "email_verification.verified_button".tr(),
                                    style: GoogleFonts.cairo(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ).animate().fadeIn(delay: 600.ms),

                        const SizedBox(height: 20),

                        // Resend Section
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: viewModel.resendCooldown > 0
                              ? Container(
                                  key: const ValueKey('timer'),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: RichText(
                                    text: TextSpan(
                                      style: GoogleFonts.cairo(
                                        fontSize: 14,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      children: [
                                        TextSpan(text: "${"email_verification.resend_wait".tr()} "),
                                        TextSpan(
                                          text: "(${viewModel.resendCooldown})",
                                          style: GoogleFonts.cairo(
                                            color: AppColors.primaryDark,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : TextButton.icon(
                                  key: const ValueKey('resend_btn'),
                                  onPressed: viewModel.isResending
                                      ? null
                                      : () async {
                                          await viewModel.sendVerificationEmail(_authService);
                                          if (viewModel.errorMessage != null && context.mounted) {
                                            _showSnackBar(viewModel.errorMessage!, isError: true);
                                          } else if (viewModel.message != null && context.mounted) {
                                            _showSnackBar(viewModel.message!);
                                          }
                                        },
                                  icon: viewModel.isResending
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.refresh_rounded, size: 20),
                                  label: Text(
                                    "email_verification.resend_button".tr(),
                                    style: GoogleFonts.cairo(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primaryDark,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                ),
                        ).animate().fadeIn(delay: 700.ms),

                        const Spacer(flex: 2),

                        // Sign Out Option
                        TextButton(
                          onPressed: _handleSignOut,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade500,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: Text(
                            "email_verification.sign_out".tr(),
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ).animate().fadeIn(delay: 800.ms),
                        
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
