import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import '../viewmodels/onboarding_viewmodel.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/permission_manager.dart';
import 'login_screen.dart';

/// ==========================================
/// 🎯 Onboarding Screen
/// ==========================================
/// شاشة الترحيب والصلاحيات للمستخدمين الجدد
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isRequestingPermissions = false;

  static const Color _prototypeMaroon = Color(0xFF800000);

  Future<void> _completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } catch (e) {
      debugPrint('❌ OnboardingScreen: Failed to complete onboarding - $e');
    }
  }

  Future<void> _requestPermissions() async {
    if (_isRequestingPermissions) return;

    setState(() => _isRequestingPermissions = true);

    try {
      // Request permissions one by one with explanations
      await _requestPermissionWithDialog(
        title: 'onboarding.permissions.location_title'.tr(),
        description: 'onboarding.permissions.location_desc'.tr(),
        icon: Icons.location_on_rounded,
        onRequest: () => PermissionManager.requestLocationPermission(),
      );

      await _requestPermissionWithDialog(
        title: 'onboarding.permissions.bg_location_title'.tr(),
        description: 'onboarding.permissions.bg_location_desc'.tr(),
        icon: Icons.my_location_rounded,
        onRequest: () =>
            PermissionManager.requestBackgroundLocationPermission(),
      );

      await _requestPermissionWithDialog(
        title: 'onboarding.permissions.notifications_title'.tr(),
        description: 'onboarding.permissions.notifications_desc'.tr(),
        icon: Icons.notifications_active_rounded,
        onRequest: () => PermissionManager.requestNotificationPermission(),
      );

      await _requestPermissionWithDialog(
        title: 'onboarding.permissions.battery_title'.tr(),
        description: 'onboarding.permissions.battery_desc'.tr(),
        icon: Icons.shield_rounded,
        onRequest: () => PermissionManager.requestIgnoreBatteryOptimization(),
      );

      // Complete onboarding
      await _completeOnboarding();
    } catch (e) {
      debugPrint('❌ OnboardingScreen: Permission request error - $e');
    } finally {
      if (mounted) {
        setState(() => _isRequestingPermissions = false);
      }
    }
  }

  Future<void> _requestPermissionWithDialog({
    required String title,
    required String description,
    required IconData icon,
    required Future<bool> Function() onRequest,
  }) async {
    if (!mounted) return;

    // Show explanation dialog
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: AppColors.primaryDark, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          description,
          style: GoogleFonts.cairo(
            fontSize: 14,
            height: 1.6,
            color: Colors.grey.shade700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('onboarding.skip'.tr(), style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await onRequest();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'onboarding.grant_permission'.tr(),
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Soft dark-red animated background circle
          PositionedDirectional(
            top: -50,
            end: -50,
            child:
                Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _prototypeMaroon.withValues(alpha: 0.05),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(
                      begin: 1.0,
                      end: 1.2,
                      duration: 4000.ms,
                      curve: Curves.easeInOut,
                    ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Premium Guardian 360 Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.spa,
                            color: _prototypeMaroon,
                            size: 24,
                          ).animate().fadeIn().scale(),
                          const SizedBox(width: 8),
                          Text(
                            'Guardian 360',
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: _prototypeMaroon,
                            ),
                          ).animate().fadeIn(delay: 200.ms).slideX(),
                        ],
                      ),
                      if (!viewModel.isLastPage)
                        TextButton(
                          onPressed: () async {
                            await _completeOnboarding();
                          },
                          child: Text(
                            'onboarding.skip'.tr(),
                            style: GoogleFonts.cairo(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ).animate().fadeIn()
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
                ),

                // PageView
                Expanded(
                  child: PageView.builder(
                    controller: viewModel.pageController,
                    onPageChanged: (index) {
                      viewModel.onPageChanged(index);
                      HapticFeedback.lightImpact();
                    },
                    itemCount: viewModel.pages.length,
                    itemBuilder: (context, index) {
                      final page = viewModel.pages[index];
                      return _buildPage(page, index);
                    },
                  ),
                ),

                // Bottom Navigation & Animated Dots
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 40,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Animated Dots Indicator
                      Row(
                        children: List.generate(
                          viewModel.pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsetsDirectional.only(end: 6),
                            height: 8,
                            width: index == viewModel.currentIndex ? 24 : 8,
                            decoration: BoxDecoration(
                              color: index == viewModel.currentIndex
                                  ? _prototypeMaroon
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),

                      // Next/Finish button
                      ElevatedButton(
                            onPressed: _isRequestingPermissions
                                ? null
                                : () async {
                                    if (!viewModel.isLastPage) {
                                      viewModel.goNext();
                                    } else {
                                      await _requestPermissions();
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _prototypeMaroon,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 25,
                                vertical: 12,
                              ),
                              elevation: 10,
                              shadowColor: _prototypeMaroon.withValues(
                                alpha: 0.4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: _isRequestingPermissions
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        !viewModel.isLastPage
                                            ? 'onboarding.next'.tr()
                                            : 'onboarding.start'.tr(),
                                        style: GoogleFonts.cairo(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                          )
                          .animate(
                            target: viewModel.isLastPage ? 1 : 0,
                          )
                          .scaleXY(end: 1.1, duration: 300.ms),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildPremiumIcon(IconData icon, int index) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer soft pulse
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _prototypeMaroon.withValues(alpha: 0.02),
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
         .scaleXY(begin: 0.85, end: 1.18, duration: 2800.ms, curve: Curves.easeInOut),

        // Inner ring
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _prototypeMaroon.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
         .scaleXY(begin: 0.90, end: 1.10, duration: 2200.ms, curve: Curves.easeInOut),

        // Core icon container
        Container(
          padding: const EdgeInsets.all(35),
          decoration: BoxDecoration(
            color: _prototypeMaroon.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 80, color: _prototypeMaroon)
              .animate(key: ValueKey(index))
              .fadeIn(duration: 600.ms)
              .scale(delay: 100.ms)
              .then()
              .shimmer(
                duration: 1500.ms,
                color: Colors.redAccent.withValues(alpha: 0.2),
              ),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
         .scaleXY(begin: 1.0, end: 1.035, duration: 2000.ms, curve: Curves.easeInOut),
      ],
    );
  }

  Widget _buildPage(OnboardingPage page, int index) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Transform.translate(
              offset: const Offset(0, -22),
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Premium Icon
                    _buildPremiumIcon(page.icon, index),

                    const SizedBox(height: 50),

                    // Title
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 350),
                      child: Text(
                            page.titleKey.tr(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              height: 1.2,
                            ),
                          )
                          .animate(key: ValueKey(index + 10))
                          .fadeIn(duration: 600.ms, delay: 300.ms)
                          .slideY(begin: 0.3, end: 0),
                    ),

                    const SizedBox(height: 15),

                    // Description
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 350),
                      child: Text(
                            page.descriptionKey.tr(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                              height: 1.6,
                            ),
                          )
                          .animate(key: ValueKey(index + 20))
                          .fadeIn(duration: 600.ms, delay: 500.ms),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
