import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';

import '../../../core/constants/app_colors.dart';
import '../viewmodels/otp_viewmodel.dart';
import '../../home/views/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'email_verification_screen.dart';

class OTPScreen extends StatelessWidget {
  final String phoneNumber;

  const OTPScreen({super.key, required this.phoneNumber});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OTPViewModel(
        phoneNumber: phoneNumber,
        onAutoVerificationSuccess: () {
          // 🔒 CRITICAL FIX: Navigate immediately on auto-verification
          if (context.mounted) {
            _navigateToHome(context);
          }
        },
      ),
      child: _OTPContent(phoneNumber: phoneNumber),
    );
  }

  static void _navigateToHome(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final Widget destination = (user != null && user.email != null && !user.emailVerified)
        ? const EmailVerificationScreen()
        : const HomeScreen();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }
}

class _OTPContent extends StatefulWidget {
  final String phoneNumber;
  const _OTPContent({required this.phoneNumber});

  @override
  State<_OTPContent> createState() => _OTPContentState();
}

class _OTPContentState extends State<_OTPContent> {
  final TextEditingController _pinController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _showCustomSnackBar(
    BuildContext context,
    String message, {
    bool isError = true,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFFE53935)
            : AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        elevation: 6,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _handleNavigation(BuildContext context) {
    _showCustomSnackBar(context, "تم التحقق بنجاح! أهلاً بك.", isError: false);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (context.mounted) {
        OTPScreen._navigateToHome(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OTPViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textBlack,
          ),
          onPressed: () => Navigator.pop(context),
        ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),

                        // 🛡️ Security icon
                        Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child:
                              const Icon(
                                    Icons.security_rounded,
                                    size: 70,
                                    color: AppColors.primaryDark,
                                  )
                                  .animate(
                                    onPlay: (c) => c.repeat(reverse: true),
                                  )
                                  .scaleXY(
                                    begin: 1,
                                    end: 1.1,
                                    duration: 1.seconds,
                                  ),
                        ).animate().fadeIn().slideY(begin: -0.2, end: 0),

                        const SizedBox(height: 30),

                        Text(
                          "التحقق الأمني",
                          style: GoogleFonts.cairo(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textBlack,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "أدخل الرمز المكون من 6 أرقام الذي تم إرساله إلى\n${widget.phoneNumber}",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // 🔢 Pinput OTP Input with SMS Autofill
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Pinput(
                            controller: _pinController,
                            focusNode: _focusNode,
                            length: 6,
                            autofocus: true,
                            defaultPinTheme: _defaultPinTheme(),
                            focusedPinTheme: _focusedPinTheme(),
                            submittedPinTheme: _submittedPinTheme(),
                            errorPinTheme: _errorPinTheme(),
                            onChanged: (value) {
                              viewModel.updateCode(value);
                            },
                            onCompleted: (pin) async {
                              FocusScope.of(context).unfocus();
                              bool success = await viewModel.verifyCode();
                              if (success && context.mounted) {
                                _handleNavigation(context);
                              } else if (viewModel.errorMessage.isNotEmpty &&
                                  context.mounted) {
                                _showCustomSnackBar(
                                  context,
                                  viewModel.errorMessage,
                                  isError: true,
                                );
                                _pinController.clear();
                              }
                            },
                          ),
                        ).animate().fadeIn(delay: 300.ms),

                        const SizedBox(height: 40),

                        // ⏱️ Resend timer
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: viewModel.canResend
                              ? TextButton.icon(
                                  key: const ValueKey('resend_btn'),
                                  onPressed: () {
                                    viewModel.resendOTP();
                                    _pinController.clear();
                                  },
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    color: AppColors.primaryDark,
                                  ),
                                  label: Text(
                                    "إرسال الرمز مجدداً",
                                    style: GoogleFonts.cairo(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                )
                              : Row(
                                  key: const ValueKey('timer_text'),
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "يمكنك إعادة إرسال الرمز بعد ",
                                      style: GoogleFonts.cairo(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      viewModel.formattedTime,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryRed,
                                      ),
                                    ),
                                  ],
                                ),
                        ),

                        const Spacer(),

                        // Manual verification button
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed:
                                (viewModel.currentCode.length == 6 &&
                                    !viewModel.isVerifying)
                                ? () async {
                                    FocusScope.of(context).unfocus();
                                    bool success = await viewModel.verifyCode();
                                    if (success && context.mounted) {
                                      _handleNavigation(context);
                                    } else if (viewModel
                                            .errorMessage
                                            .isNotEmpty &&
                                        context.mounted) {
                                      _showCustomSnackBar(
                                        context,
                                        viewModel.errorMessage,
                                        isError: true,
                                      );
                                      _pinController.clear();
                                    }
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              disabledBackgroundColor: Colors.grey.shade300,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 5,
                            ),
                            child: viewModel.isVerifying
                                ? const SizedBox(
                                    width: 25,
                                    height: 25,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : Text(
                                    "تأكيد وتوثيق الحساب",
                                    style: GoogleFonts.cairo(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ).animate().scale(delay: 500.ms),

                        const SizedBox(height: 30),
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

  PinTheme _defaultPinTheme() {
    return PinTheme(
      width: 48,
      height: 60,
      textStyle: GoogleFonts.montserrat(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.textBlack,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
    );
  }

  PinTheme _focusedPinTheme() {
    return _defaultPinTheme().copyWith(
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryDark, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withAlpha(40),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  PinTheme _submittedPinTheme() {
    return _defaultPinTheme().copyWith(
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryDark.withAlpha(100)),
      ),
    );
  }

  PinTheme _errorPinTheme() {
    return _defaultPinTheme().copyWith(
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red, width: 2),
      ),
    );
  }
}
