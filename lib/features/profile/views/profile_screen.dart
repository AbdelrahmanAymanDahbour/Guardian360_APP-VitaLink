import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/constants/app_colors.dart';
import '../../contacts/views/contacts_screen.dart';
import '../../home/viewmodels/home_viewmodel.dart';
import '../../medical/views/medical_record_screen.dart';
import '../viewmodels/profile_viewmodel.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileViewModel(),
      child: const _ProfileContent(),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ProfileViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'profile.title'.tr(),
          style: GoogleFonts.cairo(
            color: AppColors.textBlack,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          tooltip: 'profile.back'.tr(),
          icon: Transform.scale(
            scaleX: Directionality.of(context) == ui.TextDirection.rtl ? -1 : 1,
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.textBlack,
            ),
          ),
          onPressed: () {
            final homeVm =
                context.read<HomeViewModel>();
            homeVm.changePage(0);
          },
        ),
        actions: [
          IconButton(
            tooltip: 'profile.edit_tooltip'.tr(),
            icon: const Icon(Icons.edit_rounded, color: AppColors.primaryDark),
            onPressed: viewModel.isLoading
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    viewModel.prepareEditControllers();
                    _showEditBottomSheet(context, viewModel);
                  },
          ).animate().scale(delay: 200.ms),
          const SizedBox(width: 8),
        ],
      ),
      body: viewModel.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryDark),
            )
          : RefreshIndicator(
              color: AppColors.primaryRed,
              onRefresh: viewModel.refreshProfileData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(22, 10, 22, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    _ProfileHeader(viewModel: viewModel),
                    const SizedBox(height: 26),

                    _SectionTitle(
                      title: 'profile.personal_info'.tr(),
                      subtitle: 'profile.personal_info_desc'.tr(),
                    ),
                    const SizedBox(height: 10),

                    _InfoField(
                      icon: Icons.person_outline_rounded,
                      label: 'profile.full_name'.tr(),
                      value: viewModel.displayName.isEmpty
                          ? 'profile.fallbacks.user'.tr()
                          : viewModel.displayName,
                      isEmpty: viewModel.userName.trim().isEmpty,
                    ),
                    const SizedBox(height: 12),
                    _InfoField(
                      icon: Icons.phone_outlined,
                      label: 'profile.phone_number'.tr(),
                      value: viewModel.displayPhone.isEmpty
                          ? 'profile.fallbacks.not_entered'.tr()
                          : viewModel.displayPhone,
                      isEmpty: viewModel.userPhone.trim().isEmpty,
                      forceLtr: true,
                    ),
                    const SizedBox(height: 12),
                    _InfoField(
                      icon: Icons.email_outlined,
                      label: 'profile.email'.tr(),
                      value: viewModel.displayEmail.isEmpty
                          ? 'profile.fallbacks.unavailable'.tr()
                          : viewModel.displayEmail,
                      isEmpty: viewModel.userEmail.trim().isEmpty,
                      forceLtr: true,
                      trailing: const Icon(
                        Icons.lock_outline_rounded,
                        size: 17,
                        color: Colors.grey,
                      ),
                    ),

                    const SizedBox(height: 28),

                    _SectionTitle(
                      title: 'profile.medical_readiness'.tr(),
                      subtitle: 'profile.medical_desc'.tr(),
                    ),
                    const SizedBox(height: 10),

                    _MedicalRecordCard(viewModel: viewModel)
                        .animate()
                        .fadeIn(delay: 250.ms)
                        .slideX(begin: 0.08, end: 0),

                    const SizedBox(height: 12),

                    _EmergencyContactsCard(viewModel: viewModel)
                        .animate()
                        .fadeIn(delay: 320.ms)
                        .slideX(begin: 0.08, end: 0),

                    const SizedBox(height: 18),

                    if (!viewModel.isMedicalProfileComplete)
                      _HintCard(
                        icon: Icons.info_outline_rounded,
                        color: Colors.orange,
                        message: 'profile.hints.medical'.tr(),
                      ).animate().fadeIn(delay: 400.ms),

                    if (!viewModel.hasEmergencyContacts) ...[
                      const SizedBox(height: 12),
                      _HintCard(
                        icon: Icons.people_alt_outlined,
                        color: AppColors.primaryRed,
                        message: 'profile.hints.contacts'.tr(),
                      ).animate().fadeIn(delay: 460.ms),
                    ],

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  void _showEditBottomSheet(BuildContext context, ProfileViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _EditProfileSheet(viewModel: viewModel, parentContext: context);
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.viewModel});

  final ProfileViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final statusColor = viewModel.medicalStatusColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withAlpha(10),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: AlignmentDirectional.bottomEnd,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primaryRed],
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withAlpha(45),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    viewModel.initials,
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Icon(
                  viewModel.isMedicalProfileComplete
                      ? Icons.verified_rounded
                      : Icons.health_and_safety_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 15),
          Text(
            viewModel.displayName.isEmpty
                ? 'profile.fallbacks.user'.tr()
                : viewModel.displayName,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textBlack,
            ),
          ).animate().fadeIn(delay: 170.ms),
          const SizedBox(height: 4),
          Text(
            viewModel.accountStatusText.tr(),
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: statusColor,
              fontWeight: FontWeight.w800,
            ),
          ).animate().fadeIn(delay: 230.ms),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: GoogleFonts.cairo(
              fontSize: 11.5,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoField extends StatelessWidget {
  const _InfoField({
    required this.icon,
    required this.label,
    required this.value,
    this.isEmpty = false,
    this.trailing,
    this.forceLtr = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isEmpty;
  final Widget? trailing;
  final bool forceLtr;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(4),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isEmpty
                ? Colors.grey.shade400
                : AppColors.primaryDark,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  textDirection: forceLtr ? ui.TextDirection.ltr : null,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: isEmpty ? FontWeight.w600 : FontWeight.w900,
                    color: isEmpty ? Colors.grey.shade400 : AppColors.textBlack,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

class _MedicalRecordCard extends StatelessWidget {
  const _MedicalRecordCard({required this.viewModel});

  final ProfileViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isReady = viewModel.isMedicalProfileComplete;
    final color = isReady ? Colors.green : AppColors.primaryRed;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        HapticFeedback.selectionClick();

        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MedicalRecordScreen()),
        );

        if (context.mounted) {
          await viewModel.refreshProfileData();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withAlpha(45), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(14),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: color.withAlpha(18),
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  Icon(
                        isReady
                            ? Icons.verified_user_rounded
                            : Icons.health_and_safety_rounded,
                        color: color,
                        size: 29,
                      )
                      .animate(
                        onPlay: (controller) {
                          controller.repeat(reverse: true);
                        },
                      )
                      .scaleXY(begin: 1, end: 1.12, duration: 850.ms),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    viewModel.medicalStatusTitle.tr(),
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    viewModel.medicalStatusSubtitle.tr(),
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
              child: Transform.scale(
                scaleX:
                    !isReady &&
                        Directionality.of(context) == ui.TextDirection.rtl
                    ? -1
                    : 1,
                child: Icon(
                  isReady
                      ? Icons.edit_note_rounded
                      : Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyContactsCard extends StatelessWidget {
  const _EmergencyContactsCard({required this.viewModel});

  final ProfileViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isReady = viewModel.hasEmergencyContacts;
    final color = isReady ? Colors.green : Colors.orange;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        HapticFeedback.selectionClick();

        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ContactsScreen()),
        );

        if (context.mounted) {
          await viewModel.refreshProfileData();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withAlpha(45), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(12),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: color.withAlpha(18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isReady
                    ? Icons.people_alt_rounded
                    : Icons.person_add_alt_1_rounded,
                color: color,
                size: 29,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    viewModel.contactsStatusTitle.tr(),
                    style: GoogleFonts.cairo(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    viewModel.contactsStatusSubtitle.tr(),
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
              child: Transform.scale(
                scaleX:
                    !isReady &&
                        Directionality.of(context) == ui.TextDirection.rtl
                    ? -1
                    : 1,
                child: Icon(
                  isReady
                      ? Icons.edit_note_rounded
                      : Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withAlpha(14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: color == Colors.orange
                    ? Colors.orange.shade900
                    : AppColors.primaryDark,
                fontWeight: FontWeight.w800,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends StatelessWidget {
  const _EditProfileSheet({
    required this.viewModel,
    required this.parentContext,
  });

  final ProfileViewModel viewModel;
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        final height = MediaQuery.sizeOf(context).height;

        return AnimatedPadding(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: height * 0.88),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryDark.withAlpha(14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.manage_accounts_rounded,
                                color: AppColors.primaryDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'profile.edit_sheet.title'.tr(),
                                style: GoogleFonts.cairo(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'profile.edit_sheet.desc'.tr(),
                          textAlign: TextAlign.start,
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w700,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 22),

                        _EditTextField(
                          controller: viewModel.editNameCtrl,
                          label: 'profile.full_name'.tr(),
                          hint: 'profile.edit_sheet.name_hint'.tr(),
                          helper: '',
                          icon: Icons.person_rounded,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        _EditTextField(
                          controller: viewModel.editPhoneCtrl,
                          label: 'profile.phone_number'.tr(),
                          hint: 'profile.edit_sheet.phone_hint'.tr(),
                          helper: 'profile.edit_sheet.phone_helper'.tr(),
                          icon: Icons.phone_android_rounded,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+\s\-\(\)]'),
                            ),
                            LengthLimitingTextInputFormatter(18),
                          ],
                          textInputAction: TextInputAction.next,
                          forceLtr: true,
                        ),
                        const SizedBox(height: 14),
                        _EditTextField(
                          controller: viewModel.editEmailCtrl,
                          label: 'profile.email'.tr(),
                          hint: 'profile.edit_sheet.email_hint'.tr(),
                          helper: 'profile.edit_sheet.email_helper'.tr(),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          icon: Icons.email_rounded,
                          readOnly: true,
                          forceLtr: true,
                          suffixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: Colors.grey,
                          ),
                        ),

                        if (viewModel.errorMessage.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _SheetMessage(
                            message: viewModel.errorMessage.tr(),
                            color: Colors.red.shade700,
                            icon: Icons.error_outline_rounded,
                          ),
                        ],

                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton.icon(
                            onPressed: viewModel.isSaving
                                ? null
                                : () async {
                                    final success = await viewModel
                                        .saveProfileData();

                                    if (!context.mounted) return;

                                    if (!success) {
                                      ScaffoldMessenger.of(
                                        parentContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            viewModel.errorMessage.isNotEmpty
                                                ? viewModel.errorMessage.tr()
                                                : 'profile.errors.save_failed'
                                                      .tr(),
                                            style: GoogleFonts.cairo(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          backgroundColor: AppColors.primaryRed,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      return;
                                    }

                                    Navigator.pop(context);

                                    if (parentContext.mounted) {
                                      ScaffoldMessenger.of(
                                        parentContext,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'profile.messages.save_success'
                                                .tr(),
                                            style: GoogleFonts.cairo(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          backgroundColor: Colors.green,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryDark,
                              disabledBackgroundColor: AppColors.primaryDark
                                  .withAlpha(120),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: viewModel.isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.4,
                                    ),
                                  )
                                : const Icon(
                                    Icons.save_rounded,
                                    color: Colors.white,
                                  ),
                            label: Text(
                              viewModel.isSaving
                                  ? 'profile.actions.saving'.tr()
                                  : 'profile.actions.save_changes'.tr(),
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EditTextField extends StatelessWidget {
  const _EditTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.helper,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction,
    this.readOnly = false,
    this.suffixIcon,
    this.forceLtr = false,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String helper;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final bool readOnly;
  final Widget? suffixIcon;
  final bool forceLtr;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      textDirection: forceLtr ? ui.TextDirection.ltr : null,
      style: GoogleFonts.cairo(
        fontWeight: FontWeight.w800,
        color: AppColors.textBlack,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        suffixIcon: suffixIcon,
        labelStyle: GoogleFonts.cairo(
          color: Colors.grey.shade600,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        hintStyle: GoogleFonts.cairo(
          color: Colors.grey.shade400,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
        helperStyle: GoogleFonts.cairo(
          color: Colors.grey.shade600,
          fontSize: 10.8,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(
          icon,
          color: readOnly ? Colors.grey : AppColors.primaryDark.withAlpha(155),
        ),
        filled: true,
        fillColor: readOnly ? Colors.grey.shade100 : AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: AppColors.primaryDark,
            width: 1.8,
          ),
        ),
      ),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withAlpha(14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.cairo(
                color: color,
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
