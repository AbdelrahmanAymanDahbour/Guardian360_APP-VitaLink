import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/constants/app_colors.dart';
import '../viewmodels/home_viewmodel.dart';

import '../../map/views/map_screen.dart';
import '../../profile/views/profile_screen.dart';
import '../../settings/views/settings_screen.dart';
import '../../sos/views/sos_countdown_screen.dart';
import '../../contacts/views/contacts_screen.dart';
import '../../safe_arrival/views/safe_arrival_screen.dart';
import '../../ai/views/ai_chat_screen.dart';
import '../../kroka/views/kroka_screen.dart';
import '../../medical/views/medical_record_screen.dart';
import '../../notifications/views/notification_center_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HomeViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          PageView(
            controller: viewModel.pageController,
            physics: viewModel.selectedIndex == 1
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            onPageChanged: viewModel.updateIndexFromScroll,
            children: [
              _HomeTab(viewModel: viewModel),
              const MapScreen(),
              const ProfileScreen(),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryDark,
        elevation: 8,
        shape: const CircleBorder(),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AIChatScreen()),
          );
        },
        child:
            const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 30)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 1, end: 1.1, duration: 1.seconds)
                .shimmer(
                  delay: 2.seconds,
                  duration: 1.seconds,
                  color: Colors.white70,
                ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        elevation: 15,
        height: 70,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavButton(
              icon: Icons.home_rounded,
              index: 0,
              viewModel: viewModel,
            ),
            _buildNavButton(
              icon: Icons.map_rounded,
              index: 1,
              viewModel: viewModel,
            ),
            const SizedBox(width: 40),
            _buildNavButton(
              icon: Icons.person_rounded,
              index: 2,
              viewModel: viewModel,
            ),
            IconButton(
              icon: const Icon(
                Icons.settings_rounded,
                color: Colors.grey,
                size: 28,
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required int index,
    required HomeViewModel viewModel,
  }) {
    final isSelected = viewModel.selectedIndex == index;

    return IconButton(
      icon:
          Icon(
                icon,
                color: isSelected
                    ? AppColors.primaryDark
                    : Colors.grey.shade400,
                size: 28,
              )
              .animate(target: isSelected ? 1 : 0)
              .scaleXY(end: 1.15, duration: 300.ms),
      onPressed: () {
        if (!isSelected) {
          HapticFeedback.selectionClick();
        }
        viewModel.changePage(index);
      },
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final bool isEmergency = viewModel.accidentDetected;
    final bool isHealthy = viewModel.isSystemHealthy;

    if (isEmergency && viewModel.lastAccidentTime != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (!viewModel.accidentDetected || viewModel.lastAccidentTime == null) {
          return;
        }

        final double impact = viewModel.lastDetectedImpact;
        final double rotation = viewModel.lastDetectedRotation;

        viewModel.acknowledgeAccidentHandled();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SOSCountdownScreen(
              initialImpact: impact,
              initialRotation: rotation,
              triggerReason: 'automatic_detection',
            ),
          ),
        );
      });
    }

    final Color statusIconBg = isEmergency
        ? const Color(0xFFFFEBEE)
        : isHealthy
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFF8E1);

    final Color statusIconColor = isEmergency
        ? AppColors.primaryRed
        : isHealthy
        ? Colors.green
        : Colors.orange;

    final IconData statusIcon = isEmergency
        ? Icons.warning_amber_rounded
        : isHealthy
        ? Icons.shield_rounded
        : Icons.health_and_safety_rounded;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                          Icons.spa_rounded,
                          color: AppColors.primaryDark,
                          size: 28,
                        )
                        .animate()
                        .scaleXY(end: 1.2, duration: 600.ms)
                        .then()
                        .scaleXY(end: 1.0),
                    const SizedBox(width: 10),
                    Text(
                      "home.title".tr(),
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textBlack,
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideX(),
                  ],
                ),
                _buildNotificationBell(context),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                '${viewModel.greeting}, ${viewModel.userName}',
                style: GoogleFonts.cairo(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textGrey,
                ),
              ).animate().fadeIn(delay: 250.ms),
            ),
          ),
          const SizedBox(height: 12),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 25),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withAlpha(15),
                  blurRadius: 20,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: statusIconBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(statusIcon, color: statusIconColor, size: 22),
                    )
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(
                      duration: 2500.ms,
                      color: statusIconColor.withAlpha(80),
                    ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        viewModel.statusTitle,
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textBlack,
                        ),
                      ),
                      Text(
                        viewModel.statusSubtitle,
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          color: AppColors.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),

          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.heavyImpact();

                  if (!viewModel.isMedicalProfileComplete) {
                    _showSosMedicalWarningDialog(context, viewModel);
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SOSCountdownScreen(),
                    ),
                  );
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (int i = 0; i < 3; i++)
                      Container(
                            width: 200 + (i * 50),
                            height: 200 + (i * 50),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primaryDark.withAlpha(
                                  (10 - (i * 2)).toInt(),
                                ),
                              ),
                            ),
                          )
                          .animate(onPlay: (c) => c.repeat())
                          .scaleXY(
                            begin: 0.8,
                            end: 1.3,
                            duration: (2000 + (i * 600)).ms,
                          )
                          .fadeOut(),
                    Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primaryRed,
                                AppColors.primaryDark,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryDark.withAlpha(80),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                      Icons.touch_app_rounded,
                                      size: 50,
                                      color: Colors.white,
                                    )
                                    .animate(
                                      onPlay: (c) => c.repeat(reverse: true),
                                    )
                                    .moveY(
                                      begin: -3,
                                      end: 3,
                                      duration: 1.5.seconds,
                                    ),
                                Text(
                                  "home.sos_button".tr(),
                                  style: GoogleFonts.montserrat(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  "home.sos_subtitle".tr(),
                                  style: GoogleFonts.cairo(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(begin: 0.98, end: 1.02, duration: 1500.ms),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(25, 0, 25, 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    title: viewModel.protectionButtonText,
                    icon: Icons.shield_rounded,
                    color: AppColors.primaryDark,
                    onTap: () async {
                      HapticFeedback.mediumImpact();

                      final success = await viewModel.toggleProtection();
                      if (!success && context.mounted) {
                        _showMedicalRequiredDialog(context, viewModel);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    context,
                    title: viewModel.tripButtonText,
                    icon: Icons.route_rounded,
                    color: AppColors.primaryRed,
                    onTap: () async {
                      HapticFeedback.mediumImpact();

                      final success = await viewModel.toggleTrip();
                      if (!success && context.mounted) {
                        _showMedicalRequiredDialog(context, viewModel);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(25, 0, 25, 20),
            child: Row(
              children: [
                _buildCompactCard(
                  context,
                  title: "home.card_kroka".tr(),
                  icon: Icons.car_crash_rounded,
                  index: 0,
                ),
                const SizedBox(width: 12),
                _buildCompactCard(
                  context,
                  title: "home.card_contacts".tr(),
                  icon: Icons.people_outline_rounded,
                  index: 1,
                ),
                const SizedBox(width: 12),
                _buildCompactCard(
                  context,
                  title: "home.card_safe_arrival".tr(),
                  icon: Icons.beenhere_outlined,
                  index: 2,
                ),
              ],
            ),
          ),

          const SizedBox(height: 45),
        ],
      ),
    );
  }

  Widget _buildNotificationBell(BuildContext context) {
    final unreadCount = viewModel.unreadNotificationCount;
    final hasUnread = unreadCount > 0;
    final badgeText = unreadCount >= 10 ? '9+' : '$unreadCount';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.mediumImpact();

          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10),
                ],
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.primaryDark,
                size: 22,
              ),
            ),
            if (hasUnread)
              PositionedDirectional(
                top: -5,
                end: -5,
                child:
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryRed.withAlpha(70),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        badgeText,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ).animate().scaleXY(
                      begin: 0.8,
                      end: 1,
                      duration: 220.ms,
                      curve: Curves.easeOutBack,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withAlpha(40)),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn().slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildCompactCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required int index,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();

          if (index == 0) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const KrokaScreen()),
            );
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ContactsScreen()),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SafeArrivalScreen()),
            );
          }
        },
        child: Container(
          height: 85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primaryDark, size: 28),
              const SizedBox(height: 6),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ).animate().fadeIn().scaleXY(begin: 0.9, end: 1),
    );
  }

  void _showSosMedicalWarningDialog(
    BuildContext context,
    HomeViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.emergency_rounded, color: AppColors.primaryRed),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'home.medical_incomplete_title'.tr(),
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'home.medical_incomplete_body'.tr(),
          style: GoogleFonts.cairo(
            fontSize: 13,
            color: Colors.grey.shade700,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SOSCountdownScreen()),
              );
            },
            child: Text(
              'home.send_sos_now'.tr(),
              style: GoogleFonts.cairo(
                color: AppColors.primaryRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MedicalRecordScreen()),
              );
              if (context.mounted) {
                await viewModel.refreshMedicalStatusFromServer();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'home.complete_medical'.tr(),
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

  void _showMedicalRequiredDialog(
    BuildContext context,
    HomeViewModel viewModel,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.health_and_safety_rounded,
              color: AppColors.primaryRed,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'home.medical_required_title'.tr(),
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          viewModel.medicalRequirementMessage.isNotEmpty
              ? viewModel.medicalRequirementMessage
              : 'home.medical_required_fallback'.tr(),
          style: GoogleFonts.cairo(
            fontSize: 13,
            color: Colors.grey.shade700,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'home.later'.tr(),
              style: GoogleFonts.cairo(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MedicalRecordScreen()),
              );
              if (context.mounted) {
                await viewModel.refreshMedicalStatusFromServer();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'home.complete_medical'.tr(),
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
}
