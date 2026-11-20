import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../viewmodels/settings_viewmodel.dart';
import '../../iot/views/device_connection_screen.dart';
import '../../auth/services/firebase_auth_service.dart';
import '../../auth/views/login_screen.dart';

/// ==========================================
/// ⚙️ Settings Screen V2 - Enterprise Level
/// ==========================================
/// شاشة إعدادات احترافية بمستوى تطبيقات Enterprise
class SettingsScreenV2 extends StatelessWidget {
  const SettingsScreenV2({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SettingsViewModel(),
      child: const _SettingsContent(),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SettingsViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: viewModel.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryDark),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // App Bar مخصص
                _buildSliverAppBar(context, viewModel),

                // المحتوى
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),

                        // بطاقة الملف الشخصي
                        _buildProfileCard(viewModel),
                        const SizedBox(height: 32),

                        // قسم الحساب
                        _buildSectionTitle('settings.sections.account'.tr()),
                        const SizedBox(height: 12),
                        _buildAccountSection(context, viewModel),
                        const SizedBox(height: 32),

                        // قسم الطوارئ والسلامة
                        _buildSectionTitle('settings.sections.safety'.tr()),
                        const SizedBox(height: 12),
                        _buildSafetySection(viewModel),
                        const SizedBox(height: 32),

                        // قسم الكشف والحساسية
                        _buildSectionTitle('settings.sections.detection'.tr()),
                        const SizedBox(height: 12),
                        _buildDetectionSection(viewModel),
                        const SizedBox(height: 32),

                        // قسم الأجهزة المتصلة
                        _buildSectionTitle('settings.sections.devices'.tr()),
                        const SizedBox(height: 12),
                        _buildDevicesSection(context, viewModel),
                        const SizedBox(height: 32),

                        // قسم التطبيق
                        _buildSectionTitle('settings.sections.app'.tr()),
                        const SizedBox(height: 12),
                        _buildAppSection(context, viewModel),
                        const SizedBox(height: 32),

                        // قسم المساعدة والدعم
                        _buildSectionTitle('settings.sections.help'.tr()),
                        const SizedBox(height: 12),
                        _buildHelpSection(context),
                        const SizedBox(height: 40),

                        // زر تسجيل الخروج
                        _buildLogoutButton(context),
                        const SizedBox(height: 20),

                        // معلومات الإصدار
                        _buildVersionInfo(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, SettingsViewModel viewModel) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.textBlack,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          'settings.title'.tr(),
          style: GoogleFonts.cairo(
            color: AppColors.textBlack,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primaryDark.withOpacity(0.05),
                AppColors.background,
              ],
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 16),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: AppColors.primaryDark,
              size: 24,
            ),
          ).animate().fadeIn(delay: 200.ms).scale(),
        ),
      ],
    );
  }

  Widget _buildProfileCard(SettingsViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 30,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewModel.userName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBlack,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  viewModel.userEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/images/logo.png',
              width: 18,
              height: 18,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.spa_rounded,
                color: AppColors.primaryDark,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1, end: 0);
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
            letterSpacing: 0.5,
          ),
        ).animate().fadeIn(duration: 500.ms),
      ),
    );
  }

  Widget _buildAccountSection(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    return _buildSettingsCard([
      _buildSettingsTile(
        title: 'settings.account.profile_title'.tr(),
        subtitle: 'settings.account.profile_subtitle'.tr(),
        icon: Icons.verified_user_rounded,
        iconColor: Colors.blue,
        isActive: true,
      ),
      _buildDivider(),
      _buildSettingsTile(
        title: 'settings.account.password_title'.tr(),
        subtitle: 'settings.account.password_subtitle'.tr(),
        icon: Icons.lock_outline_rounded,
        iconColor: Colors.orange,
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.grey,
        ),
        onTap: () {
          HapticFeedback.lightImpact();
          _showPasswordChangeDialog(context);
        },
      ),
    ]);
  }

  Widget _buildSafetySection(SettingsViewModel viewModel) {
    return _buildSettingsCard([
      _buildSettingsTile(
        title: 'settings.safety.location_title'.tr(),
        subtitle: 'settings.safety.location_subtitle'.tr(),
        icon: Icons.my_location_rounded,
        iconColor: Colors.red,
        isActive: viewModel.isLiveLocationOn,
        trailing: Switch(
          value: viewModel.isLiveLocationOn,
          activeColor: AppColors.primaryDark,
          onChanged: (val) {
            HapticFeedback.lightImpact();
            viewModel.toggleLiveLocation(val);
          },
        ),
      ),
      _buildDivider(),
      _buildSettingsTile(
        title: 'settings.safety.shake_title'.tr(),
        subtitle: 'settings.safety.shake_subtitle'.tr(),
        icon: Icons.vibration_rounded,
        iconColor: Colors.deepOrange,
        isActive: viewModel.isShakeToSosOn,
        trailing: Switch(
          value: viewModel.isShakeToSosOn,
          activeColor: AppColors.primaryDark,
          onChanged: (val) {
            HapticFeedback.lightImpact();
            viewModel.toggleShakeToSos(val);
          },
        ),
      ),
      _buildDivider(),
      _buildSettingsTile(
        title: 'settings.safety.battery_title'.tr(),
        subtitle: 'settings.safety.battery_subtitle'.tr(),
        icon: Icons.battery_charging_full_rounded,
        iconColor: Colors.green,
        isActive: viewModel.isBatteryAlertOn,
        trailing: Switch(
          value: viewModel.isBatteryAlertOn,
          activeColor: AppColors.primaryDark,
          onChanged: (val) {
            HapticFeedback.lightImpact();
            viewModel.toggleBatteryAlert(val);
          },
        ),
      ),
    ]);
  }

  Widget _buildDetectionSection(SettingsViewModel viewModel) {
    return _buildSettingsCard([
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.speed_rounded,
                    color: AppColors.primaryDark,
                    size: 20,
                  ),
                ).animate(target: viewModel.sensitivity >= 75 ? 1 : 0).scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.08, 1.08),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'settings.detection.sensitivity_title'.tr(),
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textBlack,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${viewModel.sensitivity.toInt()}%',
                    style: GoogleFonts.montserrat(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
                  viewModel.sensitivityLabelKey.tr(),
                  style: GoogleFonts.cairo(
                    color: AppColors.primaryDark.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                )
                .animate(key: ValueKey(viewModel.sensitivityLabelKey))
                .fadeIn(),
            const SizedBox(height: 12),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                activeTrackColor: AppColors.primaryDark,
                inactiveTrackColor: Colors.grey.shade200,
                thumbColor: AppColors.primaryDark,
                overlayColor: AppColors.primaryDark.withOpacity(0.12),
              ),
              child: Slider(
                value: viewModel.sensitivity,
                min: 0,
                max: 100,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  viewModel.changeSensitivity(val);
                },
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildDevicesSection(
    BuildContext context,
    SettingsViewModel viewModel,
  ) {
    return _buildSettingsCard([
      _buildSettingsTile(
        title: 'settings.devices.connection_title'.tr(),
        subtitle: viewModel.isDeviceConnected
            ? '${viewModel.deviceName} • ${'settings.devices.connected'.tr()}'
            : 'settings.devices.connection_subtitle'.tr(),
        icon: Icons.wifi_tethering_rounded,
        iconColor: viewModel.isDeviceConnected ? Colors.green : Colors.grey,
        isActive: viewModel.isDeviceConnected,
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DeviceConnectionScreen(),
            ),
          );
        },
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryDark.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'settings.devices.manage'.tr(),
            style: GoogleFonts.cairo(
              color: AppColors.primaryDark,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildAppSection(BuildContext context, SettingsViewModel viewModel) {
    return _buildSettingsCard([
      _buildSettingsTile(
        title: 'settings.app.voice_title'.tr(),
        subtitle: 'settings.app.voice_subtitle'.tr(),
        icon: Icons.record_voice_over_rounded,
        iconColor: Colors.teal,
        isActive: viewModel.isSoundEnabled,
        trailing: Switch(
          value: viewModel.isSoundEnabled,
          activeColor: AppColors.primaryDark,
          onChanged: (val) {
            HapticFeedback.lightImpact();
            viewModel.toggleSound(val);
          },
        ),
      ),
      _buildDivider(),
      _buildSettingsTile(
        title: 'settings.app.language_title'.tr(),
        subtitle: context.locale.languageCode == 'ar' ? 'العربية' : 'English',
        icon: Icons.language_rounded,
        iconColor: Colors.blueAccent,
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.grey,
        ),
        onTap: () => _showLanguageSheet(context),
      ),
    ]);
  }

  Widget _buildHelpSection(BuildContext context) {
    return _buildSettingsCard([
      _buildSettingsTile(
        title: 'settings.help.faq_title'.tr(),
        subtitle: 'settings.help.faq_subtitle'.tr(),
        icon: Icons.help_outline_rounded,
        iconColor: Colors.amber,
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.grey,
        ),
        onTap: () {
          HapticFeedback.lightImpact();
          _showFAQDialog(context);
        },
      ),
      _buildDivider(),
      _buildSettingsTile(
        title: 'settings.help.support_title'.tr(),
        subtitle: 'settings.help.support_subtitle'.tr(),
        icon: Icons.support_agent_rounded,
        iconColor: Colors.cyan,
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.grey,
        ),
        onTap: () {
          HapticFeedback.lightImpact();
          _showContactSupportDialog(context);
        },
      ),
      _buildDivider(),
      _buildSettingsTile(
        title: 'settings.help.about_title'.tr(),
        subtitle: 'settings.help.about_subtitle'.tr(),
        icon: Icons.info_outline_rounded,
        iconColor: Colors.blueGrey,
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Colors.grey,
        ),
        onTap: () {
          HapticFeedback.lightImpact();
          _showAboutDialog(context);
        },
      ),
    ]);
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(children: children),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildSettingsTile({
    required String title,
    String? subtitle,
    required IconData icon,
    required Color iconColor,
    bool isActive = false,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryDark.withOpacity(0.1)
              : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isActive ? AppColors.primaryDark : Colors.grey.shade600,
          size: 22,
        ),
      ).animate(target: isActive ? 1 : 0).shimmer(duration: 1000.ms),
      title: Text(
        title,
        style: GoogleFonts.cairo(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.textBlack,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
      trailing: trailing,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 0,
      indent: 70,
      endIndent: 20,
      color: Colors.grey.shade100,
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.red.withOpacity(0.05),
          foregroundColor: Colors.red,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: () {
          HapticFeedback.heavyImpact();
          _showLogoutDialog(context);
        },
        icon: const Icon(Icons.logout_rounded, size: 22),
        label: Text(
          'settings.logout'.tr(),
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildVersionInfo() {
    return Center(
      child: Column(
        children: [
          Text(
            'Guardian 360',
            style: GoogleFonts.montserrat(
              color: AppColors.primaryDark,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'settings.version.label'.tr(),
            style: GoogleFonts.montserrat(
              color: Colors.grey[400],
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'settings.version.copyright'.tr(),
            style: GoogleFonts.cairo(
              color: Colors.grey[400],
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  void _showLanguageSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'settings.app.language_title'.tr(),
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textBlack,
                  ),
                ),
                const SizedBox(height: 20),
                _buildLanguageOption(
                  context,
                  title: 'العربية',
                  locale: const Locale('ar'),
                ),
                const SizedBox(height: 12),
                _buildLanguageOption(
                  context,
                  title: 'English',
                  locale: const Locale('en'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption(
    BuildContext context, {
    required String title,
    required Locale locale,
  }) {
    final isSelected = context.locale.languageCode == locale.languageCode;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        await context.setLocale(locale);
        if (context.mounted) Navigator.pop(context);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryDark.withOpacity(0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? AppColors.primaryDark : Colors.grey.shade500,
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textBlack,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPasswordChangeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.primaryDark,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'settings.password_dialog.title'.tr(),
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
          'settings.password_dialog.body'.tr(),
          style: GoogleFonts.cairo(
            fontSize: 13,
            color: Colors.grey.shade700,
            height: 1.5,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'settings.password_dialog.ok'.tr(),
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

  void _showFAQDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.help_outline_rounded, color: Colors.amber),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'settings.help.faq_title'.tr(),
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            'settings.help.faq_body'.tr(),
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.6,
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'settings.help.ok'.tr(),
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

  void _showContactSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.support_agent_rounded, color: Colors.cyan),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'settings.help.support_title'.tr(),
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
          'settings.help.support_body'.tr(),
          style: GoogleFonts.cairo(
            fontSize: 13,
            color: Colors.grey.shade700,
            height: 1.6,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'settings.help.ok'.tr(),
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

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.blueGrey),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'settings.help.about_title'.tr(),
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.spa_rounded,
                    size: 48,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Guardian 360',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Version 1.0.0 (Secure Beta)',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'settings.help.about_body'.tr(),
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'settings.help.ok'.tr(),
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

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 10),
            Text(
              'settings.logout_dialog.title'.tr(),
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: AppColors.textBlack,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'settings.logout_dialog.message'.tr(),
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
              'settings.logout_dialog.cancel'.tr(),
              style: GoogleFonts.cairo(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuthService().signOut();

              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'settings.logout_dialog.confirm'.tr(),
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
