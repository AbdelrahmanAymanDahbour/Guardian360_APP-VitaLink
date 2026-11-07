import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/constants/app_colors.dart';
import '../viewmodels/signup_viewmodel.dart';
import 'otp_screen.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SignupViewModel(),
      child: const _SignupContent(),
    );
  }
}

class _SignupContent extends StatelessWidget {
  const _SignupContent();

  void _showCustomSnackBar(
    BuildContext context,
    String messageKey, {
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
                messageKey.tr(),
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

  Future<void> _submit(BuildContext context, SignupViewModel viewModel) async {
    FocusScope.of(context).unfocus();

    final validationError = viewModel.validateInputs();
    if (validationError != null) {
      _showCustomSnackBar(context, validationError);
      return;
    }

    final success = await viewModel.createAccount();

    if (!context.mounted) return;

    if (success) {
      _showCustomSnackBar(
        context,
        'signup.success.account_ready',
        isError: false,
      );

      await Future.delayed(const Duration(milliseconds: 700));

      if (!context.mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              OTPScreen(phoneNumber: viewModel.phoneController.text.trim()),
        ),
      );
    } else {
      _showCustomSnackBar(
        context,
        viewModel.errorKey.isNotEmpty ? viewModel.errorKey : 'errors.unknown',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SignupViewModel>();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.surfaceWhite,
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),

                  Text(
                    'signup.title'.tr(),
                    style: GoogleFonts.cairo(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textBlack,
                      height: 1.2,
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1, end: 0),

                  const SizedBox(height: 6),

                  Text(
                    'signup.subtitle'.tr(),
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      color: AppColors.textGrey,
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 35),

                  _buildLabel('signup.full_name'.tr(), 400),
                  _buildTextField(
                    controller: viewModel.nameController,
                    hint: 'signup.hints.full_name'.tr(),
                    icon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r"[a-zA-Z\u0600-\u06FF\s]"),
                      ),
                    ],
                    delay: 400,
                  ),

                  const SizedBox(height: 18),

                  _buildLabel('signup.phone'.tr(), 500),
                  _buildTextField(
                    controller: viewModel.phoneController,
                    hint: 'signup.hints.phone'.tr(),
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    delay: 500,
                  ),

                  const SizedBox(height: 18),

                  _buildLabel('signup.email'.tr(), 600),
                  _buildTextField(
                    controller: viewModel.emailController,
                    hint: 'signup.hints.email'.tr(),
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    delay: 600,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'errors.email_required'.tr();
                      }
                      final emailRegex = RegExp(
                        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                      );
                      if (!emailRegex.hasMatch(value.trim())) {
                        return 'errors.invalid_email'.tr();
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 18),

                  _buildLabel('signup.password'.tr(), 700),
                  _buildTextField(
                    controller: viewModel.passwordController,
                    hint: 'signup.hints.password'.tr(),
                    icon: Icons.lock_outline_rounded,
                    isPassword: true,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    delay: 700,
                    viewModel: viewModel,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'errors.password_required'.tr();
                      }

                      final password = value.trim();

                      if (password.length < 8) {
                        return 'errors.password_min_length'.tr();
                      }

                      final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
                      final hasNumber = RegExp(r'[0-9]').hasMatch(password);
                      final hasSpecialChar = RegExp(
                        r'[@$!%*?&#^()_+=\-\[\]{}|\\:;"<>,.~/`]',
                      ).hasMatch(password);

                      if (!hasLetter) {
                        return 'errors.password_needs_letter'.tr();
                      }

                      if (!hasNumber) {
                        return 'errors.password_needs_number'.tr();
                      }

                      if (!hasSpecialChar) {
                        return 'errors.password_needs_special'.tr();
                      }

                      return null;
                    },
                  ),

                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 16,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'signup.password_note'.tr(),
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 800.ms),

                  const SizedBox(height: 18),

                  _buildLabel('signup.confirm_password'.tr(), 850),
                  _buildTextField(
                    controller: viewModel.confirmPasswordController,
                    hint: 'signup.confirm_password'.tr(),
                    icon: Icons.lock_outline_rounded,
                    isPassword: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    delay: 850,
                    viewModel: viewModel,
                    onSubmitted: (_) => _submit(context, viewModel),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'errors.password_required'.tr();
                      }
                      if (value.trim() != viewModel.passwordController.text.trim()) {
                        return 'signup.errors.passwords_do_not_match'.tr();
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: viewModel.isLoading
                          ? null
                          : () => _submit(context, viewModel),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 8,
                        shadowColor: AppColors.primaryDark.withAlpha(102),
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
                              'signup.btn_create'.tr(),
                              style: GoogleFonts.cairo(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ).animate().scaleXY(
                    begin: 0.8,
                    end: 1,
                    duration: 600.ms,
                    delay: 900.ms,
                  ),

                  const SizedBox(height: 25),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'signup.have_account'.tr(),
                        style: GoogleFonts.cairo(
                          color: AppColors.textGrey,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'signup.login'.tr(),
                          style: GoogleFonts.cairo(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 1000.ms),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, int delay) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: Text(
        text,
        style: GoogleFonts.cairo(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: AppColors.textBlack,
        ),
      ),
    ).animate(delay: delay.ms).fadeIn();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    required TextInputAction textInputAction,
    required int delay,
    SignupViewModel? viewModel,
    List<String>? autofillHints,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onSubmitted,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withAlpha(20),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: isPassword ? viewModel!.isObscure : false,
            textInputAction: textInputAction,
            keyboardType: keyboardType ?? TextInputType.text,
            autofillHints: autofillHints,
            inputFormatters: inputFormatters,
            textCapitalization: textCapitalization,
            onFieldSubmitted: onSubmitted,
            validator: validator,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: GoogleFonts.cairo(
              color: AppColors.textBlack,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.cairo(
                color: Colors.grey[400],
                fontSize: 14,
              ),
              prefixIcon: Icon(
                icon,
                color: AppColors.primaryDark.withAlpha(180),
                size: 22,
              ),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        viewModel!.isObscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey[500],
                      ),
                      onPressed: viewModel.togglePasswordVisibility,
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: AppColors.primaryDark,
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: Color(0xFFE53935),
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: Color(0xFFE53935),
                  width: 2,
                ),
              ),
              errorStyle: GoogleFonts.cairo(
                color: const Color(0xFFE53935),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
        ).animate(delay: delay.ms).fadeIn().slideY(begin: 0.1, end: 0),
      ],
    );
  }
}
