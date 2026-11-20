import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../models/driver_license_model.dart';
import '../models/kroka_damage_zone.dart';
import '../viewmodels/kroka_viewmodel.dart';

class KrokaScreen extends StatelessWidget {
  const KrokaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => KrokaViewModel(),
      child: const _KrokaContent(),
    );
  }
}

class _KrokaContent extends StatelessWidget {
  const _KrokaContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<KrokaViewModel>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'kroka.title'.tr(),
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: viewModel.isReportSubmitted
              ? _KrokaSuccessState(viewModel: viewModel)
              : _KrokaForm(viewModel: viewModel),
        ),
      ),
    );
  }
}

class _KrokaForm extends StatelessWidget {
  const _KrokaForm({required this.viewModel});

  final KrokaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primaryDark,
            onRefresh: viewModel.refreshLocation,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ErrorBanner(viewModel: viewModel),
                  _LocationCard(viewModel: viewModel),
                  const SizedBox(height: 12),
                  _DriverLicenseVerificationCard(viewModel: viewModel),
                  const SizedBox(height: 12),
                  _DamageSelectorCard(viewModel: viewModel),
                  const SizedBox(height: 12),
                  _FaultEstimateCard(viewModel: viewModel),
                  const SizedBox(height: 12),
                  _VehiclePlatesCard(viewModel: viewModel),
                  const SizedBox(height: 12),
                  _EvidenceStatusCard(viewModel: viewModel),
                  const SizedBox(height: 12),
                  _AccidentDetailsCard(viewModel: viewModel),
                  const SizedBox(height: 12),
                  _ReviewCard(viewModel: viewModel),
                ],
              ),
            ),
          ),
        ),
        _SubmitBar(viewModel: viewModel),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.viewModel});

  final KrokaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final errorKey = viewModel.activeErrorKey;

    if (errorKey == null || errorKey.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withAlpha(18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryRed.withAlpha(70)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primaryRed,
            size: 21,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              errorKey.tr(),
              style: GoogleFonts.cairo(
                color: AppColors.primaryRed,
                fontSize: 12.3,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.05, end: 0);
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.viewModel});

  final KrokaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final hasLocation = viewModel.hasCapturedLocation;
    final locationName = viewModel.locationName?.trim();
    final hasNamedLocation = locationName != null && locationName.isNotEmpty;
    final accuracy = viewModel.locationAccuracyMeters;

    final displayLocation = hasLocation
        ? hasNamedLocation
              ? locationName
              : 'kroka.location.ready'.tr()
        : viewModel.isLocationLoading
        ? 'kroka.location.fetching'.tr()
        : 'kroka.location.unavailable'.tr();

    return _KrokaCard(
      icon: Icons.my_location_rounded,
      title: 'kroka.location.title'.tr(),
      trailing: _LocationRefreshButton(viewModel: viewModel),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _LocationStatusIcon(
            hasLocation: hasLocation,
            isLoading: viewModel.isLocationLoading,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayLocation,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: AppColors.textBlack,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    height: 1.28,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _CompactChip(
                      icon: hasLocation
                          ? Icons.gps_fixed_rounded
                          : Icons.gps_not_fixed_rounded,
                      label: hasLocation
                          ? 'kroka.location.ready'.tr()
                          : 'kroka.location.unavailable'.tr(),
                      color: hasLocation
                          ? Colors.green.shade700
                          : AppColors.primaryRed,
                    ),
                    if (hasLocation && accuracy != null)
                      _CompactChip(
                        icon: Icons.radar_rounded,
                        label: 'kroka.location.accuracy_value'.tr(
                          namedArgs: {'meters': accuracy.toStringAsFixed(0)},
                        ),
                        color: AppColors.primaryDark,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationRefreshButton extends StatelessWidget {
  const _LocationRefreshButton({required this.viewModel});

  final KrokaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isLocationLoading) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.primaryDark,
        ),
      );
    }

    return IconButton(
      tooltip: 'kroka.actions.refresh_location'.tr(),
      icon: const Icon(Icons.refresh_rounded),
      color: AppColors.primaryDark,
      onPressed: viewModel.refreshLocation,
    );
  }
}

class _LocationStatusIcon extends StatelessWidget {
  const _LocationStatusIcon({
    required this.hasLocation,
    required this.isLoading,
  });

  final bool hasLocation;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final color = hasLocation ? Colors.green.shade700 : AppColors.primaryRed;
    final icon = hasLocation
        ? Icons.location_on_rounded
        : isLoading
        ? Icons.location_searching_rounded
        : Icons.location_off_rounded;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withAlpha(16),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _DamageSelectorCard extends StatelessWidget {
  const _DamageSelectorCard({required this.viewModel});

  final KrokaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return _KrokaCard(
      icon: Icons.car_crash_rounded,
      title: 'kroka.damage.title'.tr(),
      child: Column(
        children: [
          _CleanCarDamageSelector(viewModel: viewModel),
          const SizedBox(height: 10),
          _SelectedDamageSummary(viewModel: viewModel),
        ],
      ),
    );
  }
}

class _CleanCarDamageSelector extends StatelessWidget {
  const _CleanCarDamageSelector({required this.viewModel});

  final KrokaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF7F7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.primaryDark.withAlpha(18)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _DamageZoneTile(
                    zone: KrokaDamageZone.frontLeft,
                    viewModel: viewModel,
                    icon: Icons.north_west_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DamageZoneTile(
                    zone: KrokaDamageZone.front,
                    viewModel: viewModel,
                    icon: Icons.keyboard_double_arrow_up_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DamageZoneTile(
                    zone: KrokaDamageZone.frontRight,
                    viewModel: viewModel,
                    icon: Icons.north_east_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _DamageZoneTile(
                        zone: KrokaDamageZone.leftFrontDoor,
                        viewModel: viewModel,
                        icon: Icons.chevron_left_rounded,
                        compact: true,
                      ),
                      const SizedBox(height: 8),
                      _DamageZoneTile(
                        zone: KrokaDamageZone.leftRearDoor,
                        viewModel: viewModel,
                        icon: Icons.chevron_left_rounded,
                        compact: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const _TopViewCar(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      _DamageZoneTile(
                        zone: KrokaDamageZone.rightFrontDoor,
                        viewModel: viewModel,
                        icon: Icons.chevron_right_rounded,
                        compact: true,
                      ),
                      const SizedBox(height: 8),
                      _DamageZoneTile(
                        zone: KrokaDamageZone.rightRearDoor,
                        viewModel: viewModel,
                        icon: Icons.chevron_right_rounded,
                        compact: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: _DamageZoneTile(
                    zone: KrokaDamageZone.rearLeft,
                    viewModel: viewModel,
                    icon: Icons.south_west_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DamageZoneTile(
                    zone: KrokaDamageZone.back,
                    viewModel: viewModel,
                    icon: Icons.keyboard_double_arrow_down_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _DamageZoneTile(
                    zone: KrokaDamageZone.rearRight,
                    viewModel: viewModel,
                    icon: Icons.south_east_rounded,
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

class _DamageZoneTile extends StatelessWidget {
  const _DamageZoneTile({
    required this.zone,
    required this.viewModel,
    required this.icon,
    this.compact = false,
  });

  final KrokaDamageZone zone;
  final KrokaViewModel viewModel;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isSelected = viewModel.isDamageZoneSelected(zone.id);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          viewModel.toggleDamageZone(zone.id);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOut,
          height: compact ? 54 : 50,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryDark
                  : AppColors.primaryDark.withAlpha(28),
              width: isSelected ? 1.6 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppColors.primaryDark.withAlpha(28)
                    : Colors.black.withAlpha(7),
                blurRadius: isSelected ? 12 : 7,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.primaryDark,
                size: compact ? 17 : 18,
              ),
              const SizedBox(height: 2),
              Text(
                zone.labelKey.tr(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  color: isSelected ? Colors.white : AppColors.textBlack,
                  fontSize: compact ? 9.2 : 9.6,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopViewCar extends StatelessWidget {
  const _TopViewCar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 82,
      height: 126,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(left: 5, top: 25, child: _CarWheel()),
          Positioned(left: 5, bottom: 25, child: _CarWheel()),
          Positioned(right: 5, top: 25, child: _CarWheel()),
          Positioned(right: 5, bottom: 25, child: _CarWheel()),
          Container(
            width: 58,
            height: 116,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaryDark.withAlpha(225),
                  AppColors.primaryRed.withAlpha(215),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withAlpha(30),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 12,
                  left: 14,
                  right: 14,
                  child: Container(
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(70),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 14,
                  right: 14,
                  child: Container(
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    Icons.directions_car_filled_rounded,
                    color: Colors.white.withAlpha(235),
                    size: 30,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CarWheel extends StatelessWidget {
  const _CarWheel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(105),
        borderRadius: BorderRadius.circular(9),
      ),
    );
  }
}

class _SelectedDamageSummary extends StatelessWidget {
  const _SelectedDamageSummary({required this.viewModel});

  final KrokaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final selectedZones = viewModel.selectedDamageZones;
    final hasSelection = selectedZones.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: hasSelection
            ? AppColors.primaryDark.withAlpha(10)
            : AppColors.primaryDark.withAlpha(7),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: hasSelection
              ? AppColors.primaryDark.withAlpha(38)
              : AppColors.primaryDark.withAlpha(20),
        ),
      ),
      child: hasSelection
          ? Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primaryDark,
                  size: 17,
                ),
                ...selectedZones.map(
                  (zone) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withAlpha(14),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primaryDark.withAlpha(55),
                      ),
                    ),
                    child: Text(
                      zone.labelKey.tr(),
                      style: GoogleFonts.cairo(
                        color: AppColors.primaryDark,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  color: AppColors.textGrey,
                  size: 19,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'kroka.damage.not_selected'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      color: AppColors.textGrey,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _FaultEstimateCard extends StatelessWidget {
  const _FaultEstimateCard({required this.viewModel});

  final KrokaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return _KrokaCard(
      icon: Icons.balance_rounded,
      title: 'kroka.fault.title'.tr(),
      child: Row(
        children: [
          _FaultChip(
            id: 'me',
            label: 'kroka.fault.me'.tr(),
            icon: Icons.person_rounded,
            color: Colors.orange.shade700,
            viewModel: viewModel,
          ),
          const SizedBox(width: 8),
          _FaultChip(
            id: 'other',
            label: 'kroka.fault.other'.tr(),
            icon: Icons.group_rounded,
            color: AppColors.primaryRed,
            viewModel: viewModel,
          ),
          const SizedBox(width: 8),
          _FaultChip(
            id: 'unknown',
            label: 'kroka.fault.unknown'.tr(),
            icon: Icons.help_outline_rounded,
            color: Colors.blue.shade700,
            viewModel: viewModel,
          ),
        ],
      ),
    );
  }
}

class _FaultChip extends StatelessWidget {
  const _FaultChip({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.viewModel,
  });

  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final KrokaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final isSelected = viewModel.faultStatus == id;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            viewModel.selectFaultStatus(id);
          },
          borderRadius: BorderRadius.circular(15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 5),
            decoration: BoxDecoration(
              color: isSelected ? color.withAlpha(20) : Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isSelected ? color : AppColors.primaryDark.withAlpha(24),
                width: isSelected ? 1.4 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  color: isSelected ? color : AppColors.textGrey,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 10.6,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                    color: isSelected ? color : AppColors.textBlack,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VehiclePlatesCard extends StatelessWidget {
  const _VehiclePlatesCard({required this.viewModel});

  final KrokaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return _KrokaCard(
      icon: Icons.confirmation_number_rounded,
      title: 'kroka.vehicles.title'.tr(),
      child: Column(
        children: [
          _JordanPlateInput(
            label: 'kroka.vehicles.mine'.tr(),
            requiredLabel: 'kroka.vehicles.required'.tr(),
            codeController: viewModel.myCarCodeController,
            numberController: viewModel.myCarNumController,
            isScanning: viewModel.isPlateScanning,
            hasOcrValue: viewModel.hasMyPlateOcrScan,
            ocrBadgeLabel: viewModel.myPlateOcrSourceLabelKey.tr(),
            onScanPlate: viewModel.canScanPlate
                ? () async {
                    await _handlePlateScan(context, isMineVehicle: true);
                  }
                : null,
          ),
          const SizedBox(height: 12),
          _JordanPlateInput(
            label: 'kroka.vehicles.other'.tr(),
            requiredLabel: 'kroka.vehicles.optional'.tr(),
            codeController: viewModel.otherCarCodeController,
            numberController: viewModel.otherCarNumController,
            isScanning: viewModel.isPlateScanning,
            hasOcrValue: viewModel.hasOtherPlateOcrScan,
            ocrBadgeLabel: viewModel.otherPlateOcrSourceLabelKey.tr(),
            onScanPlate: viewModel.canScanPlate
                ? () async {
                    await _handlePlateScan(context, isMineVehicle: false);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _handlePlateScan(
    BuildContext context, {
    required bool isMineVehicle,
  }) async {
    HapticFeedback.selectionClick();

    final selectedSource = await _showPlateScanSourceSheet(context);

    if (selectedSource == null || !context.mounted) return;

    HapticFeedback.lightImpact();

    if (selectedSource == _PlateScanSourceChoice.camera) {
      if (isMineVehicle) {
        await viewModel.scanMyVehiclePlateFromCamera();
      } else {
        await viewModel.scanOtherVehiclePlateFromCamera();
      }
      return;
    }

    if (isMineVehicle) {
      await viewModel.scanMyVehiclePlateFromGallery();
    } else {
      await viewModel.scanOtherVehiclePlateFromGallery();
    }
  }

  Future<_PlateScanSourceChoice?> _showPlateScanSourceSheet(
    BuildContext context,
  ) {
    return showModalBottomSheet<_PlateScanSourceChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(24),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withAlpha(16),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.document_scanner_rounded,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'kroka.vehicles.scan_source_title'.tr(),
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textBlack,
                            ),
                          ),
                          Text(
                            'kroka.vehicles.scan_source_subtitle'.tr(),
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textGrey,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _PlateScanSourceTile(
                  icon: Icons.photo_camera_rounded,
                  title: 'kroka.vehicles.scan_from_camera'.tr(),
                  subtitle: 'kroka.vehicles.scan_from_camera_hint'.tr(),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _PlateScanSourceChoice.camera,
                  ),
                ),
                const SizedBox(height: 10),
                _PlateScanSourceTile(
                  icon: Icons.photo_library_rounded,
                  title: 'kroka.vehicles.scan_from_gallery'.tr(),
                  subtitle: 'kroka.vehicles.scan_from_gallery_hint'.tr(),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _PlateScanSourceChoice.gallery,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _PlateScanSourceChoice { camera, gallery }

class _DriverLicenseVerificationCard extends StatelessWidget {
  const _DriverLicenseVerificationCard({required this.viewModel});

  final KrokaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final license = viewModel.myDriverLicense;
    final statusColor = _statusColor(license);
    final statusText = _statusText(license);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: viewModel.canScanDriverLicense
            ? () {
                HapticFeedback.selectionClick();
                _showDriverLicenseSheet(context);
              }
            : null,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.black.withAlpha(10)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              _DriverLicenseIcon(color: AppColors.primaryDark, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'kroka.license.title'.tr(),
                      softWrap: true,
                      style: GoogleFonts.cairo(
                        color: AppColors.primaryDark,
                        fontSize: 15.2,
                        fontWeight: FontWeight.w900,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            statusText,
                            softWrap: true,
                            style: GoogleFonts.cairo(
                              color: statusColor,
                              fontSize: 11.4,
                              fontWeight: FontWeight.w900,
                              height: 1.18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withAlpha(10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primaryDark,
                  size: 23,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDriverLicenseSheet(BuildContext context) {
    final license = viewModel.myDriverLicense;
    final statusColor = _statusColor(license);
    final hasPendingReview =
        license?.status == DriverLicenseVerificationStatus.pendingReview;

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(24),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _DriverLicenseIcon(color: AppColors.primaryDark, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'kroka.license.sheet_title'.tr(),
                            softWrap: true,
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textBlack,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            'kroka.license.sheet_subtitle'.tr(),
                            softWrap: true,
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textGrey,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _TinyStatusBadge(
                      label: _statusText(license),
                      color: statusColor,
                    ),
                  ],
                ),
                if (license?.hasUsefulData == true) ...[
                  const SizedBox(height: 12),
                  _DriverLicensePreview(license: license!),
                ],
                const SizedBox(height: 16),
                _PlateScanSourceTile(
                  icon: Icons.photo_camera_rounded,
                  title: 'kroka.license.scan_camera'.tr(),
                  subtitle: 'kroka.license.scan_camera_hint'.tr(),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await Future<void>.delayed(
                      const Duration(milliseconds: 120),
                    );
                    if (!context.mounted) return;
                    HapticFeedback.lightImpact();
                    await viewModel.scanMyDriverLicenseFromCamera();
                  },
                ),
                const SizedBox(height: 10),
                _PlateScanSourceTile(
                  icon: Icons.photo_library_rounded,
                  title: 'kroka.license.scan_gallery'.tr(),
                  subtitle: 'kroka.license.scan_gallery_hint'.tr(),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await Future<void>.delayed(
                      const Duration(milliseconds: 120),
                    );
                    if (!context.mounted) return;
                    HapticFeedback.lightImpact();
                    await viewModel.scanMyDriverLicenseFromGallery();
                  },
                ),
                if (hasPendingReview) ...[
                  const SizedBox(height: 10),
                  _PlateScanSourceTile(
                    icon: Icons.verified_rounded,
                    title: 'kroka.license.confirm'.tr(),
                    subtitle: 'kroka.license.confirm_hint'.tr(),
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await Future<void>.delayed(
                        const Duration(milliseconds: 120),
                      );
                      if (!context.mounted) return;
                      HapticFeedback.selectionClick();
                      await viewModel.confirmMyDriverLicense();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _statusColor(DriverLicenseModel? license) {
    switch (license?.status) {
      case DriverLicenseVerificationStatus.verified:
        return Colors.green.shade700;
      case DriverLicenseVerificationStatus.pendingReview:
        return AppColors.primaryDark;
      case DriverLicenseVerificationStatus.skipped:
      case DriverLicenseVerificationStatus.refused:
      default:
        return AppColors.primaryRed;
    }
  }

  String _statusText(DriverLicenseModel? license) {
    switch (license?.status) {
      case DriverLicenseVerificationStatus.verified:
        return 'kroka.license.status.verified'.tr();
      case DriverLicenseVerificationStatus.pendingReview:
        return 'kroka.license.status.pending_review'.tr();
      case DriverLicenseVerificationStatus.skipped:
      case DriverLicenseVerificationStatus.refused:
      default:
        return 'kroka.license.status.not_provided'.tr();
    }
  }
}

class _DriverLicenseIcon extends StatelessWidget {
  const _DriverLicenseIcon({required this.color, this.size = 50});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cardWidth = size * 0.62;
    final cardHeight = size * 0.44;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(size * 0.34),
        border: Border.all(color: color.withAlpha(42)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: cardWidth,
            height: cardHeight,
            padding: EdgeInsets.symmetric(
              horizontal: size * 0.065,
              vertical: size * 0.055,
            ),
            decoration: BoxDecoration(
              color: color.withAlpha(18),
              borderRadius: BorderRadius.circular(size * 0.105),
              border: Border.all(color: color.withAlpha(92), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  width: size * 0.16,
                  height: size * 0.16,
                  decoration: BoxDecoration(
                    color: color.withAlpha(88),
                    borderRadius: BorderRadius.circular(size * 0.045),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: size * 0.115,
                  ),
                ),
                SizedBox(width: size * 0.055),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LicenseIconLine(
                        widthFactor: 1,
                        height: size * 0.026,
                        color: color,
                      ),
                      SizedBox(height: size * 0.035),
                      _LicenseIconLine(
                        widthFactor: 0.72,
                        height: size * 0.026,
                        color: color,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          PositionedDirectional(
            end: size * 0.14,
            bottom: size * 0.17,
            child: Container(
              width: size * 0.22,
              height: size * 0.055,
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withAlpha(210),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LicenseIconLine extends StatelessWidget {
  const _LicenseIconLine({
    required this.widthFactor,
    required this.height,
    required this.color,
  });

  final double widthFactor;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color.withAlpha(120),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class _DriverLicensePreview extends StatelessWidget {
  const _DriverLicensePreview({required this.license});

  final DriverLicenseModel license;

  @override
  Widget build(BuildContext context) {
    final values = <String>[
      if (_hasText(license.fullName)) license.fullName!.trim(),
      if (_hasText(license.licenseNumber))
        '${'kroka.license.fields.license_number'.tr()}: ${license.licenseNumber}',
      if (_hasText(license.nationalId))
        '${'kroka.license.fields.national_id'.tr()}: ${license.nationalId}',
      if (_hasText(license.licenseClass))
        '${'kroka.license.fields.license_class'.tr()}: ${license.licenseClass}',
      if (license.expiryDate != null)
        '${'kroka.license.fields.expiry_date'.tr()}: ${DateFormat('yyyy/MM/dd').format(license.expiryDate!)}',
    ];

    if (values.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        values.join('\n'),
        softWrap: true,
        style: GoogleFonts.cairo(
          color: AppColors.textBlack,
          fontSize: 11.2,
          fontWeight: FontWeight.w800,
          height: 1.35,
        ),
      ),
    );
  }

  bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}

class _TinyStatusBadge extends StatelessWidget {
  const _TinyStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withAlpha(32)),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          color: color,
          fontSize: 9.4,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }
}

class _PlateScanSourceTile extends StatelessWidget {
  const _PlateScanSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primaryDark.withAlpha(28)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withAlpha(14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.primaryDark, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 13.3,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textBlack,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textGrey,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.textGrey,
            ),
          ],
        ),
      ),
    );
  }
}

class _JordanPlateInput extends StatelessWidget {
  const _JordanPlateInput({
    required this.label,
    required this.requiredLabel,
    required this.codeController,
    required this.numberController,
    required this.isScanning,
    required this.hasOcrValue,
    required this.ocrBadgeLabel,
    required this.onScanPlate,
  });

  final String label;
  final String requiredLabel;
  final TextEditingController codeController;
  final TextEditingController numberController;
  final bool isScanning;
  final bool hasOcrValue;
  final String ocrBadgeLabel;
  final Future<void> Function()? onScanPlate;

  @override
  Widget build(BuildContext context) {
    final digitInputFormatter = FilteringTextInputFormatter.allow(
      RegExp(r'[0-9٠-٩۰-۹]'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.cairo(
                  color: AppColors.textBlack,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _SoftBadge(label: requiredLabel),
          ],
        ),
        const SizedBox(height: 7),
        Container(
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.black87, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(7),
                blurRadius: 9,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Directionality(
            textDirection: ui.TextDirection.ltr,
            child: Row(
              children: [
                Container(
                  width: 40,
                  decoration: const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: Colors.black87, width: 1.5),
                    ),
                  ),
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        'kroka.vehicles.plate_country'.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: numberController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      digitInputFormatter,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    style: GoogleFonts.cairo(
                      color: Colors.black,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'kroka.vehicles.plate_number'.tr(),
                      hintStyle: GoogleFonts.cairo(
                        color: Colors.black26,
                        fontSize: 12,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Container(width: 1.5, color: Colors.black87),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: codeController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      digitInputFormatter,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    style: GoogleFonts.cairo(
                      color: Colors.black,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'kroka.vehicles.plate_code'.tr(),
                      hintStyle: GoogleFonts.cairo(
                        color: Colors.black26,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onScanPlate,
                icon: isScanning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryDark,
                        ),
                      )
                    : const Icon(Icons.document_scanner_rounded, size: 18),
                label: Text(
                  isScanning
                      ? 'kroka.vehicles.scanning_plate'.tr()
                      : 'kroka.vehicles.scan_plate'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  disabledForegroundColor: AppColors.textGrey,
                  side: BorderSide(color: AppColors.primaryDark.withAlpha(55)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
            if (hasOcrValue) ...[
              const SizedBox(width: 8),
              _SoftBadge(label: ocrBadgeLabel),
            ],
          ],
        ),
      ],
    );
  }
}

class _AccidentDetailsCard extends StatelessWidget {
  const _AccidentDetailsCard({required this.viewModel});

  final KrokaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return _KrokaCard(
      icon: Icons.notes_rounded,
      title: 'kroka.details.title'.tr(),
      child: TextField(
        controller: viewModel.notesController,
        minLines: 2,
        maxLines: 3,
        maxLength: 500,
        style: GoogleFonts.cairo(
          color: AppColors.textBlack,
          fontSize: 13.3,
          height: 1.45,
        ),
        decoration: InputDecoration(
          counterStyle: GoogleFonts.cairo(
            color: AppColors.textGrey,
            fontSize: 10,
          ),
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: AppColors.primaryDark),
          ),
        ),
      ),
    );
  }
}

class _EvidenceStatusCard extends StatelessWidget {
  const _EvidenceStatusCard({required this.viewModel});

  final KrokaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final hasEvidence = viewModel.hasEvidence;
    final evidenceCount = viewModel.evidenceCount;
    final hasPendingSelection = viewModel.hasPendingEvidenceSelection;
    final isDraftCreating = viewModel.isDraftCreating;
    final isEvidenceBusy = viewModel.isEvidenceBusy;
    final isCaptureEnabled = viewModel.hasEvidenceCaptureSupport;

    final statusColor = hasPendingSelection
        ? AppColors.primaryDark
        : hasEvidence
        ? Colors.green.shade700
        : AppColors.primaryDark;

    final statusIcon = hasPendingSelection
        ? Icons.fact_check_rounded
        : hasEvidence
        ? Icons.verified_rounded
        : Icons.perm_media_rounded;

    final statusLabel = hasPendingSelection
        ? 'kroka.evidence.pending_title'.tr()
        : hasEvidence
        ? 'kroka.evidence.count'.tr(
            namedArgs: {'count': evidenceCount.toString()},
          )
        : 'kroka.evidence.ready_to_capture'.tr();

    final statusDescription = hasPendingSelection
        ? 'kroka.evidence.pending_description'.tr()
        : hasEvidence
        ? 'kroka.evidence.uploaded_description'.tr()
        : 'kroka.evidence.ready_description'.tr();

    final canUseEvidenceAction =
        isCaptureEnabled &&
        !isDraftCreating &&
        !isEvidenceBusy &&
        !viewModel.isSubmitting;

    return _KrokaCard(
      icon: Icons.perm_media_rounded,
      title: 'kroka.evidence.title'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withAlpha(38)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(18),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 22),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          color: AppColors.textBlack,
                          fontSize: 13.2,
                          fontWeight: FontWeight.w900,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusDescription,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          color: AppColors.textGrey,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _EvidenceQuickActionTile(
                  icon: Icons.photo_camera_rounded,
                  label: 'kroka.evidence.types.images'.tr(),
                  enabled: canUseEvidenceAction,
                  onTap: () => _handleImageEvidenceCapture(context),
                ),
                _EvidenceQuickActionTile(
                  icon: Icons.videocam_rounded,
                  label: 'kroka.evidence.types.videos'.tr(),
                  enabled: canUseEvidenceAction,
                  onTap: () => _handleVideoEvidenceCapture(context),
                ),
                _EvidenceQuickActionTile(
                  icon: Icons.mic_rounded,
                  label: 'kroka.evidence.types.audio'.tr(),
                  enabled: canUseEvidenceAction,
                  onTap: () => _handleAudioEvidenceCapture(context),
                ),
                _EvidenceQuickActionTile(
                  icon: Icons.person_pin_rounded,
                  label: 'kroka.evidence.types.witnesses'.tr(),
                  enabled: canUseEvidenceAction,
                  onTap: () => _handleWitnessEvidenceCapture(context),
                ),
              ],
            ),
          ),
          if (hasPendingSelection) ...[
            const SizedBox(height: 12),
            _PendingEvidenceSelectionCard(viewModel: viewModel),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: viewModel.canAddPendingEvidence
                  ? () async {
                      HapticFeedback.mediumImpact();
                      await viewModel.uploadPendingEvidence();
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                disabledBackgroundColor: AppColors.primaryDark.withAlpha(45),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: isEvidenceBusy
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_task_rounded, size: 20),
              label: Text(
                isEvidenceBusy
                    ? 'kroka.evidence.actions.uploading'.tr()
                    : hasPendingSelection
                    ? 'kroka.evidence.actions.add_to_report'.tr()
                    : 'kroka.evidence.actions.select_first'.tr(),
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900,
                  fontSize: 13.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withAlpha(7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.security_rounded,
                  color: AppColors.primaryDark,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'kroka.evidence.audit_hint'.tr(),
                    style: GoogleFonts.cairo(
                      color: AppColors.textGrey,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleImageEvidenceCapture(BuildContext context) async {
    final selectedSource = await _showEvidenceSourceSheet(
      context,
      includeFiles: false,
    );

    if (selectedSource == null || !context.mounted) return;

    HapticFeedback.lightImpact();

    switch (selectedSource) {
      case _EvidenceSourceChoice.camera:
        await viewModel.selectImageEvidenceFromCamera();
        break;
      case _EvidenceSourceChoice.gallery:
        await viewModel.selectImageEvidenceFromGallery();
        break;
      case _EvidenceSourceChoice.files:
        break;
    }
  }

  Future<void> _handleVideoEvidenceCapture(BuildContext context) async {
    final selectedSource = await _showEvidenceSourceSheet(
      context,
      titleKey: 'kroka.evidence.video_source_title',
      subtitleKey: 'kroka.evidence.video_source_subtitle',
    );

    if (selectedSource == null || !context.mounted) return;

    HapticFeedback.lightImpact();

    switch (selectedSource) {
      case _EvidenceSourceChoice.camera:
        await viewModel.selectVideoEvidenceFromCamera();
        break;
      case _EvidenceSourceChoice.gallery:
        await viewModel.selectVideoEvidenceFromGallery();
        break;
      case _EvidenceSourceChoice.files:
        await viewModel.selectVideoEvidenceFromFiles();
        break;
    }
  }

  Future<void> _handleAudioEvidenceCapture(BuildContext context) async {
    HapticFeedback.lightImpact();
    await viewModel.selectAudioEvidenceFromFiles();
  }

  Future<void> _handleWitnessEvidenceCapture(BuildContext context) async {
    final input = await _showWitnessStatementDialog(context);

    if (input == null || !context.mounted) return;

    HapticFeedback.lightImpact();

    await viewModel.addWitnessStatement(
      name: input.name,
      phone: input.phone,
      statement: input.statement,
    );
  }

  Future<_EvidenceSourceChoice?> _showEvidenceSourceSheet(
    BuildContext context, {
    bool includeFiles = true,
    String titleKey = 'kroka.evidence.source_title',
    String subtitleKey = 'kroka.evidence.source_subtitle',
  }) {
    return showModalBottomSheet<_EvidenceSourceChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(24),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark.withAlpha(16),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.add_a_photo_rounded,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titleKey.tr(),
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textBlack,
                            ),
                          ),
                          Text(
                            subtitleKey.tr(),
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textGrey,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _PlateScanSourceTile(
                  icon: Icons.photo_camera_rounded,
                  title: 'kroka.evidence.actions.camera'.tr(),
                  subtitle: 'kroka.evidence.actions.camera_hint'.tr(),
                  onTap: () =>
                      Navigator.pop(sheetContext, _EvidenceSourceChoice.camera),
                ),
                const SizedBox(height: 10),
                _PlateScanSourceTile(
                  icon: Icons.photo_library_rounded,
                  title: 'kroka.evidence.actions.gallery'.tr(),
                  subtitle: 'kroka.evidence.actions.gallery_hint'.tr(),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _EvidenceSourceChoice.gallery,
                  ),
                ),
                if (includeFiles) ...[
                  const SizedBox(height: 10),
                  _PlateScanSourceTile(
                    icon: Icons.attach_file_rounded,
                    title: 'kroka.evidence.actions.files'.tr(),
                    subtitle: 'kroka.evidence.actions.files_hint'.tr(),
                    onTap: () => Navigator.pop(
                      sheetContext,
                      _EvidenceSourceChoice.files,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<_WitnessInput?> _showWitnessStatementDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final statementController = TextEditingController();

    return showDialog<_WitnessInput>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'kroka.evidence.witness.title'.tr(),
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w900,
              color: AppColors.textBlack,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'kroka.evidence.witness.name'.tr(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'kroka.evidence.witness.phone'.tr(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: statementController,
                  minLines: 3,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'kroka.evidence.witness.statement'.tr(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('common.cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  _WitnessInput(
                    name: nameController.text,
                    phone: phoneController.text,
                    statement: statementController.text,
                  ),
                );
              },
              child: Text('common.save'.tr()),
            ),
          ],
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      phoneController.dispose();
      statementController.dispose();
    });
  }
}

class _PendingEvidenceSelectionCard extends StatelessWidget {
  const _PendingEvidenceSelectionCard({required this.viewModel});

  final KrokaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final fileName = viewModel.pendingEvidenceFileName;
    final size = viewModel.pendingEvidenceSizeBytes;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryDark.withAlpha(28)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withAlpha(14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: AppColors.primaryDark,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${viewModel.pendingEvidenceTypeLabelKey.tr()} • ${viewModel.pendingEvidenceSourceLabelKey.tr()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: AppColors.textBlack,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  size == null
                      ? fileName
                      : '$fileName • ${_formatEvidenceSize(size)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: AppColors.textGrey,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'kroka.evidence.actions.clear_selection'.tr(),
            onPressed: viewModel.clearPendingEvidenceSelection,
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.textGrey,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  String _formatEvidenceSize(int sizeBytes) {
    if (sizeBytes <= 0) return '0 KB';
    final kiloBytes = sizeBytes / 1024;
    if (kiloBytes < 1024) return '${kiloBytes.toStringAsFixed(0)} KB';
    final megaBytes = kiloBytes / 1024;
    return '${megaBytes.toStringAsFixed(1)} MB';
  }
}

enum _EvidenceSourceChoice { camera, gallery, files }

class _WitnessInput {
  const _WitnessInput({
    required this.name,
    required this.phone,
    required this.statement,
  });

  final String name;
  final String phone;
  final String statement;
}

class _EvidenceQuickActionTile extends StatelessWidget {
  const _EvidenceQuickActionTile({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.primaryDark : AppColors.textGrey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          width: 66,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: color.withAlpha(enabled ? 11 : 7),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withAlpha(enabled ? 42 : 22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  color: color,
                  fontSize: 9.8,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.viewModel});

  final KrokaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final review = viewModel.reviewState;

    final damageValue = review.isDamageReady
        ? review.damageLabelKey.tr()
        : 'kroka.review.not_ready'.tr();

    final faultValue = review.isFaultReady
        ? review.faultLabelKey.tr()
        : 'kroka.review.not_ready'.tr();

    final myPlateValue = review.myPlatePreview ?? 'kroka.review.not_ready'.tr();

    final otherPlateValue =
        review.otherPlatePreview ?? 'kroka.review.optional_empty'.tr();

    final locationValue = review.isLocationReady
        ? review.locationPreview.trim().isEmpty
              ? 'kroka.location.ready'.tr()
              : review.locationPreview
        : 'kroka.review.not_ready'.tr();

    final evidenceValue = review.hasEvidence
        ? 'kroka.review.evidence_count'.tr(
            namedArgs: {'count': review.evidenceCount.toString()},
          )
        : 'kroka.review.evidence_empty'.tr();

    final licenseValue = _driverLicenseReviewValue(
      myLicense: viewModel.myDriverLicense,
    );

    return _KrokaCard(
      icon: Icons.fact_check_rounded,
      title: 'kroka.review.title'.tr(),
      child: Column(
        children: [
          _ReviewRow(label: 'kroka.review.damage'.tr(), value: damageValue),
          _ReviewRow(label: 'kroka.review.fault'.tr(), value: faultValue),
          _ReviewRow(label: 'kroka.review.my_plate'.tr(), value: myPlateValue),
          _ReviewRow(
            label: 'kroka.review.other_plate'.tr(),
            value: otherPlateValue,
          ),
          _ReviewRow(label: 'kroka.review.location'.tr(), value: locationValue),
          _ReviewRow(
            label: 'kroka.review.driver_license'.tr(),
            value: licenseValue,
          ),
          _ReviewRow(label: 'kroka.review.evidence'.tr(), value: evidenceValue),
        ],
      ),
    );
  }

  String _driverLicenseReviewValue({required DriverLicenseModel? myLicense}) {
    return '${'kroka.license.my_driver'.tr()}: ${_licenseStatusLabel(myLicense)}';
  }

  String _licenseStatusLabel(DriverLicenseModel? license) {
    switch (license?.status) {
      case DriverLicenseVerificationStatus.verified:
        return 'kroka.license.status.verified'.tr();
      case DriverLicenseVerificationStatus.pendingReview:
        return 'kroka.license.status.pending_review'.tr();
      case DriverLicenseVerificationStatus.skipped:
        return 'kroka.license.status.skipped'.tr();
      case DriverLicenseVerificationStatus.refused:
        return 'kroka.license.status.refused'.tr();
      default:
        return 'kroka.license.status.not_provided'.tr();
    }
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.viewModel});

  final KrokaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(14),
            blurRadius: 18,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: viewModel.canSubmit
                ? () async {
                    HapticFeedback.mediumImpact();
                    await viewModel.submitReport();
                  }
                : null,
            icon:
                viewModel.isSubmitting ||
                    viewModel.isDraftCreating ||
                    viewModel.isPdfGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.description_rounded),
            label: Text(
              viewModel.isPdfGenerating
                  ? 'kroka.actions.generating_pdf'.tr()
                  : viewModel.isDraftCreating
                  ? 'kroka.actions.preparing_report'.tr()
                  : viewModel.isSubmitting
                  ? 'kroka.actions.submitting'.tr()
                  : 'kroka.actions.submit'.tr(),
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KrokaSuccessState extends StatelessWidget {
  const _KrokaSuccessState({required this.viewModel});

  final KrokaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final reference = viewModel.submittedReferenceCode ?? '';
    final location = viewModel.locationName?.trim();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withAlpha(20),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.shade700.withAlpha(20),
                  border: Border.all(color: Colors.green.shade700),
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 52,
                  color: Colors.green.shade700,
                ),
              ).animate().scaleXY(begin: 0.86, end: 1),
              const SizedBox(height: 18),
              Text(
                'kroka.success.title'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  color: AppColors.textBlack,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'kroka.success.subtitle'.tr(),
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  color: AppColors.textGrey,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              _SuccessInfoBlock(
                label: 'kroka.success.reference_label'.tr(),
                value: reference.isEmpty
                    ? 'kroka.signals.unavailable'.tr()
                    : reference,
                icon: Icons.tag_rounded,
              ),
              const SizedBox(height: 10),
              _SuccessInfoBlock(
                label: 'kroka.success.location_label'.tr(),
                value: location == null || location.isEmpty
                    ? 'kroka.location.ready'.tr()
                    : location,
                icon: Icons.location_on_rounded,
              ),
              const SizedBox(height: 10),
              _GeneratedPdfReportBlock(viewModel: viewModel),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.home_rounded),
                  label: Text('kroka.actions.back_home'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    textStyle: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GeneratedPdfReportBlock extends StatelessWidget {
  const _GeneratedPdfReportBlock({required this.viewModel});

  final KrokaViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final report = viewModel.generatedReport;

    if (viewModel.isPdfGenerating) {
      return _SuccessInfoBlock(
        label: 'kroka.report.pdf_status'.tr(),
        value: 'kroka.report.generating'.tr(),
        icon: Icons.picture_as_pdf_rounded,
      );
    }

    if (report == null || !report.isValid) {
      return _SuccessInfoBlock(
        label: 'kroka.report.pdf_status'.tr(),
        value: 'kroka.report.pdf_pending'.tr(),
        icon: Icons.picture_as_pdf_outlined,
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade700.withAlpha(55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.picture_as_pdf_rounded, color: Colors.green.shade800),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'kroka.report.pdf_ready'.tr(),
                  style: GoogleFonts.cairo(
                    color: Colors.green.shade900,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'kroka.report.pdf_ready_description'.tr(),
            style: GoogleFonts.cairo(
              color: AppColors.textGrey,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(report.downloadUrl);
                if (uri == null) return;

                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text('kroka.report.open_pdf'.tr()),
              style: TextButton.styleFrom(
                foregroundColor: Colors.green.shade900,
                textStyle: GoogleFonts.cairo(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessInfoBlock extends StatelessWidget {
  const _SuccessInfoBlock({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryDark.withAlpha(18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryDark, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    color: AppColors.textGrey,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: AppColors.textBlack,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KrokaCard extends StatelessWidget {
  const _KrokaCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withAlpha(10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withAlpha(12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppColors.primaryDark, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: AppColors.primaryDark,
                    fontSize: 15.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _CompactChip extends StatelessWidget {
  const _CompactChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(14),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withAlpha(35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.cairo(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryDark.withAlpha(9),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          color: AppColors.primaryDark,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.cairo(
                color: AppColors.textGrey,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.cairo(
                color: AppColors.textBlack,
                fontSize: 12.2,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
