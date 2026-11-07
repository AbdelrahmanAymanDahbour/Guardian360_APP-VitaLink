import 'dart:async'; // 👈 ضروري للـ Stream + unawaited
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/place_model.dart';
import '../services/places_api_service.dart';
import '../config/marker_config.dart';
import '../../../core/services/geocoding_service.dart';

/// ==========================================
/// 🧠 Map ViewModel (Logic & State Management) [Ultra Pro Safe Lifecycle]
/// ==========================================
/// مسؤول عن:
/// - تهيئة موقع المستخدم.
/// - تشغيل تتبع الخريطة اللحظي.
/// - جلب الأماكن الآمنة القريبة.
/// - مزامنة الكروت مع الماركرات.
///
/// ملاحظة مهمة:
/// هذا الـ ViewModel موجود App-Level Provider، لذلك عمره أطول من GoogleMap widget.
/// لذلك يجب حماية GoogleMapController من الاستخدام بعد dispose.
class MapViewModel extends ChangeNotifier {
  GoogleMapController? mapController;
  LatLng? currentPosition;
  bool isLoading = true;
  String? mapErrorKey;

  final Set<Marker> _markers = {};
  Set<Marker> get markers => _markers;

  int _markerRevision = 0;
  int get markerRevision => _markerRevision;

  final PlacesApiService _placesService = PlacesApiService();
  String _locale = 'en';

  List<PlaceModel> _nearbyPlaces = [];
  List<PlaceModel> get nearbyPlaces => _nearbyPlaces;

  bool isLoadingPlaces = false;

  int _activeCardIndex = 0;
  int get activeCardIndex => _activeCardIndex;

  String _currentAreaNameKey = 'map.locating';
  String get currentAreaNameKey => _currentAreaNameKey;

  String _actualAreaName = '';
  String get actualAreaName => _actualAreaName;

  Function(int)? animateToCard;

  // 📡 متغير التتبع اللحظي داخل شاشة الخريطة فقط
  StreamSubscription<Position>? _positionStreamSubscription;

  // ==========================================
  // 🛡️ Lifecycle Guards
  // ==========================================

  bool _isDisposed = false;

  /// هل يوجد GoogleMapController مربوط حاليًا بـ GoogleMap widget فعالة؟
  bool _isMapControllerAttached = false;

  /// رقم جيل الكنترولر.
  /// كل onMapCreated أو detach يغير الرقم حتى يتم تجاهل أي عملية قديمة.
  int _mapControllerGeneration = 0;

  /// رقم جيل طلبات الأماكن.
  /// يمنع نتائج الشبكة القديمة من الكتابة فوق الحالة الجديدة.
  int _placesFetchGeneration = 0;

  /// رقم جيل تهيئة الموقع.
  /// يحمي initializeLocation من التداخل إذا استدعيت أكثر من مرة.
  int _locationInitGeneration = 0;

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  bool _isActiveLocationInitialization(int generation) {
    return !_isDisposed && generation == _locationInitGeneration;
  }

  bool _isActiveMapController(GoogleMapController controller, int generation) {
    return !_isDisposed &&
        _isMapControllerAttached &&
        generation == _mapControllerGeneration &&
        identical(mapController, controller);
  }

  /// يفصل الكنترولر عن الـ ViewModel عند خروج/تدمير GoogleMap widget.
  ///
  /// لا نغيّر بيانات الأماكن ولا الماركرات هنا.
  /// فقط نمنع استعمال controller قديم.
  void detachMapController() {
    _isMapControllerAttached = false;
    _mapControllerGeneration++;
    _placesFetchGeneration++;
    mapController = null;
  }

  // ==========================================
  // 🛰️ تهيئة الموقع والتتبع اللحظي
  // ==========================================

  Future<void> initializeLocation({required String locale}) async {
    if (_isDisposed) return;

    final initGeneration = ++_locationInitGeneration;

    _locale = _sanitizeLocale(locale);
    isLoading = true;
    mapErrorKey = null;
    _safeNotify();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!_isActiveLocationInitialization(initGeneration)) return;

      if (!serviceEnabled) {
        throw 'errors.location_disabled';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (!_isActiveLocationInitialization(initGeneration)) return;

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (!_isActiveLocationInitialization(initGeneration)) return;

        if (permission == LocationPermission.denied) {
          throw 'errors.location_denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'errors.location_denied';
      }

      // 1. اللقطة الأولى: تحديد الموقع بسرعة عشان نفتح الخريطة
      final initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!_isActiveLocationInitialization(initGeneration)) return;

      currentPosition = LatLng(
        initialPosition.latitude,
        initialPosition.longitude,
      );

      // 🎨 رسم الأيقونات الاحترافية في الذاكرة قبل عرضها
      await MarkerConfig.initCustomMarkers();
      if (!_isActiveLocationInitialization(initGeneration)) return;

      _markers.clear();
      _updateUserMarker();

      isLoading = false;
      _safeNotify();

      // جلب الأماكن بناءً على الموقع الأولي
      await fetchNearbyPlaces(locale: _locale);
      if (!_isActiveLocationInitialization(initGeneration)) return;

      // 2. تشغيل الرادار للتتبع اللحظي داخل الخريطة
      _startLiveTracking();
    } catch (e) {
      if (!_isActiveLocationInitialization(initGeneration)) return;

      mapErrorKey = e.toString().startsWith('errors.')
          ? e.toString()
          : 'errors.unknown_map_error';

      isLoading = false;
      _safeNotify();
    }
  }

  Future<void> refreshForLocale(String locale) async {
    if (_isDisposed) return;

    final normalized = _sanitizeLocale(locale);
    if (_locale == normalized && _nearbyPlaces.isNotEmpty) return;

    _locale = normalized;
    if (currentPosition == null) return;

    await fetchNearbyPlaces(locale: _locale);
  }

  void _startLiveTracking() {
    if (_isDisposed) return;

    // نوقف أي تتبع قديم عشان ما يصير تضارب
    _positionStreamSubscription?.cancel();

    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10, // التحديث كل 10 متر لتوفير البطارية
          ),
        ).listen(
          (Position position) {
            if (_isDisposed) return;

            currentPosition = LatLng(position.latitude, position.longitude);

            // نحدث ماركر المستخدم فقط بدون مسح ماركرات الأماكن
            _updateUserMarker();

            _safeNotify();

            // لا نعمل centerOnUserLocation هنا حتى لا نزعج المستخدم أثناء التصفح
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_isDisposed) return;

            debugPrint('❌ Map live tracking error: $error');
            debugPrintStack(stackTrace: stackTrace);
          },
        );
  }

  // ==========================================
  // 🗺️ Google Map Controller Lifecycle
  // ==========================================

  void onMapCreated(GoogleMapController controller) {
    if (_isDisposed) {
      controller.dispose();
      return;
    }

    mapController = controller;
    _isMapControllerAttached = true;
    _mapControllerGeneration++;

    final generation = _mapControllerGeneration;

    unawaited(_applyMapStyleSafely(controller, generation));

    if (currentPosition != null) {
      centerOnUserLocation();
    }
  }

  Future<void> _applyMapStyleSafely(
    GoogleMapController controller,
    int generation,
  ) async {
    try {
      final style = await rootBundle.loadString(
        'assets/map_styles/guardian_map_style.json',
      );

      if (!_isActiveMapController(controller, generation)) return;

      await controller.setMapStyle(style);
    } catch (e) {
      debugPrint('❌ Failed to load map style: $e');
    }
  }

  Future<void> _animateCameraSafely({
    required GoogleMapController controller,
    required int generation,
    required CameraUpdate update,
  }) async {
    if (!_isActiveMapController(controller, generation)) return;

    try {
      await controller.animateCamera(update);
    } catch (e) {
      debugPrint('⚠️ Map camera operation ignored safely: $e');
    }
  }

  Future<void> _focusPlaceSafely({
    required GoogleMapController controller,
    required int generation,
    required CameraUpdate cameraUpdate,
    required MarkerId markerId,
  }) async {
    await _animateCameraSafely(
      controller: controller,
      generation: generation,
      update: cameraUpdate,
    );
  }

  void _updateUserMarker() {
    if (currentPosition == null) return;

    // نحذف الماركر القديم تبع المستخدم حتى لا يترك أثر وراءه
    _markers.removeWhere(
      (marker) => marker.markerId.value == 'user_current_location',
    );

    // نضيف ماركر المستخدم المخصص
    _markers.add(MarkerConfig.createUserLocationMarker(currentPosition!));
    _markerRevision++;
  }

  void centerOnUserLocation() {
    final controller = mapController;
    final position = currentPosition;
    final generation = _mapControllerGeneration;

    if (controller == null || position == null || !_isMapControllerAttached) {
      return;
    }

    unawaited(
      _animateCameraSafely(
        controller: controller,
        generation: generation,
        update: CameraUpdate.newCameraPosition(
          CameraPosition(target: position, zoom: 15.5),
        ),
      ),
    );
  }

  // ==========================================
  // 🌐 جلب الأماكن وتوزيع العلامات
  // ==========================================

  Future<void> fetchNearbyPlaces({String? locale}) async {
    if (_isDisposed) return;
    if (currentPosition == null) return;

    final fetchGeneration = ++_placesFetchGeneration;
    final requestPosition = currentPosition!;

    final language = _sanitizeLocale(locale ?? _locale);
    _locale = language;

    isLoadingPlaces = true;
    _safeNotify();

    try {
      // جلب الأماكن من السيرفيس كما هو بدون تغيير المنطق
      final places = await _placesService.fetchNearestSafePlaces(
        requestPosition,
        locale: language,
      );

      if (_isDisposed || fetchGeneration != _placesFetchGeneration) return;

      final areaName = await GeocodingService(
        languageCode: language,
      ).getAreaNameFromCoordinates(requestPosition);

      if (_isDisposed || fetchGeneration != _placesFetchGeneration) return;

      _nearbyPlaces = places;
      _actualAreaName = areaName;
      _currentAreaNameKey = '';

      _addPlaceMarkers();

      isLoadingPlaces = false;
      _safeNotify();

      if (_nearbyPlaces.isNotEmpty && mapController != null) {
        onCardSwiped(0);
      }
    } catch (e) {
      if (_isDisposed || fetchGeneration != _placesFetchGeneration) return;

      isLoadingPlaces = false;
      _currentAreaNameKey = 'map.current_location';
      _safeNotify();

      debugPrint('❌ Error in fetchNearbyPlaces: $e');
    }
  }

  void _addPlaceMarkers() {
    _markers.clear();
    _updateUserMarker();

    for (int i = 0; i < _nearbyPlaces.length; i++) {
      final place = _nearbyPlaces[i];

      _markers.add(
        MarkerConfig.createMarker(
          place: place,
          snippet: _markerSnippet(place),
          onTap: () {
            onCardSwiped(i);
            animateToCard?.call(i);
          },
        ),
      );
    }

    _markerRevision++;
  }

  // ==========================================
  // 🔄 منطق التزامن بين الكروت والخريطة
  // ==========================================

  void onCardSwiped(int index) {
    if (_nearbyPlaces.isEmpty) return;
    if (index < 0 || index >= _nearbyPlaces.length) return;

    _activeCardIndex = index;
    _safeNotify();

    final place = _nearbyPlaces[index];

    final controller = mapController;
    final generation = _mapControllerGeneration;

    if (controller == null || !_isMapControllerAttached) return;

    final markerId = MarkerId(place.id);

    final markerExists = _markers.any((marker) => marker.markerId == markerId);
    if (!markerExists) return;

    unawaited(
      _focusPlaceSafely(
        controller: controller,
        generation: generation,
        markerId: markerId,
        cameraUpdate: CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(
              place.location.latitude - 0.002,
              place.location.longitude,
            ),
            zoom: 16.5,
            tilt: 45.0,
          ),
        ),
      ),
    );
  }

  Future<void> openDirections(PlaceModel place) async {
    if (_isDisposed) return;
    if (currentPosition == null) return;

    try {
      final origin =
          '${currentPosition!.latitude},${currentPosition!.longitude}';
      final destination =
          '${place.location.latitude},${place.location.longitude}';

      final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=driving',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Navigation Error: $e');
    }
  }

  void stopLiveTracking() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  String _markerSnippet(PlaceModel place) {
    final duration = place.durationText?.trim() ?? '';
    final distance = place.realDistanceText?.trim() ?? '';

    if (duration.isNotEmpty && distance.isNotEmpty) {
      return '$duration • $distance';
    }

    if (duration.isNotEmpty) return duration;
    return distance;
  }

  String _sanitizeLocale(String locale) {
    final language = locale.trim().toLowerCase();
    if (language.startsWith('ar')) return 'ar';
    return 'en';
  }

  // ==========================================
  // 🧹 Dispose
  // ==========================================

  @override
  void dispose() {
    _isDisposed = true;

    _locationInitGeneration++;
    _placesFetchGeneration++;

    detachMapController();
    stopLiveTracking();

    animateToCard = null;

    super.dispose();
  }
}
