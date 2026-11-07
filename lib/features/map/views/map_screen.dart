import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/constants/app_colors.dart';
import '../viewmodels/map_viewmodel.dart';
import '../config/marker_config.dart';
import '../models/place_model.dart';

/// ==========================================
/// 🗺️ Screen: Guardian Map (Super Ultra Pro Final)
/// ==========================================
/// الشاشة النهائية الشاملة: تتبع لحظي، حساب أزمة سير،
/// رسم أيقونات برمجياً، وتصميم UI مصفح ضد الـ Overflow.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final PageController _pageController;
  MapViewModel? _viewModel;
  String? _lastLocale;

  @override
  void initState() {
    super.initState();
    // إعداد وحدة التحكم بالكروت السفلية
    _pageController = PageController(viewportFraction: 0.88);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final viewModel = context.read<MapViewModel>();
      _viewModel = viewModel;

      // ربط التنقل بين الماركرات والكروت
      viewModel.animateToCard = _handleAnimateToCard;

      // تشغيل الرادار والموقع
      viewModel.initializeLocation(locale: context.locale.languageCode);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final locale = context.locale.languageCode;
    final previousLocale = _lastLocale;
    _lastLocale = locale;

    if (previousLocale != null && previousLocale != locale) {
      final viewModel = context.read<MapViewModel>();
      _viewModel = viewModel;
      unawaited(viewModel.refreshForLocale(locale));
    }
  }

  @override
  void dispose() {
    if (_viewModel?.animateToCard == _handleAnimateToCard) {
      _viewModel?.animateToCard = null;
    }
    _viewModel?.detachMapController();
    _viewModel?.stopLiveTracking();
    _pageController.dispose();
    super.dispose();
  }

  void _handleAnimateToCard(int index) {
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 🗺️ 1. الخريطة (مع تفعيل المرور الحي والبوصلة)
          Positioned.fill(
            child: Selector<MapViewModel, _MapLayerState>(
              selector: (_, viewModel) => _MapLayerState(
                currentPosition: viewModel.currentPosition,
                markers: viewModel.markers,
                markerRevision: viewModel.markerRevision,
                mapErrorKey: viewModel.mapErrorKey,
              ),
              builder: (context, state, _) {
                final viewModel = context.read<MapViewModel>();

                if (state.currentPosition == null) {
                  return state.mapErrorKey != null
                      ? _buildMapErrorState(state.mapErrorKey!)
                      : _buildLoadingState();
                }

                return GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: state.currentPosition!,
                    zoom: 15.5,
                  ),
                  onMapCreated: viewModel.onMapCreated,
                  markers: state.markers,
                  myLocationEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  trafficEnabled: true,
                  mapToolbarEnabled: false,
                  mapType: MapType.normal,
                );
              },
            ),
          ),

          // 🔍 2. شريط البحث العلوي (الديناميكي)
          PositionedDirectional(
            top: MediaQuery.of(context).padding.top + 15,
            start: 20,
            end: 20,
            child: Selector<MapViewModel, _MapHeaderState>(
              selector: (_, viewModel) => _MapHeaderState(
                isLoading: viewModel.isLoading,
                isLoadingPlaces: viewModel.isLoadingPlaces,
                actualAreaName: viewModel.actualAreaName,
              ),
              builder: (context, state, _) => _buildTopSearchCard(state),
            ),
          ),

          // 🎯 3. زر الموقع (بلمسة Guardian الخمرية الفخمة 🩸)
          Selector<MapViewModel, bool>(
            selector: (_, viewModel) => viewModel.nearbyPlaces.isEmpty,
            builder: (context, placesAreEmpty, _) {
              final viewModel = context.read<MapViewModel>();

              return PositionedDirectional(
                bottom: placesAreEmpty ? 40 : 160,
                end: 20,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6B0000).withOpacity(0.5),
                        blurRadius: 18,
                        spreadRadius: 4,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    heroTag: "location_btn",
                    backgroundColor: const Color(0xFF6B0000),
                    elevation: 0,
                    mini: true,
                    onPressed: viewModel.centerOnUserLocation,
                    child: const Icon(
                      Icons.gps_fixed_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ).animate().scale(delay: 500.ms, curve: Curves.easeOutBack),
              );
            },
          ),

          Selector<MapViewModel, _MapPlacesState>(
            selector: (_, viewModel) => _MapPlacesState(
              places: viewModel.nearbyPlaces,
              activeCardIndex: viewModel.activeCardIndex,
              isLoadingPlaces: viewModel.isLoadingPlaces,
              hasCurrentPosition: viewModel.currentPosition != null,
            ),
            builder: (context, state, _) {
              final viewModel = context.read<MapViewModel>();

              return Stack(
                children: [
                  if (!state.isLoadingPlaces && state.places.isNotEmpty)
                    PositionedDirectional(
                      bottom: 25,
                      start: 0,
                      end: 0,
                      child: SizedBox(
                        height: 115,
                        child:
                            PageView.builder(
                              controller: _pageController,
                              physics: const BouncingScrollPhysics(),
                              onPageChanged: viewModel.onCardSwiped,
                              itemCount: state.places.length,
                              itemBuilder: (context, index) {
                                final place = state.places[index];
                                final isActive = state.activeCardIndex == index;

                                return _buildPremiumPlaceCard(
                                  place: place,
                                  isActive: isActive,
                                  onTap: () => viewModel.openDirections(place),
                                );
                              },
                            ).animate().slideY(
                              begin: 1.0,
                              end: 0,
                              duration: 600.ms,
                              curve: Curves.easeOutCirc,
                            ),
                      ),
                    ),
                  if (!state.isLoadingPlaces &&
                      state.places.isEmpty &&
                      state.hasCurrentPosition)
                    PositionedDirectional(
                      bottom: 40,
                      start: 40,
                      end: 40,
                      child: _buildNoPlacesFound(),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // WIDGETS
  // ==========================================

  Widget _buildTopSearchCard(_MapHeaderState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.map_rounded,
              color: AppColors.primaryDark,
              size: 20,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.isLoading
                      ? context.tr('map.locating')
                      : (state.actualAreaName.isNotEmpty
                            ? state.actualAreaName
                            : context.tr('map.current_location')),
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textBlack,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  context.tr('map.current_location'),
                  style: GoogleFonts.cairo(
                    color: AppColors.textGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (state.isLoading || state.isLoadingPlaces)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primaryDark,
              ),
            ),
        ],
      ),
    ).animate().slideY(
      begin: -1.0,
      end: 0,
      duration: 700.ms,
      curve: Curves.easeOutCirc,
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (int i = 0; i < 4; i++)
              Container(
                    width: 90 + (i * 90.0),
                    height: 90 + (i * 90.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryRed.withOpacity(0.1),
                      ),
                      color: AppColors.primaryRed.withOpacity(0.02),
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat())
                  .scaleXY(
                    begin: 0.8,
                    end: 1.2,
                    duration: 2500.ms,
                    delay: (i * 400).ms,
                  )
                  .fadeOut(),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryRed.withOpacity(0.2),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: const Icon(
                Icons.my_location_rounded,
                color: AppColors.primaryRed,
                size: 35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapErrorState(String errorKey) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_off_rounded,
                  color: AppColors.primaryRed,
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.tr(errorKey),
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textBlack,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoPlacesFound() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primaryRed,
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            context.tr('map.no_places'),
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: AppColors.textBlack,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ).animate().fade().scale();
  }

  Widget _buildPremiumPlaceCard({
    required PlaceModel place,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final icon = MarkerConfig.getIcon(place.type);
    final iconColor = MarkerConfig.getCardIconColor(place.type);
    final iconBgColor = MarkerConfig.getCardIconBackgroundColor(place.type);

    return AnimatedScale(
      scale: isActive ? 1.0 : 0.92,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: isActive
              ? Border.all(color: iconColor.withOpacity(0.6), width: 2)
              : Border.all(color: Colors.transparent, width: 2),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? iconColor.withOpacity(0.2)
                  : Colors.black.withOpacity(0.03),
              blurRadius: isActive ? 15 : 8,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // 🏥 أيقونة المكان
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: iconColor, size: 28),
                  ),
                  const SizedBox(width: 16),

                  // 📝 النصوص والمعلومات
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          place.name,
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textBlack,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // ⏱️ المسافة والوقت (تصميم مصفح ضد الـ Overflow)
                            Flexible(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.route_rounded,
                                      size: 14,
                                      color: AppColors.primaryDark,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _formatPlaceDistance(context, place),
                                        style: GoogleFonts.montserrat(
                                          color: AppColors.textBlack,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow
                                            .visible, // لضمان ظهور النص كاملاً
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // 🏷️ نوع المكان
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _placeTypeLabelKey(place.type).tr(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.cairo(
                                  color: iconColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 🚀 زر التنقل (يظهر فقط للكرت الفعال)
                  if (isActive)
                    Container(
                      margin: const EdgeInsetsDirectional.only(start: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryDark,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.navigation_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ).animate().scale(delay: 200.ms, curve: Curves.easeOutBack),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatPlaceDistance(BuildContext context, PlaceModel place) {
    final duration = place.durationText?.trim() ?? '';
    final distance = place.realDistanceText?.trim() ?? '';

    if (duration.isNotEmpty && distance.isNotEmpty) {
      return '$duration • $distance';
    }

    if (duration.isNotEmpty) return duration;
    if (distance.isNotEmpty) return distance;

    final fallback = place.distanceInKm;
    if (fallback == null) return '--';

    if (fallback < 1) {
      return '${(fallback * 1000).toStringAsFixed(0)} ${'units.meter'.tr()}';
    }

    return '${fallback.toStringAsFixed(1)} ${'units.kilometer'.tr()}';
  }

  String _placeTypeLabelKey(PlaceType type) {
    switch (type) {
      case PlaceType.hospital:
        return 'map.place_types.hospital';
      case PlaceType.clinic:
        return 'map.place_types.clinic';
      case PlaceType.security:
        return 'map.place_types.security';
      case PlaceType.pharmacy:
        return 'map.place_types.pharmacy';
      case PlaceType.fireStation:
        return 'map.place_types.fire_station';
      case PlaceType.other:
        return 'map.place_types.other';
    }
  }
}

class _MapLayerState {
  const _MapLayerState({
    required this.currentPosition,
    required this.markers,
    required this.markerRevision,
    required this.mapErrorKey,
  });

  final LatLng? currentPosition;
  final Set<Marker> markers;
  final int markerRevision;
  final String? mapErrorKey;

  @override
  bool operator ==(Object other) {
    return other is _MapLayerState &&
        other.currentPosition == currentPosition &&
        other.markerRevision == markerRevision &&
        other.mapErrorKey == mapErrorKey;
  }

  @override
  int get hashCode => Object.hash(currentPosition, markerRevision, mapErrorKey);
}

class _MapHeaderState {
  const _MapHeaderState({
    required this.isLoading,
    required this.isLoadingPlaces,
    required this.actualAreaName,
  });

  final bool isLoading;
  final bool isLoadingPlaces;
  final String actualAreaName;

  @override
  bool operator ==(Object other) {
    return other is _MapHeaderState &&
        other.isLoading == isLoading &&
        other.isLoadingPlaces == isLoadingPlaces &&
        other.actualAreaName == actualAreaName;
  }

  @override
  int get hashCode => Object.hash(isLoading, isLoadingPlaces, actualAreaName);
}

class _MapPlacesState {
  const _MapPlacesState({
    required this.places,
    required this.activeCardIndex,
    required this.isLoadingPlaces,
    required this.hasCurrentPosition,
  });

  final List<PlaceModel> places;
  final int activeCardIndex;
  final bool isLoadingPlaces;
  final bool hasCurrentPosition;

  @override
  bool operator ==(Object other) {
    return other is _MapPlacesState &&
        identical(other.places, places) &&
        other.activeCardIndex == activeCardIndex &&
        other.isLoadingPlaces == isLoadingPlaces &&
        other.hasCurrentPosition == hasCurrentPosition;
  }

  @override
  int get hashCode {
    return Object.hash(
      identityHashCode(places),
      activeCardIndex,
      isLoadingPlaces,
      hasCurrentPosition,
    );
  }
}
