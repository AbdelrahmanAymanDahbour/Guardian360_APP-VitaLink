import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../services/safe_arrival_places_service.dart';
import '../viewmodels/safe_arrival_viewmodel.dart';

class SafeArrivalScreen extends StatelessWidget {
  const SafeArrivalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SafeArrivalViewModel(),
      child: const _SafeArrivalContent(),
    );
  }
}

class _SafeArrivalContent extends StatefulWidget {
  const _SafeArrivalContent();

  @override
  State<_SafeArrivalContent> createState() => _SafeArrivalContentState();
}

class _SafeArrivalContentState extends State<_SafeArrivalContent> {
  GoogleMapController? _mapController;
  String? _lastCameraSignature;

  @override
  void dispose() {
    final controller = _mapController;
    _mapController = null;
    _lastCameraSignature = null;
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SafeArrivalViewModel>();
    final isDanger = viewModel.currentState == SafeArrivalState.danger;

    _scheduleCameraUpdateIfMapVisible(viewModel);

    return Scaffold(
      backgroundColor: _backgroundFor(viewModel.currentState),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _t('safe_arrival.title', 'الوصول الآمن'),
          style: GoogleFonts.cairo(
            color: isDanger ? Colors.white : AppColors.primaryDark,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDanger ? Colors.white : AppColors.textBlack,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _buildStateView(context, viewModel),
      ),
    );
  }

  Color _backgroundFor(SafeArrivalState state) {
    switch (state) {
      case SafeArrivalState.arrived:
        return const Color(0xFFF1FBFA);
      case SafeArrivalState.danger:
        return AppColors.primaryRed;
      case SafeArrivalState.setup:
      case SafeArrivalState.tracking:
        return AppColors.background;
    }
  }

  Widget _buildStateView(BuildContext context, SafeArrivalViewModel viewModel) {
    switch (viewModel.currentState) {
      case SafeArrivalState.setup:
        return _buildSetupView(context, viewModel);
      case SafeArrivalState.tracking:
        return _buildTrackingView(context, viewModel);
      case SafeArrivalState.arrived:
        return _buildArrivedView(context, viewModel);
      case SafeArrivalState.danger:
        return _buildDangerView(context, viewModel);
    }
  }

  // ==========================================
  // 🧭 SETUP
  // ==========================================

  Widget _buildSetupView(BuildContext context, SafeArrivalViewModel viewModel) {
    final isRestoring =
        viewModel.isInitializing || viewModel.isRestoringActiveTrip;

    return SafeArea(
      key: const ValueKey('setup'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSetupHero(),
            const SizedBox(height: 14),
            if (isRestoring) ...[
              _buildRestoringCard(),
              const SizedBox(height: 14),
            ],
            _buildMessages(viewModel),
            const SizedBox(height: 14),
            _buildDestinationCard(viewModel),
            if (viewModel.hasRoutePreview) ...[
              const SizedBox(height: 14),
              _buildRoutePreviewCard(viewModel),
              const SizedBox(height: 14),
              _buildMapCard(
                viewModel,
                title: 'مسار الرحلة',
                subtitle: 'يعرض موقعك الحالي والوجهة المحددة.',
                height: 255,
                live: false,
              ),
            ],
            const SizedBox(height: 20),
            _buildStartButton(viewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupHero() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, Color(0xFF9D111D)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withAlpha(45),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(32),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: Colors.white.withAlpha(65)),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('safe_arrival.title', 'الوصول الآمن'),
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'اختر وجهتك، وسيقوم Guardian 360 بتتبع رحلتك حتى تصل بأمان.',
                  style: GoogleFonts.cairo(
                    color: Colors.white.withAlpha(225),
                    fontWeight: FontWeight.w600,
                    fontSize: 12.4,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06, end: 0);
  }

  Widget _buildRestoringCard() {
    return _SurfaceCard(
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'جاري التحقق من الرحلات النشطة...',
              style: GoogleFonts.cairo(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationCard(SafeArrivalViewModel viewModel) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.travel_explore_rounded,
            title: 'الوجهة',
            subtitle: 'اختر الوجهة من النتائج لضمان دقة الموقع.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: viewModel.destinationController,
            textInputAction: TextInputAction.search,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w800,
              color: AppColors.textBlack,
            ),
            decoration: InputDecoration(
              hintText: 'ابحث عن جامعة، مدينة، مستشفى، أو منطقة...',
              hintStyle: GoogleFonts.cairo(
                color: Colors.grey.shade500,
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.location_on_rounded,
                color: AppColors.primaryDark,
              ),
              suffixIcon: _buildDestinationSuffix(viewModel),
              filled: true,
              fillColor: const Color(0xFFF8F9FA),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: _inputBorder(Colors.grey.shade300),
              enabledBorder: _inputBorder(Colors.grey.shade300),
              focusedBorder: _inputBorder(AppColors.primaryDark, width: 1.4),
            ),
          ),
          if (viewModel.isSearchingDestinations ||
              viewModel.isResolvingDestination ||
              viewModel.isLoadingRoutePreview) ...[
            const SizedBox(height: 12),
            _buildInlineLoading(viewModel),
          ],
          if (viewModel.hasDestinationPredictions) ...[
            const SizedBox(height: 12),
            _buildPredictions(viewModel),
          ],
          if (viewModel.hasTrustedDestination) ...[
            const SizedBox(height: 12),
            _buildSelectedDestination(viewModel),
          ],
        ],
      ),
    );
  }

  Widget _buildDestinationSuffix(SafeArrivalViewModel viewModel) {
    if (viewModel.isSearchingDestinations ||
        viewModel.isResolvingDestination ||
        viewModel.isLoadingRoutePreview) {
      return const Padding(
        padding: EdgeInsets.all(14),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (viewModel.destinationController.text.trim().isNotEmpty) {
      return IconButton(
        tooltip: 'مسح',
        onPressed: viewModel.clearSelectedDestination,
        icon: const Icon(Icons.close_rounded),
      );
    }

    return const Icon(Icons.search_rounded);
  }

  Widget _buildInlineLoading(SafeArrivalViewModel viewModel) {
    String text = 'جاري المعالجة...';

    if (viewModel.isSearchingDestinations) {
      text = 'جاري البحث عن الوجهات...';
    } else if (viewModel.isResolvingDestination) {
      text = 'جاري اعتماد الوجهة...';
    } else if (viewModel.isLoadingRoutePreview) {
      text = 'جاري تجهيز تفاصيل الرحلة...';
    }

    return Row(
      children: [
        const SizedBox(
          width: 17,
          height: 17,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.cairo(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPredictions(SafeArrivalViewModel viewModel) {
    final predictions = viewModel.destinationPredictions.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          for (var i = 0; i < predictions.length; i++) ...[
            _buildPredictionTile(viewModel, predictions[i]),
            if (i != predictions.length - 1)
              Divider(height: 1, color: Colors.grey.shade200),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.04, end: 0);
  }

  Widget _buildPredictionTile(
    SafeArrivalViewModel viewModel,
    SafeArrivalPlacePrediction prediction,
  ) {
    final title = prediction.displayTitle;
    final subtitle = prediction.displaySubtitle;

    return InkWell(
      onTap: () => viewModel.selectDestinationPrediction(prediction),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withAlpha(18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.place_rounded,
                color: AppColors.primaryDark,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      color: AppColors.textBlack,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  if (subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.cairo(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.grey,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedDestination(SafeArrivalViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFAF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF00A86B).withAlpha(75)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Color(0xFF00A86B),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewModel.selectedDestinationTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: const Color(0xFF005B3F),
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
                if (viewModel.selectedDestinationAddress.trim().isNotEmpty)
                  Text(
                    viewModel.selectedDestinationAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cairo(
                      color: const Color(0xFF007A55),
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'تحديث تفاصيل الرحلة',
            onPressed: viewModel.isLoadingRoutePreview
                ? null
                : viewModel.loadRoutePreviewForSelectedDestination,
            icon: const Icon(Icons.alt_route_rounded),
            color: const Color(0xFF005B3F),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutePreviewCard(SafeArrivalViewModel viewModel) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.alt_route_rounded,
            title: 'تفاصيل الرحلة',
            subtitle: 'سيتم تحديث الوقت والمسافة أثناء التتبع.',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.route_outlined,
                  label: 'المسافة',
                  value: viewModel.estimatedDistanceText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  icon: Icons.schedule_rounded,
                  label: 'الوقت المتوقع',
                  value: viewModel.estimatedDurationText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton(SafeArrivalViewModel viewModel) {
    final isBusy =
        viewModel.isLoading ||
        viewModel.isLoadingRoutePreview ||
        viewModel.isRestoringActiveTrip;

    final canStart = viewModel.canStartTrip;

    final canPrepareRoute =
        viewModel.hasTrustedDestination &&
        !viewModel.hasRoutePreview &&
        !isBusy;

    String label = 'ابدأ التتبع الآمن';

    if (!viewModel.hasTrustedDestination) {
      label = 'اختر وجهتك أولًا';
    } else if (viewModel.isLoadingRoutePreview) {
      label = 'جاري تجهيز تفاصيل الرحلة...';
    } else if (!viewModel.hasRoutePreview) {
      label = 'جهّز تفاصيل الرحلة';
    } else if (isBusy) {
      label = 'جاري التجهيز...';
    }

    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: canStart
            ? viewModel.startTracking
            : canPrepareRoute
            ? () => viewModel.loadRoutePreviewForSelectedDestination()
            : null,
        icon: isBusy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                canPrepareRoute ? Icons.alt_route_rounded : Icons.radar_rounded,
                color: Colors.white,
              ),
        label: Text(
          label,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w900,
            fontSize: 15.5,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          disabledBackgroundColor: Colors.grey.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: (canStart || canPrepareRoute) ? 4 : 0,
        ),
      ),
    );
  }

  // ==========================================
  // 🛰️ TRACKING
  // ==========================================

  Widget _buildTrackingView(
    BuildContext context,
    SafeArrivalViewModel viewModel,
  ) {
    return SafeArea(
      key: const ValueKey('tracking'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMessages(viewModel),
            const SizedBox(height: 12),
            _buildMapCard(
              viewModel,
              title: viewModel.isTripPaused
                  ? 'التتبع متوقف مؤقتًا'
                  : 'التتبع الحي',
              subtitle: viewModel.isTripPaused
                  ? 'يمكنك استئناف التتبع عند جاهزيتك.'
                  : 'يتم تحديث موقعك ووقت الوصول تلقائيًا.',
              height: 330,
              live: !viewModel.isTripPaused,
            ),
            const SizedBox(height: 14),
            _buildTrackingSummary(viewModel),
            const SizedBox(height: 14),
            _buildApproachCard(viewModel),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.timer_rounded,
                    label: 'الوقت المتبقي',
                    value: viewModel.dynamicEtaText,
                    large: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.social_distance_rounded,
                    label: 'المتبقي للوجهة',
                    value: viewModel.remainingDistanceText,
                    large: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.speed_rounded,
                    label: 'السرعة',
                    value: viewModel.currentSpeedText,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.gps_fixed_rounded,
                    label: 'دقة الموقع',
                    value: viewModel.currentGpsAccuracyText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildTrackingActions(viewModel),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingSummary(SafeArrivalViewModel viewModel) {
    final destination = viewModel.selectedDestinationTitle.trim().isNotEmpty
        ? viewModel.selectedDestinationTitle
        : 'الوجهة المحددة';

    return _SurfaceCard(
      child: Row(
        children: [
          viewModel.isTripPaused
              ? _StatusIconBox(
                  icon: Icons.pause_rounded,
                  color: const Color(0xFFFF8A00),
                  background: const Color(0xFFFFF4E5),
                )
              : const _PulseDot(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewModel.trackingStatusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textBlack,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'الوجهة: $destination',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    fontSize: 11.8,
                  ),
                ),
              ],
            ),
          ),
          Icon(
                viewModel.isTripPaused
                    ? Icons.pause_circle_filled_rounded
                    : Icons.satellite_alt_rounded,
                color: viewModel.isTripPaused
                    ? const Color(0xFFFF8A00)
                    : AppColors.primaryDark,
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(begin: 0.95, end: 1.12, duration: 900.ms),
        ],
      ),
    );
  }

  Widget _buildApproachCard(SafeArrivalViewModel viewModel) {
    final isInsideArrival =
        viewModel.latestTrackingUpdate?.canConfirmArrival == true;
    final isNear = viewModel.isNearDestination || isInsideArrival;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isInsideArrival
            ? const Color(0xFFE8F5E9)
            : isNear
            ? const Color(0xFFFFF8E1)
            : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isInsideArrival
              ? const Color(0xFF00A86B).withAlpha(70)
              : isNear
              ? const Color(0xFFFFB300).withAlpha(80)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatusIconBox(
            icon: isInsideArrival
                ? Icons.flag_circle_rounded
                : isNear
                ? Icons.near_me_rounded
                : Icons.route_rounded,
            color: isInsideArrival
                ? const Color(0xFF00A86B)
                : isNear
                ? const Color(0xFFFF8A00)
                : AppColors.primaryDark,
            background: Colors.white.withAlpha(180),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              viewModel.approachStatusText,
              style: GoogleFonts.cairo(
                color: isInsideArrival
                    ? const Color(0xFF006B4D)
                    : isNear
                    ? const Color(0xFF9A5B00)
                    : AppColors.textBlack,
                fontWeight: FontWeight.w900,
                fontSize: 13.2,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingActions(SafeArrivalViewModel viewModel) {
    final canFinish = viewModel.canFinishManually;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (viewModel.canResumeTrip) ...[
          Row(
            children: [
              Expanded(
                child: _PrimaryActionButton(
                  label: 'استئناف التتبع',
                  icon: Icons.play_arrow_rounded,
                  onPressed: viewModel.resumeTrip,
                  color: const Color(0xFF00A86B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SecondaryButton(
                  label: 'إلغاء الرحلة',
                  icon: Icons.close_rounded,
                  onPressed: viewModel.cancelTrip,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ] else if (viewModel.canPauseTrip) ...[
          Row(
            children: [
              Expanded(
                child: _SecondaryButton(
                  label: 'إيقاف مؤقت',
                  icon: Icons.pause_rounded,
                  onPressed: viewModel.pauseTrip,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SecondaryButton(
                  label: 'إلغاء الرحلة',
                  icon: Icons.close_rounded,
                  onPressed: viewModel.cancelTrip,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        _PrimaryActionButton(
          label: canFinish ? 'إنهاء الرحلة' : 'إنهاء عند الاقتراب',
          icon: Icons.beenhere_rounded,
          onPressed: canFinish ? viewModel.finishTripManually : null,
          color: const Color(0xFF00A86B),
        ),
      ],
    );
  }

  // ==========================================
  // ✅ ARRIVED
  // ==========================================

  Widget _buildArrivedView(
    BuildContext context,
    SafeArrivalViewModel viewModel,
  ) {
    final report =
        (viewModel.currentTrip?.report?.guardianReport ??
                viewModel.latestReport?.guardianReport ??
                '')
            .trim();

    final destination = viewModel.selectedDestinationTitle.trim().isNotEmpty
        ? viewModel.selectedDestinationTitle
        : _t('safe_arrival.route_end', 'الوجهة');

    final hasMessage =
        viewModel.errorMessage.trim().isNotEmpty ||
        viewModel.warningMessage.trim().isNotEmpty ||
        viewModel.successMessage.trim().isNotEmpty;

    return SafeArea(
      key: const ValueKey('arrived'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasMessage) ...[
              _buildMessages(viewModel),
              const SizedBox(height: 12),
            ],
            _buildArrivalHero(
              destination,
            ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.035, end: 0),
            const SizedBox(height: 14),
            _buildArrivalRouteMotionCard(viewModel, destination)
                .animate()
                .fadeIn(delay: 80.ms, duration: 300.ms)
                .slideY(begin: 0.04, end: 0),
            const SizedBox(height: 12),
            _buildArrivedTripCard(viewModel, destination)
                .animate()
                .fadeIn(delay: 160.ms, duration: 300.ms)
                .slideY(begin: 0.04, end: 0),
            if (report.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildCompactGuardianReport(report)
                  .animate()
                  .fadeIn(delay: 220.ms, duration: 300.ms)
                  .slideY(begin: 0.04, end: 0),
            ],
            const SizedBox(height: 18),
            _PrimaryActionButton(
              label: viewModel.isSharingWhatsApp
                  ? 'جاري فتح WhatsApp...'
                  : 'اختيار جهة عبر WhatsApp',
              icon: Icons.forum_rounded,
              onPressed: viewModel.isSharingWhatsApp
                  ? null
                  : viewModel.shareArrivalUpdate,
              color: const Color(0xFF00A86B),
            ).animate().fadeIn(delay: 300.ms, duration: 260.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildArrivalHero(String destination) {
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _arrivalSuccessMark()
              .animate()
              .fadeIn(duration: 240.ms)
              .scale(
                begin: const Offset(0.92, 0.92),
                end: const Offset(1, 1),
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'تم تأكيد الوصول بأمان',
              maxLines: 1,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: const Color(0xFF006B4D),
                fontWeight: FontWeight.w900,
                fontSize: 27,
                height: 1.12,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'تم الوصول إلى $destination',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              color: const Color(0xFF007A55).withAlpha(215),
              fontWeight: FontWeight.w700,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _arrivalSuccessMark() {
    return SizedBox(
      width: 78,
      height: 78,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFF00A86B).withAlpha(18),
                  shape: BoxShape.circle,
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(begin: 0.90, end: 1.08, duration: 1150.ms),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00A86B).withAlpha(80)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00A86B).withAlpha(28),
                  blurRadius: 18,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF00A86B),
              size: 36,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrivalRouteMotionCard(
    SafeArrivalViewModel viewModel,
    String destination,
  ) {
    final startLabel = _t('safe_arrival.route_start', 'نقطة الانطلاق');

    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.route_rounded,
            title: 'مسار الوصول',
            subtitle: 'حركة مستمرة داخل المسار من البداية حتى الوجهة.',
          ),
          const SizedBox(height: 16),
          Directionality(
            textDirection: ui.TextDirection.ltr,
            child: SizedBox(
              height: 66,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const endpointSize = 40.0;
                  const carSize = 28.0;
                  const startCenter = endpointSize / 2;

                  final width = constraints.maxWidth;
                  final trackLeft = startCenter + 7;
                  final trackRight = width - startCenter - 7;
                  final carMinCenter = trackLeft + 45;
                  final carMaxCenter = trackRight - 45;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: trackLeft,
                        right: width - trackRight,
                        top: 31,
                        child: Container(
                          height: 3.2,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5F3F1),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      Positioned(
                        left: trackLeft,
                        right: width - trackRight,
                        top: 31,
                        child: Container(
                          height: 3.2,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFB2DFDB), Color(0xFF00A86B)],
                            ),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _routeEndpoint(
                          icon: Icons.my_location_rounded,
                          color: AppColors.primaryDark,
                          background: const Color(0xFFF7F8F9),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _routeEndpoint(
                          icon: Icons.flag_rounded,
                          color: const Color(0xFF00A86B),
                          background: const Color(0xFFEAF8EF),
                        ),
                      ),
                      _LoopingRouteCar(
                        minCenterX: carMinCenter,
                        maxCenterX: carMaxCenter,
                        size: carSize,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _routeLabel(
                  title: startLabel,
                  subtitle: 'بداية الرحلة',
                  alignStart: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _routeLabel(
                  title: destination,
                  subtitle: 'تم الوصول',
                  alignStart: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _routeEndpoint({
    required IconData icon,
    required Color color,
    required Color background,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _routeLabel({
    required String title,
    required String subtitle,
    required bool alignStart,
  }) {
    return Column(
      crossAxisAlignment: alignStart
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignStart ? TextAlign.start : TextAlign.end,
          style: GoogleFonts.cairo(
            color: AppColors.textBlack,
            fontWeight: FontWeight.w900,
            fontSize: 12.4,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignStart ? TextAlign.start : TextAlign.end,
          style: GoogleFonts.cairo(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
            fontSize: 10.6,
          ),
        ),
      ],
    );
  }

  Widget _buildArrivedTripCard(
    SafeArrivalViewModel viewModel,
    String destination,
  ) {
    final trip = viewModel.currentTrip;
    final arrivedAt =
        trip?.arrivedAt ?? trip?.manualFinishedAt ?? trip?.effectiveEndAt;

    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.fact_check_rounded,
            title: 'ملخص الرحلة',
            subtitle: 'أهم مؤشرات الوصول بشكل موجز.',
          ),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 10) / 2;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _ArrivalInfoChip(
                      icon: Icons.access_time_rounded,
                      label: 'وقت الوصول',
                      value: _formatArrivalTime(arrivedAt),
                      color: const Color(0xFF00695C),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _ArrivalInfoChip(
                      icon: Icons.timer_outlined,
                      label: _t('safe_arrival.stat_time', 'الوقت المستغرق'),
                      value: viewModel.getTripDuration(),
                      color: AppColors.primaryDark,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _ArrivalInfoChip(
                      icon: Icons.route_outlined,
                      label: _t('safe_arrival.stat_distance', 'المسافة'),
                      value: viewModel.getTripDistance(),
                      color: const Color(0xFF00796B),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _ArrivalInfoChip(
                      icon: Icons.verified_user_outlined,
                      label: _t('safe_arrival.stat_rating', 'تقييم الأمان'),
                      value: viewModel.safetyRating,
                      color: const Color(0xFF00A86B),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompactGuardianReport(String report) {
    final normalizedReport = _normalizeReportText(report);

    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(14, 7, 14, 10),
      color: Colors.white,
      borderColor: const Color(0xFFB2DFDB).withAlpha(120),
      shadow: false,
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
          initiallyExpanded: false,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF00796B),
              size: 21,
            ),
          ),
          title: Text(
            _t('safe_arrival.ai_report_title', 'تقرير Guardian 360'),
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF00796B),
              fontSize: 14.2,
            ),
          ),
          subtitle: Text(
            'مراجعة مختصرة لحالة الرحلة والوصول.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              color: const Color(0xFF00695C),
              fontWeight: FontWeight.w600,
              fontSize: 10.8,
            ),
          ),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                normalizedReport,
                style: GoogleFonts.cairo(
                  fontSize: 12.2,
                  color: const Color(0xFF004D40),
                  height: 1.65,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatArrivalTime(DateTime? value) {
    if (value == null) return '--';

    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _normalizeReportText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }
  // ==========================================
  // 🚨 DANGER
  // ==========================================

  Widget _buildDangerView(
    BuildContext context,
    SafeArrivalViewModel viewModel,
  ) {
    return SafeArea(
      key: const ValueKey('danger'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 18),
            Icon(
                  Icons.warning_amber_rounded,
                  size: 96,
                  color: Colors.white.withAlpha(245),
                )
                .animate(onPlay: (controller) => controller.repeat())
                .shake(duration: 650.ms),
            const SizedBox(height: 18),
            Text(
              _t('safe_arrival.danger_title', 'تنبيه الوصول الآمن'),
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 27,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.errorMessage.trim().isNotEmpty
                  ? viewModel.errorMessage
                  : _t(
                      'safe_arrival.danger_subtitle',
                      'تحتاج هذه الرحلة إلى مراجعة.',
                    ),
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: Colors.white.withAlpha(220),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 22),
            _SurfaceCard(
              dangerMode: true,
              child: Column(
                children: [
                  _dangerRow(
                    icon: Icons.location_on_rounded,
                    label: 'الوجهة',
                    value: viewModel.selectedDestinationTitle.trim().isEmpty
                        ? '--'
                        : viewModel.selectedDestinationTitle,
                  ),
                  const SizedBox(height: 12),
                  _dangerRow(
                    icon: Icons.route_rounded,
                    label: 'المسافة',
                    value: viewModel.getTripDistance(),
                  ),
                  const SizedBox(height: 12),
                  _dangerRow(
                    icon: Icons.timer_rounded,
                    label: 'المدة',
                    value: viewModel.getTripDuration(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildMapCard(
              viewModel,
              title: 'آخر موقع معروف',
              subtitle: 'آخر موقع مسجل أثناء الرحلة.',
              height: 240,
              live: false,
              dangerMode: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: viewModel.cancelTrip,
              icon: const Icon(Icons.health_and_safety_rounded),
              label: Text(
                _t('safe_arrival.btn_im_safe', 'أنا بخير وإلغاء التنبيه'),
                style: GoogleFonts.cairo(
                  color: AppColors.primaryRed,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryRed,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dangerRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(width: 10),
        Text(
          '$label:',
          style: GoogleFonts.cairo(
            color: Colors.white.withAlpha(210),
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 🗺️ MAP
  // ==========================================

  Widget _buildMapCard(
    SafeArrivalViewModel viewModel, {
    required String title,
    required String subtitle,
    required double height,
    required bool live,
    bool dangerMode = false,
  }) {
    final center = viewModel.mapCenter;

    if (center == null) {
      return _SurfaceCard(
        dangerMode: dangerMode,
        child: SizedBox(
          height: height,
          child: Center(
            child: Text(
              'ستظهر الخريطة بعد تحديد الوجهة.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                color: dangerMode ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      );
    }

    return _SurfaceCard(
      padding: EdgeInsets.zero,
      dangerMode: dangerMode,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: height,
          child: Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: center,
                  zoom: live ? 15.5 : 12,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                  _scheduleCameraUpdate(viewModel, force: true);
                },
                markers: _buildMarkers(viewModel),
                polylines: _buildPolylines(viewModel, dangerMode: dangerMode),
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                compassEnabled: true,
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(238),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(16),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: live
                              ? const Color(0xFFE8F5E9)
                              : AppColors.primaryDark.withAlpha(18),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          live
                              ? Icons.online_prediction_rounded
                              : Icons.map_rounded,
                          color: live
                              ? const Color(0xFF00A86B)
                              : AppColors.primaryDark,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                color: AppColors.textBlack,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                                fontSize: 10.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (live)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A86B),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'مباشر',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Set<Marker> _buildMarkers(SafeArrivalViewModel viewModel) {
    final markers = <Marker>{};

    final origin = viewModel.routeOrigin;
    final destination = viewModel.routeDestination;
    final current = viewModel.currentLocation;

    if (origin != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('safe_arrival_origin'),
          position: origin,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: 'نقطة البداية'),
        ),
      );
    }

    if (destination != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('safe_arrival_destination'),
          position: destination,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: viewModel.selectedDestinationTitle),
        ),
      );
    }

    if (current != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('safe_arrival_current'),
          position: current,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: const InfoWindow(title: 'موقعك الحالي'),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines(
    SafeArrivalViewModel viewModel, {
    required bool dangerMode,
  }) {
    final points = viewModel.routePolylinePoints;

    if (points.length < 2) return const <Polyline>{};

    return {
      Polyline(
        polylineId: const PolylineId('safe_arrival_route'),
        points: points,
        width: 6,
        color: dangerMode ? Colors.white : AppColors.primaryDark,
        geodesic: true,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  void _scheduleCameraUpdateIfMapVisible(SafeArrivalViewModel viewModel) {
    final state = viewModel.currentState;

    final hasVisibleMap =
        state == SafeArrivalState.tracking ||
        state == SafeArrivalState.danger ||
        (state == SafeArrivalState.setup && viewModel.hasRoutePreview);

    if (!hasVisibleMap) {
      _mapController = null;
      _lastCameraSignature = null;
      return;
    }

    _scheduleCameraUpdate(viewModel);
  }

  void _scheduleCameraUpdate(
    SafeArrivalViewModel viewModel, {
    bool force = false,
  }) {
    final controller = _mapController;
    if (controller == null) return;

    final state = viewModel.currentState;

    if (state == SafeArrivalState.tracking) {
      final target = viewModel.currentLocation;
      if (target == null) return;

      final signature =
          'tracking-${target.latitude.toStringAsFixed(5)}-${target.longitude.toStringAsFixed(5)}';

      if (!force && signature == _lastCameraSignature) return;
      _lastCameraSignature = signature;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !identical(_mapController, controller)) return;

        _animateCameraSafely(
          controller,
          CameraUpdate.newCameraPosition(
            CameraPosition(target: target, zoom: 16, tilt: 30),
          ),
        );
      });
      return;
    }

    final points = viewModel.routePolylinePoints;

    if (points.length < 2) return;

    final first = points.first;
    final last = points.last;

    final signature =
        'route-${points.length}-${first.latitude.toStringAsFixed(4)}-${first.longitude.toStringAsFixed(4)}-${last.latitude.toStringAsFixed(4)}-${last.longitude.toStringAsFixed(4)}';

    if (!force && signature == _lastCameraSignature) return;
    _lastCameraSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_mapController, controller)) return;

      final bounds = _boundsFrom(points);

      _animateCameraSafely(
        controller,
        CameraUpdate.newLatLngBounds(bounds, 70),
      );
    });
  }

  void _animateCameraSafely(
    GoogleMapController controller,
    CameraUpdate update,
  ) {
    try {
      controller.animateCamera(update).catchError((Object error) {
        _handleMapCameraError(controller, error);
      });
    } catch (error) {
      _handleMapCameraError(controller, error);
    }
  }

  void _handleMapCameraError(GoogleMapController controller, Object error) {
    debugPrint('⚠️ SafeArrivalScreen: map camera update skipped - $error');

    if (!mounted) return;

    if (identical(_mapController, controller)) {
      _mapController = null;
      _lastCameraSignature = null;
    }
  }

  LatLngBounds _boundsFrom(List<LatLng> points) {
    var south = points.first.latitude;
    var north = points.first.latitude;
    var west = points.first.longitude;
    var east = points.first.longitude;

    for (final point in points) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }

    if ((north - south).abs() < 0.0001) {
      north += 0.0001;
      south -= 0.0001;
    }

    if ((east - west).abs() < 0.0001) {
      east += 0.0001;
      west -= 0.0001;
    }

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  // ==========================================
  // Shared UI
  // ==========================================

  Widget _buildMessages(SafeArrivalViewModel viewModel) {
    final items = <Widget>[];

    if (viewModel.errorMessage.trim().isNotEmpty) {
      items.add(
        _MessageBanner(
          message: viewModel.errorMessage,
          icon: Icons.error_outline_rounded,
          background: const Color(0xFFFFEBEE),
          foreground: AppColors.primaryRed,
        ),
      );
    }

    if (viewModel.warningMessage.trim().isNotEmpty) {
      items.add(
        _MessageBanner(
          message: viewModel.warningMessage,
          icon: Icons.info_outline_rounded,
          background: const Color(0xFFFFF8E1),
          foreground: const Color(0xFFB26A00),
        ),
      );
    }

    if (viewModel.successMessage.trim().isNotEmpty &&
        viewModel.errorMessage.trim().isEmpty) {
      items.add(
        _MessageBanner(
          message: viewModel.successMessage,
          icon: Icons.check_circle_outline_rounded,
          background: const Color(0xFFE8F5E9),
          foreground: const Color(0xFF007A55),
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          items[i],
          if (i != items.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  static String _t(String key, String fallback) {
    final translated = key.tr();
    return translated == key ? fallback : translated;
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool dangerMode;
  final Color? color;
  final Color? borderColor;
  final bool shadow;

  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.dangerMode = false,
    this.color,
    this.borderColor,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor =
        color ?? (dangerMode ? Colors.white.withAlpha(28) : Colors.white);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: resolvedColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              borderColor ??
              (dangerMode ? Colors.white.withAlpha(55) : Colors.grey.shade200),
        ),
        boxShadow: shadow && !dangerMode
            ? [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ]
            : const [],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primaryDark.withAlpha(18),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: AppColors.primaryDark, size: 22),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textBlack,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  fontSize: 11.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool large;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    const color = AppColors.primaryDark;

    return Container(
      padding: EdgeInsets.all(large ? 15 : 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: large ? 24 : 21),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: large ? 19 : 15,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 10.8,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrivalInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ArrivalInfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withAlpha(11),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(34)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withAlpha(18),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: GoogleFonts.cairo(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.4,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.4,
                    height: 1.2,
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

class _LoopingRouteCar extends StatefulWidget {
  final double minCenterX;
  final double maxCenterX;
  final double size;

  const _LoopingRouteCar({
    required this.minCenterX,
    required this.maxCenterX,
    required this.size,
  });

  @override
  State<_LoopingRouteCar> createState() => _LoopingRouteCarState();
}

class _LoopingRouteCarState extends State<_LoopingRouteCar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _motion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _motion = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _motion,
      builder: (context, child) {
        final travel = widget.maxCenterX - widget.minCenterX;
        final centerX = widget.minCenterX + (travel * _motion.value);
        final left = centerX - (widget.size / 2);
        final tilt = (_motion.value - 0.5) * 0.08;
        final scale = 0.97 + (_motion.value * 0.04);

        return Positioned(
          left: left,
          top: 16,
          child: Transform.rotate(
            angle: tilt,
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: _RouteCarGlyph(size: widget.size),
    );
  }
}

class _RouteCarGlyph extends StatelessWidget {
  final double size;

  const _RouteCarGlyph({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: const Offset(0, 2),
            child: Icon(
              Icons.directions_car_filled_rounded,
              color: Colors.black.withAlpha(20),
              size: size,
            ),
          ),
          Icon(
            Icons.directions_car_filled_rounded,
            color: const Color(0xFF007A55),
            size: size,
          ),
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color background;
  final Color foreground;

  const _MessageBanner({
    required this.message,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: foreground.withAlpha(40)),
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.cairo(
                color: foreground,
                fontWeight: FontWeight.w700,
                fontSize: 12.2,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0);
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 21),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
            ),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: Colors.grey.shade400,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.grey.shade800, size: 20),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: GoogleFonts.cairo(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w900,
              fontSize: 13.5,
            ),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade200,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFE8F5E9),
        shape: BoxShape.circle,
      ),
      child:
          Container(
                width: 15,
                height: 15,
                decoration: const BoxDecoration(
                  color: Color(0xFF00A86B),
                  shape: BoxShape.circle,
                ),
              )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .scaleXY(begin: 0.8, end: 1.35, duration: 850.ms),
    );
  }
}

class _StatusIconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;

  const _StatusIconBox({
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 26),
    );
  }
}
