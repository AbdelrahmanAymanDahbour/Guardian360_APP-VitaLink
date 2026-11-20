import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../viewmodels/medical_record_viewmodel.dart';

class MedicalRecordScreen extends StatelessWidget {
  const MedicalRecordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MedicalRecordViewModel(),
      child: const _MedicalRecordContent(),
    );
  }
}

class _MedicalRecordContent extends StatelessWidget {
  const _MedicalRecordContent();

  @override
  Widget build(BuildContext context) {
    final isAuthChecking = context.select((MedicalRecordViewModel vm) => vm.isAuthChecking);
    final isAuthenticated = context.select((MedicalRecordViewModel vm) => vm.isAuthenticated);
    final viewModel = context.read<MedicalRecordViewModel>();

    if (isAuthChecking) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primaryRed),
          ),
        ),
      );
    }

    if (!isAuthenticated) {
      return _LockedMedicalRecordView(viewModel: viewModel);
    }

    return _UnlockedMedicalRecordView(viewModel: viewModel);
  }
}

// ─────────────────────────────────────────────
// LOCKED SCREEN (unchanged logic)
// ─────────────────────────────────────────────

class _LockedMedicalRecordView extends StatelessWidget {
  const _LockedMedicalRecordView({required this.viewModel});

  final MedicalRecordViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          tooltip: 'medical.actions.close'.tr(),
          icon: const Icon(
            Icons.close_rounded,
            color: AppColors.textBlack,
            size: 30,
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withAlpha(18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryRed.withAlpha(35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryRed.withAlpha(18),
                        blurRadius: 30,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child:
                      const Icon(
                            Icons.fingerprint_rounded,
                            size: 82,
                            color: AppColors.primaryRed,
                          )
                          .animate(
                            onPlay: (controller) {
                              controller.repeat(reverse: true);
                            },
                          )
                          .scaleXY(
                            begin: 1,
                            end: 1.12,
                            duration: 1100.ms,
                            curve: Curves.easeInOut,
                          ),
                ),
                const SizedBox(height: 28),
                Text(
                  'medical.locked.title'.tr(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'medical.locked.body'.tr(),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    height: 1.7,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (viewModel.errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _MessageCard(
                    message: viewModel.errorMessage,
                    icon: Icons.error_outline_rounded,
                    color: Colors.red.shade700,
                    backgroundColor: Colors.red.shade50,
                  ),
                ],
                const SizedBox(height: 34),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      elevation: 5,
                      shadowColor: AppColors.primaryDark.withAlpha(60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: viewModel.authenticateUser,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: Text(
                      'medical.actions.unlock_record'.tr(),
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextButton.icon(
                  onPressed: viewModel.authenticateUser,
                  icon: const Icon(
                    Icons.fingerprint_rounded,
                    color: AppColors.primaryRed,
                  ),
                  label: Text(
                    'medical.actions.use_device_auth'.tr(),
                    style: GoogleFonts.cairo(
                      color: AppColors.primaryRed,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// UNLOCKED SCREEN
// ─────────────────────────────────────────────

class _UnlockedMedicalRecordView extends StatelessWidget {
  const _UnlockedMedicalRecordView({required this.viewModel});

  final MedicalRecordViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'medical.title'.tr(),
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w900,
              color: AppColors.textBlack,
            ),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: 'common.back'.tr(),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textBlack,
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        // AppBar action icon — responsive, centered, soft animation
        actions: [
          Selector<MedicalRecordViewModel, bool>(
            selector: (_, vm) => vm.isSaving,
            builder: (context, isSaving, child) {
              return Padding(
                padding: const EdgeInsetsDirectional.only(end: 14),
                child: Center(
                  child: Tooltip(
                    message: 'medical.actions.save_record'.tr(),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(50),
                      onTap: isSaving ? null : () => _handleSave(context, viewModel),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primaryDark.withAlpha(18),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.health_and_safety_rounded,
                            color: AppColors.primaryDark,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ).animate()
                  .fadeIn(delay: 200.ms, duration: 200.ms)
                  .scaleXY(begin: 0.96, end: 1, delay: 200.ms, duration: 200.ms);
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: Selector<MedicalRecordViewModel, bool>(
              selector: (_, vm) => vm.isSaving,
              builder: (context, isSaving, child) {
                return ElevatedButton.icon(
                  onPressed: isSaving
                      ? null
                      : () => _handleSave(context, viewModel),
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                  label: Text(
                    isSaving
                        ? 'medical.actions.saving'.tr()
                        : 'medical.actions.encrypt_and_save'.tr(),
                    style: GoogleFonts.cairo(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    disabledBackgroundColor: AppColors.primaryDark.withAlpha(120),
                    elevation: 4,
                    shadowColor: AppColors.primaryDark.withAlpha(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const _SecurityBanner(),
                  _CompletionCard(viewModel: viewModel),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // PART 7 — Staggered section entrance (delay per section)
                  _MedicalSection(
                    title: 'medical.sections.basic.title'.tr(),
                    subtitle: 'medical.sections.basic.subtitle'.tr(),
                    icon: Icons.assignment_ind_rounded,
                    entranceDelay: 60,
                    children: [
                      _MedicalTextField(
                        label: 'medical.fields.full_name.label'.tr(),
                        hint: 'medical.fields.full_name.hint'.tr(),
                        helper: 'medical.fields.full_name.helper'.tr(),
                        controller: viewModel.nameController,
                        icon: Icons.person_rounded,
                        textInputAction: TextInputAction.next,
                      ),
                      _MedicalTextField(
                        label: 'medical.fields.national_id.label'.tr(),
                        hint: 'medical.fields.national_id.hint'.tr(),
                        helper: 'medical.fields.national_id.helper'.tr(),
                        controller: viewModel.nationalIdController,
                        icon: Icons.badge_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textInputAction: TextInputAction.next,
                      ),
                      _DateOfBirthField(viewModel: viewModel),
                      Selector<MedicalRecordViewModel, bool>(
                        selector: (_, vm) => vm.hasDateOfBirth,
                        builder: (context, hasDateOfBirth, child) {
                          return _ResponsivePair(
                            first: _MedicalTextField(
                              label: 'medical.fields.age.label'.tr(),
                              hint: hasDateOfBirth
                                  ? 'medical.fields.age.auto_hint'.tr()
                                  : 'medical.fields.age.hint'.tr(),
                              helper: hasDateOfBirth
                                  ? 'medical.fields.age.auto_helper'.tr()
                                  : 'medical.fields.age.helper'.tr(),
                              controller: viewModel.ageController,
                              icon: Icons.cake_rounded,
                              keyboardType: TextInputType.number,
                              readOnly: hasDateOfBirth,
                              // ultraCompact — age is a short numeric field
                              ultraCompact: true,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              textInputAction: TextInputAction.next,
                            ),
                            second: _MedicalTextField(
                              label: 'medical.fields.address.label'.tr(),
                              hint: 'medical.fields.address.hint'.tr(),
                              helper: 'medical.fields.address.helper'.tr(),
                              controller: viewModel.addressController,
                              icon: Icons.home_rounded,
                              // ultraCompact — address is a short-value field
                              ultraCompact: true,
                              textInputAction: TextInputAction.next,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _MedicalSection(
                    title: 'medical.sections.vitals.title'.tr(),
                    subtitle: 'medical.sections.vitals.subtitle'.tr(),
                    icon: Icons.monitor_heart_rounded,
                    entranceDelay: 120,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _MedicalTextField(
                              label: 'medical.fields.weight.label'.tr(),
                              hint: 'medical.fields.weight.hint'.tr(),
                              helper: 'medical.fields.weight.helper'.tr(),
                              suffixText: 'medical.fields.weight.suffix'.tr(),
                              controller: viewModel.weightController,
                              icon: Icons.monitor_weight_rounded,
                              // ultraCompact — weight is a short numeric field
                              ultraCompact: true,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'),
                                ),
                              ],
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MedicalTextField(
                              label: 'medical.fields.height.label'.tr(),
                              hint: 'medical.fields.height.hint'.tr(),
                              helper: 'medical.fields.height.helper'.tr(),
                              suffixText: 'medical.fields.height.suffix'.tr(),
                              controller: viewModel.heightController,
                              icon: Icons.height_rounded,
                              // ultraCompact — height is a short numeric field
                              ultraCompact: true,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'),
                                ),
                              ],
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                        ],
                      ),
                      _BloodTypePicker(viewModel: viewModel),
                      _GenderSelector(viewModel: viewModel),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // PART 8 — Critical section visual emphasis preserved
                  _MedicalSection(
                    title: 'medical.sections.critical.title'.tr(),
                    subtitle: 'medical.sections.critical.subtitle'.tr(),
                    icon: Icons.medical_services_outlined,
                    isCritical: true,
                    entranceDelay: 180,
                    children: [
                      _MedicalTextField(
                        label: 'medical.fields.allergies.label'.tr(),
                        hint: 'medical.fields.allergies.hint'.tr(),
                        helper: 'medical.fields.allergies.helper'.tr(),
                        controller: viewModel.allergiesController,
                        icon: Icons.warning_amber_rounded,
                        isCritical: true,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.newline,
                      ),
                      _MedicalTextField(
                        label: 'medical.fields.medications.label'.tr(),
                        hint: 'medical.fields.medications.hint'.tr(),
                        helper: 'medical.fields.medications.helper'.tr(),
                        controller: viewModel.medicationsController,
                        icon: Icons.medication_rounded,
                        isCritical: true,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.newline,
                      ),
                      _MedicalTextField(
                        label: 'medical.fields.chronic_diseases.label'.tr(),
                        hint: 'medical.fields.chronic_diseases.hint'.tr(),
                        helper: 'medical.fields.chronic_diseases.helper'.tr(),
                        controller: viewModel.diseasesController,
                        icon: Icons.healing_rounded,
                        isCritical: true,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.newline,
                      ),
                      _MedicalTextField(
                        label: 'medical.fields.notes.label'.tr(),
                        hint: 'medical.fields.notes.hint'.tr(),
                        helper: 'medical.fields.notes.helper'.tr(),
                        controller: viewModel.notesController,
                        icon: Icons.notes_rounded,
                        minLines: 2,
                        maxLines: 4,
                        // PART 2 — prevent hint truncation on multi-line notes field
                        hintMaxLinesOverride: 4,
                        textInputAction: TextInputAction.newline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _OrganDonorCard(viewModel: viewModel),
                  const SizedBox(height: 16),
                  Selector<MedicalRecordViewModel, String>(
                    selector: (_, vm) => vm.errorMessage,
                    builder: (context, errorMessage, child) {
                      if (errorMessage.isEmpty) return const SizedBox.shrink();
                      return _MessageCard(
                        message: errorMessage,
                        icon: Icons.error_outline_rounded,
                        color: Colors.red.shade700,
                        backgroundColor: Colors.red.shade50,
                      );
                    },
                  ),
                  Selector<MedicalRecordViewModel, String>(
                    selector: (_, vm) => vm.successMessage,
                    builder: (context, successMessage, child) {
                      if (successMessage.isEmpty) return const SizedBox.shrink();
                      return _MessageCard(
                        message: successMessage,
                        icon: Icons.check_circle_outline_rounded,
                        color: Colors.green.shade700,
                        backgroundColor: Colors.green.shade50,
                      );
                    },
                  ),
                  const SizedBox(height: 86),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSave(
    BuildContext context,
    MedicalRecordViewModel viewModel,
  ) async {
    final success = await viewModel.saveData();

    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'medical.messages.save_success'.tr(),
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.maybePop(context);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          viewModel.errorMessage.isNotEmpty
              ? viewModel.errorMessage
              : 'medical.errors.save_failed'.tr(),
          style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SECURITY BANNER
// ─────────────────────────────────────────────

class _SecurityBanner extends StatelessWidget {
  const _SecurityBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF0FBF0),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
      child: Row(
        children: [
          Icon(
            Icons.verified_user_rounded,
            size: 17,
            color: Colors.green.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'medical.security.banner'.tr(),
              style: GoogleFonts.cairo(
                fontSize: 11,
                color: Colors.green.shade800,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// COMPLETION CARD
// ─────────────────────────────────────────────

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.viewModel});

  final MedicalRecordViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final percentage =
        context.select((MedicalRecordViewModel vm) => vm.completionPercentage).clamp(0.0, 1.0);
    final isEmergencyReady =
        context.select((MedicalRecordViewModel vm) => vm.isMedicalReadyForEmergency);
    final percentText = '${(percentage * 100).round()}%';
    final progressColor = isEmergencyReady ? Colors.green : AppColors.primaryDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: progressColor.withAlpha(16),
                child: Icon(
                  isEmergencyReady
                      ? Icons.health_and_safety_rounded
                      : Icons.info_outline_rounded,
                  color: progressColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isEmergencyReady
                      ? 'medical.completion.ready_title'.tr()
                      : 'medical.completion.required_title'.tr(),
                  style: GoogleFonts.cairo(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              Text(
                percentText,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey.shade100,
              color: progressColor,
              minHeight: 7,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isEmergencyReady
                ? 'medical.completion.ready_body'.tr()
                : 'medical.completion.required_body'.tr(),
            style: GoogleFonts.cairo(
              fontSize: 11,
              height: 1.4,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MEDICAL SECTION  (PART 7 stagger + PART 8 critical)
// ─────────────────────────────────────────────

class _MedicalSection extends StatelessWidget {
  const _MedicalSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
    this.isCritical = false,
    this.entranceDelay = 0,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;
  final bool isCritical;
  final int entranceDelay; // ms stagger delay

  @override
  Widget build(BuildContext context) {
    // PART 1 — Critical section uses primaryDark for full Guardian identity alignment
    final iconBg = AppColors.primaryDark.withAlpha(isCritical ? 20 : 16);
    const iconColor = AppColors.primaryDark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCritical
              ? AppColors.primaryDark.withAlpha(22)
              : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // PART 3 — one-time subtle entrance animation on critical icon capsule only
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              )
                  .animate()
                  .fadeIn(
                    delay: (entranceDelay + (isCritical ? 80 : 0)).ms,
                    duration: 260.ms,
                  )
                  .scaleXY(
                    begin: 0.88,
                    end: 1,
                    delay: (entranceDelay + (isCritical ? 80 : 0)).ms,
                    duration: 260.ms,
                    curve: Curves.easeOutCubic,
                  ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.cairo(
                        fontSize: isCritical ? 16 : 15.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        height: 1.35,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    )
        .animate()
        .fadeIn(delay: entranceDelay.ms, duration: 260.ms)
        .slideY(begin: 0.05, end: 0, delay: entranceDelay.ms, duration: 260.ms);
  }
}

// ─────────────────────────────────────────────
// RESPONSIVE PAIR
// ─────────────────────────────────────────────

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return Column(children: [first, second]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: 12),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// MEDICAL TEXT FIELD  (PART 1 compact flag)
// ─────────────────────────────────────────────

class _MedicalTextField extends StatefulWidget {
  const _MedicalTextField({
    required this.label,
    required this.hint,
    required this.helper,
    required this.controller,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction,
    this.suffixText,
    this.minLines = 1,
    this.maxLines = 1,
    this.isCritical = false,
    this.readOnly = false,
    // ignore: unused_element_parameter — kept for forward-compatibility; callers use ultraCompact
    this.compact = false,
    this.ultraCompact = false,
    this.hintMaxLinesOverride,
  });

  final String label;
  final String hint;
  final String helper;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final String? suffixText;
  final int minLines;
  final int maxLines;
  final bool isCritical;
  final bool readOnly;
  /// Reduces vertical padding for short single-line fields.
  final bool compact;
  /// Maximum compactness: even tighter padding, smaller icon/font, no helper text.
  /// Use ONLY for weight, height, address.
  final bool ultraCompact;
  /// Override hintMaxLines for fields with long hint/placeholder text (e.g. notes).
  final int? hintMaxLinesOverride;

  @override
  State<_MedicalTextField> createState() => _MedicalTextFieldState();
}

class _MedicalTextFieldState extends State<_MedicalTextField> {
  late bool _isFilled;

  @override
  void initState() {
    super.initState();
    _isFilled = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_handleTextChange);
  }

  @override
  void didUpdateWidget(covariant _MedicalTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_handleTextChange);
      widget.controller.addListener(_handleTextChange);
      _isFilled = widget.controller.text.trim().isNotEmpty;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    super.dispose();
  }

  void _handleTextChange() {
    final currentlyFilled = widget.controller.text.trim().isNotEmpty;
    if (_isFilled != currentlyFilled) {
      setState(() {
        _isFilled = currentlyFilled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.primaryDark;
    final iconColor = _isFilled ? activeColor : Colors.grey.shade400;
    final cleanHelper = widget.helper.trim();

    // ultraCompact: maximum reduction for short single-value fields (weight/height/address)
    if (widget.ultraCompact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: TextFormField(
          controller: widget.controller,
          readOnly: widget.readOnly,
          keyboardType: widget.keyboardType,
          inputFormatters: widget.inputFormatters,
          textInputAction: widget.textInputAction,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          textAlignVertical: TextAlignVertical.center,
          style: GoogleFonts.cairo(
            color: AppColors.textBlack,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            isDense: true,
            labelText: widget.label,
            hintText: widget.hint,
            // No helper text for ultraCompact — keeps the box tight
            helperText: null,
            suffixText: widget.suffixText,
            hintMaxLines: 1,
            labelStyle: GoogleFonts.cairo(
              color: Colors.grey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
            hintStyle: GoogleFonts.cairo(
              color: Colors.grey.shade400,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
            suffixStyle: GoogleFonts.cairo(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
            prefixIcon: Icon(widget.icon, color: iconColor, size: 18),
            filled: true,
            fillColor: widget.readOnly ? Colors.grey.shade50 : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 9,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.8),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        ),
      );
    }

    // compact: slightly tighter padding for other short fields
    final verticalPad = widget.compact ? 10.0 : 13.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: TextFormField(
        controller: widget.controller,
        readOnly: widget.readOnly,
        keyboardType: widget.keyboardType,
        inputFormatters: widget.inputFormatters,
        textInputAction: widget.textInputAction,
        minLines: widget.minLines,
        maxLines: widget.maxLines,
        textAlignVertical: TextAlignVertical.center,
        style: GoogleFonts.cairo(
          color: AppColors.textBlack,
          fontWeight: FontWeight.w800,
          fontSize: 13.5,
        ),
        decoration: InputDecoration(
          isDense: true,
          labelText: widget.label,
          hintText: widget.hint,
          helperText: cleanHelper.isEmpty ? null : cleanHelper,
          suffixText: widget.suffixText,
          helperMaxLines: 3,
          hintMaxLines: widget.hintMaxLinesOverride ?? 2,
          labelStyle: GoogleFonts.cairo(
            color: Colors.grey.shade600,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
          hintStyle: GoogleFonts.cairo(
            color: Colors.grey.shade400,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          helperStyle: GoogleFonts.cairo(
            color: Colors.grey.shade500,
            fontSize: 10.5,
            height: 1.25,
            fontWeight: FontWeight.w500,
          ),
          suffixStyle: GoogleFonts.cairo(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w800,
          ),
          prefixIcon: Icon(widget.icon, color: iconColor, size: 20),
          filled: true,
          fillColor: widget.readOnly ? Colors.grey.shade50 : Colors.white,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: verticalPad,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primaryDark, width: 1.8),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DATE OF BIRTH FIELD  (PART 2)
// ─────────────────────────────────────────────

class _DateOfBirthField extends StatelessWidget {
  const _DateOfBirthField({required this.viewModel});

  final MedicalRecordViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final dateOfBirth = context.select((MedicalRecordViewModel vm) => vm.dateOfBirth);
    final hasDate = dateOfBirth != null;
    final iconColor = hasDate ? AppColors.primaryDark : Colors.grey.shade400;

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _pickDateOfBirth(context, viewModel),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: hasDate ? AppColors.primaryDark.withAlpha(8) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasDate ? AppColors.primaryDark : Colors.grey.shade200,
              width: hasDate ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_month_rounded, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'medical.fields.date_of_birth.label'.tr(),
                      style: GoogleFonts.cairo(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasDate
                          ? _formatDate(dateOfBirth)
                          : 'medical.fields.date_of_birth.hint'.tr(),
                      style: GoogleFonts.cairo(
                        color: hasDate ? AppColors.textBlack : Colors.grey.shade400,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'medical.fields.date_of_birth.helper'.tr(),
                      style: GoogleFonts.cairo(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasDate)
                GestureDetector(
                  onTap: viewModel.clearDateOfBirth,
                  child: Tooltip(
                    message: 'medical.fields.date_of_birth.clear'.tr(),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.grey.shade500),
                    ),
                  ),
                )
              else
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.grey.shade400,
                  size: 14,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDateOfBirth(
    BuildContext context,
    MedicalRecordViewModel viewModel,
  ) async {
    final now = DateTime.now();
    final initialDate =
        viewModel.dateOfBirth ?? DateTime(now.year - 20, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'medical.date_picker.help'.tr(),
      cancelText: 'common.cancel'.tr(),
      confirmText: 'common.confirm'.tr(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primaryRed),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (picked != null) {
      viewModel.setDateOfBirth(picked);
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

// ─────────────────────────────────────────────
// BLOOD TYPE PICKER FIELD  (PART 3)
// ─────────────────────────────────────────────

class _BloodTypePicker extends StatelessWidget {
  const _BloodTypePicker({required this.viewModel});

  final MedicalRecordViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final selected = context.select((MedicalRecordViewModel vm) => vm.selectedBloodType);
    final hasValue = selected != null && selected.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showBloodTypePicker(context, viewModel),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: hasValue ? AppColors.primaryDark.withAlpha(10) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasValue ? AppColors.primaryDark : Colors.grey.shade200,
              width: hasValue ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              // Small capsule icon
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: hasValue
                      ? AppColors.primaryDark.withAlpha(18)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.water_drop_rounded,
                  color: hasValue ? AppColors.primaryDark : Colors.grey.shade400,
                  size: 17,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'medical.fields.blood_type.label'.tr(),
                      style: GoogleFonts.cairo(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasValue
                          ? selected
                          : 'medical.fields.blood_type.hint'.tr(),
                      style: GoogleFonts.cairo(
                        fontSize: 13.5,
                        color: hasValue ? AppColors.primaryDark : Colors.grey.shade400,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'medical.fields.blood_type.helper'.tr(),
                      style: GoogleFonts.cairo(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: hasValue ? AppColors.primaryDark : Colors.grey.shade400,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // PART 4 — premium blood type bottom sheet with 2-column grid chips
  void _showBloodTypePicker(
    BuildContext context,
    MedicalRecordViewModel viewModel,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              // Title row
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primaryRed.withAlpha(18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.water_drop_rounded,
                      color: AppColors.primaryRed,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'medical.fields.blood_type.sheet_title'.tr(),
                    style: GoogleFonts.cairo(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // PART 4 — 2-column grid of selectable chips with staggered fade/scale
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.6,
                ),
                itemCount: viewModel.bloodTypes.length,
                itemBuilder: (context, index) {
                  final type = viewModel.bloodTypes[index];
                  final isSelected = viewModel.selectedBloodType == type;

                  return _BloodTypeChip(
                    type: type,
                    isSelected: isSelected,
                    animationDelay: (index * 40).ms,
                    onTap: () {
                      viewModel.setBloodType(type);
                      Navigator.pop(sheetContext);
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// BLOOD TYPE CHIP  (PART 4 — grid chip)
// ─────────────────────────────────────────────

class _BloodTypeChip extends StatelessWidget {
  const _BloodTypeChip({
    required this.type,
    required this.isSelected,
    required this.onTap,
    required this.animationDelay,
  });

  final String type;
  final bool isSelected;
  final VoidCallback onTap;
  final Duration animationDelay;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : Colors.grey.shade200,
            width: isSelected ? 0 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryDark.withAlpha(40),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.water_drop_rounded,
              size: 14,
              color: isSelected ? Colors.white.withAlpha(200) : Colors.grey.shade400,
            ),
            const SizedBox(width: 8),
            Text(
              type,
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : AppColors.textBlack,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_rounded, size: 14, color: Colors.white),
            ],
          ],
        ),
      ),
    )
        .animate(delay: animationDelay)
        .fadeIn(duration: 200.ms)
        .scaleXY(begin: 0.92, end: 1, duration: 200.ms, curve: Curves.easeOutBack);
  }
}

// ─────────────────────────────────────────────
// ORGAN DONOR CARD
// ─────────────────────────────────────────────

class _OrganDonorCard extends StatelessWidget {
  const _OrganDonorCard({required this.viewModel});

  final MedicalRecordViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isOrganDonor = context.select((MedicalRecordViewModel vm) => vm.isOrganDonor);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        secondary: CircleAvatar(
          backgroundColor: Colors.green.withAlpha(18),
          child: Icon(
            Icons.volunteer_activism_rounded,
            color: Colors.green.shade700,
          ),
        ),
        title: Text(
          'medical.fields.organ_donor.label'.tr(),
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w900,
            color: AppColors.primaryDark,
          ),
        ),
        subtitle: Text(
          'medical.fields.organ_donor.helper'.tr(),
          style: GoogleFonts.cairo(
            fontSize: 12,
            height: 1.45,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        value: isOrganDonor,
        activeThumbColor: Colors.white,
        activeTrackColor: Colors.green.shade600,
        onChanged: viewModel.toggleDonor,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GENDER SELECTOR  (PART 5 — segmented feel)
// ─────────────────────────────────────────────

class _GenderSelector extends StatelessWidget {
  const _GenderSelector({required this.viewModel});

  final MedicalRecordViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final selected = context.select((MedicalRecordViewModel vm) => vm.selectedGender);
    final hasValue = selected != null && selected.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasValue ? AppColors.primaryDark : Colors.grey.shade200,
            width: hasValue ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.wc_rounded,
                  color: hasValue ? AppColors.primaryDark : Colors.grey.shade400,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'medical.fields.gender.label'.tr(),
                  style: GoogleFonts.cairo(
                    color: Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            // PART 5 — Segmented-style gender chips
            Row(
              children: [
                Expanded(
                  child: _GenderChip(
                    label: 'medical.fields.gender.male'.tr(),
                    icon: Icons.male_rounded,
                    isSelected: selected == 'male',
                    onTap: () => viewModel.setGender('male'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _GenderChip(
                    label: 'medical.fields.gender.female'.tr(),
                    icon: Icons.female_rounded,
                    isSelected: selected == 'female',
                    onTap: () => viewModel.setGender('female'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// GENDER CHIP  (PART 5)
// ─────────────────────────────────────────────

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryDark : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : Colors.grey.shade200,
            width: isSelected ? 0 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryDark.withAlpha(35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade400,
              size: 17,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MESSAGE CARD
// ─────────────────────────────────────────────

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  final String message;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(45)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.cairo(
                color: color,
                fontSize: 12.5,
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
