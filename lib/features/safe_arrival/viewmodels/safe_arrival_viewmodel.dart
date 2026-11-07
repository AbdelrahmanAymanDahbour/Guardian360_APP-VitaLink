import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_thresholds.dart';
import '../../../core/models/emergency_contact_model.dart';
import '../../../core/services/gps_location_service.dart';
import '../../auth/services/firebase_auth_service.dart';
import '../models/safe_arrival_destination_model.dart';
import '../models/safe_arrival_report_model.dart';
import '../models/safe_arrival_trip_model.dart';
import '../repositories/safe_arrival_repository.dart';
import '../services/safe_arrival_places_service.dart';
import '../services/safe_arrival_route_service.dart';
import '../services/safe_arrival_tracking_service.dart';
import '../services/safe_arrival_notification_service.dart';
import '../services/whatsapp_share_service.dart';

/// حالات شاشة الوصول الآمن.
///
/// أبقينا الأسماء الحالية حتى تبقى الشاشة الحالية متوافقة.
/// لكن المنطق الداخلي أصبح يعتمد على تتبع حقيقي ووجهة موثوقة.
enum SafeArrivalState { setup, tracking, arrived, danger }

/// ==========================================
/// 🛡️ Safe Arrival ViewModel
/// ==========================================
/// مسؤول عن تنسيق ميزة الوصول الآمن فقط.
///
/// مسؤولياته:
/// - إدارة حالة الشاشة.
/// - التحقق من المستخدم الحالي.
/// - البحث عن وجهة موثوقة عبر Google Places.
/// - تجهيز Route Preview حقيقي قبل بدء الرحلة.
/// - تحميل جهة الطوارئ الأساسية.
/// - بدء رحلة Safe Arrival في Firestore.
/// - تشغيل SafeArrivalTrackingService.
/// - استقبال تحديثات GPS والتعامل معها.
/// - إنهاء الرحلة عند الوصول الحقيقي.
/// - فتح WhatsApp برسالة طمأنة جاهزة.
///
/// غير مسؤول عن:
/// - Firestore raw queries داخل UI.
/// - GPS stream low-level.
/// - رسم واجهة المستخدم.
class SafeArrivalViewModel extends ChangeNotifier {
  SafeArrivalViewModel({
    FirebaseAuthService? authService,
    SafeArrivalRepository? repository,
    SafeArrivalTrackingService? trackingService,
    WhatsAppShareService? whatsappShareService,
    SafeArrivalPlacesService? placesService,
    SafeArrivalRouteService? routeService,
    GPSLocationService? gpsService,
    SafeArrivalNotificationService? notificationService,
  }) : _authService = authService ?? FirebaseAuthService(),
       _repository = repository ?? SafeArrivalRepository(),
       _trackingService = trackingService ?? SafeArrivalTrackingService(),
       _whatsappShareService =
           whatsappShareService ?? const WhatsAppShareService(),
       _placesService = placesService ?? SafeArrivalPlacesService(),
       _routeService = routeService ?? SafeArrivalRouteService(),
       _gpsService = gpsService ?? GPSLocationService(),
       _safeArrivalNotificationService =
           notificationService ?? SafeArrivalNotificationService(),
       _ownsPlacesService = placesService == null,
       _ownsRouteService = routeService == null {
    destinationController.addListener(_handleDestinationTextChanged);
    unawaited(initialize());
  }

  final FirebaseAuthService _authService;
  final SafeArrivalRepository _repository;
  final SafeArrivalTrackingService _trackingService;
  final WhatsAppShareService _whatsappShareService;
  final SafeArrivalPlacesService _placesService;
  final SafeArrivalRouteService _routeService;
  final GPSLocationService _gpsService;
  final SafeArrivalNotificationService _safeArrivalNotificationService;

  final bool _ownsPlacesService;
  final bool _ownsRouteService;

  // ==========================================
  // 📦 Public State - compatible with current UI
  // ==========================================

  SafeArrivalState currentState = SafeArrivalState.setup;

  String userName = 'مستخدم Guardian';

  final destinationController = TextEditingController();

  int remainingSeconds = 0;

  bool isInitializing = false;
  bool isLoading = false;
  bool isSharingWhatsApp = false;
  bool isSearchingDestinations = false;
  bool isResolvingDestination = false;
  bool isLoadingRoutePreview = false;

  String errorMessage = '';
  String successMessage = '';
  String warningMessage = '';

  SafeArrivalDestinationModel? selectedDestination;
  EmergencyContactModel? selectedEmergencyContact;
  SafeArrivalTripModel? currentTrip;
  SafeArrivalTrackingUpdate? latestTrackingUpdate;
  SafeArrivalReportModel? latestReport;

  List<SafeArrivalPlacePrediction> destinationPredictions =
      const <SafeArrivalPlacePrediction>[];

  SafeArrivalRoutePreview? routePreview;

  // ==========================================
  // 🔒 Internal State
  // ==========================================

  Timer? _countdownTimer;
  Timer? _destinationSearchDebounce;

  DateTime? _tripStartTime;
  DateTime? _lastCloudSyncAt;

  bool _isDisposed = false;
  bool _isStartingTrip = false;
  bool _isCompletingArrival = false;
  bool _isTriggeringDanger = false;
  bool _isSyncingLocation = false;
  bool _isUpdatingDestinationText = false;
  bool _isRestoringActiveTrip = false;
  bool _isPausingTrip = false;
  bool _isResumingTrip = false;

  int _destinationSearchGeneration = 0;

  final Set<String> _sentSafeArrivalNotificationKeys = <String>{};

  // ==========================================
  // 📖 Getters used by current/new UI
  // ==========================================

  bool get hasTrustedDestination => selectedDestination?.isValid == true;

  bool get hasRoutePreview => routePreview != null;

  bool get hasEmergencyContact =>
      selectedEmergencyContact?.hasValidPhone == true;

  bool get canStartTrip {
    return !isLoading &&
        !isSearchingDestinations &&
        !isResolvingDestination &&
        !isLoadingRoutePreview &&
        !_isStartingTrip &&
        currentState == SafeArrivalState.setup &&
        hasTrustedDestination &&
        hasRoutePreview;
  }

  bool get isRestoringActiveTrip => _isRestoringActiveTrip;

  bool get isTripPaused {
    return currentTrip?.status == SafeArrivalTripStatus.paused;
  }

  bool get canPauseTrip {
    return currentState == SafeArrivalState.tracking &&
        currentTrip?.status == SafeArrivalTripStatus.tracking &&
        !_isPausingTrip &&
        !isLoading;
  }

  bool get canResumeTrip {
    return currentState == SafeArrivalState.tracking &&
        isTripPaused &&
        !_isResumingTrip &&
        !isLoading;
  }

  bool get canCancelCurrentTrip {
    return currentTrip != null && !isLoading;
  }

  String get trackingStatusText {
    if (isTripPaused) {
      return 'تم إيقاف التتبع مؤقتًا.';
    }

    if (currentState == SafeArrivalState.danger) {
      return 'تحتاج الرحلة إلى مراجعة.';
    }

    return 'التتبع نشط.';
  }

  bool get hasDestinationPredictions => destinationPredictions.isNotEmpty;

  String get selectedDestinationTitle {
    return selectedDestination?.displayName ??
        destinationController.text.trim();
  }

  String get selectedDestinationAddress {
    return selectedDestination?.displayAddress ?? '';
  }

  String get estimatedDistanceText {
    return routePreview?.formattedDistance ?? '--';
  }

  String get estimatedDurationText {
    return routePreview?.formattedDuration ?? '--';
  }

  String get remainingDistanceText {
    final meters =
        latestTrackingUpdate?.distanceToDestinationMeters ??
        currentTrip?.distanceToDestinationMeters;

    if (meters == null) return '--';

    return _formatDistance(meters);
  }

  String get currentGpsAccuracyText {
    final accuracy = latestTrackingUpdate?.accuracyMeters;

    if (accuracy == null) return '--';

    return '${accuracy.toStringAsFixed(0)} م';
  }

  String get currentSpeedText {
    final speed = latestTrackingUpdate?.speedKmh;

    if (speed == null) return '--';

    return '${speed.toStringAsFixed(0)} كم/س';
  }

  String get safetyRating {
    return currentTrip?.report?.ratingLabel ??
        latestReport?.ratingLabel ??
        '--';
  }

  String get formattedTime {
    final safeRemaining = remainingSeconds < 0 ? 0 : remainingSeconds;

    final minutes = safeRemaining ~/ 60;
    final seconds = safeRemaining % 60;

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int? get dynamicEtaSeconds {
    final update = latestTrackingUpdate;
    if (update != null) {
      return _calculateDynamicEtaSeconds(update);
    }

    if (remainingSeconds > 0) {
      return remainingSeconds;
    }

    return routePreview?.durationSeconds;
  }

  String get dynamicEtaText {
    final eta = dynamicEtaSeconds;
    if (eta == null) return '--';
    return _formatElapsedSeconds(eta);
  }

  bool get isNearDestination {
    final meters =
        latestTrackingUpdate?.distanceToDestinationMeters ??
        currentTrip?.distanceToDestinationMeters;

    if (meters == null) return false;

    return meters <= AppThresholds.safeArrivalManualFinishRadiusMeters;
  }

  bool get canFinishManually {
    final update = latestTrackingUpdate;

    if (currentState != SafeArrivalState.tracking || update == null) {
      return false;
    }

    return update.canConfirmArrival || isNearDestination;
  }

  String get approachStatusText {
    final meters =
        latestTrackingUpdate?.distanceToDestinationMeters ??
        currentTrip?.distanceToDestinationMeters;

    if (meters == null) {
      return 'جاري تحديد المسافة المتبقية.';
    }

    if (latestTrackingUpdate?.canConfirmArrival == true) {
      return 'أنت داخل نطاق الوصول.';
    }

    if (isNearDestination) {
      return 'أنت قريب من الوجهة.';
    }

    return 'تبقى ${_formatDistance(meters)} للوصول.';
  }

  List<LatLng> get routePolylinePoints {
    return routePreview?.polylinePoints ?? const <LatLng>[];
  }

  LatLng? get routeOrigin {
    return routePreview?.origin;
  }

  LatLng? get routeDestination {
    final destination = selectedDestination;

    if (destination == null || !destination.hasValidCoordinates) return null;

    return LatLng(destination.latitude, destination.longitude);
  }

  LatLng? get currentLocation {
    final update = latestTrackingUpdate;

    if (update != null) {
      return LatLng(update.latitude, update.longitude);
    }

    final trip = currentTrip;

    if (trip != null && trip.hasCurrentLocation) {
      return LatLng(trip.currentLatitude!, trip.currentLongitude!);
    }

    return routePreview?.origin;
  }

  LatLng? get mapCenter {
    return currentLocation ?? routePreview?.center ?? routeDestination;
  }

  // ==========================================
  // 🚀 Initialization
  // ==========================================

  Future<void> initialize() async {
    if (isInitializing) return;

    isInitializing = true;
    _safeNotify();

    await Future.wait([_loadUserName(), _loadPrimaryEmergencyContact()]);

    await _restoreActiveTripIfAny();

    isInitializing = false;
    _safeNotify();
  }

  Future<void> _loadUserName() async {
    try {
      final currentUser = _authService.currentUser;
      final authDisplayName = currentUser?.displayName?.trim();

      if (authDisplayName != null && authDisplayName.isNotEmpty) {
        userName = authDisplayName;
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final cachedName = prefs.getString('user_name')?.trim();

      if (cachedName != null && cachedName.isNotEmpty) {
        userName = cachedName;
      }
    } catch (e, stackTrace) {
      debugPrint('⚠️ SafeArrivalViewModel: Failed to load user name - $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _loadPrimaryEmergencyContact() async {
    try {
      final currentUser = _authService.currentUser;

      if (currentUser == null) {
        selectedEmergencyContact = null;
        return;
      }

      final result = await _repository.loadPrimaryEmergencyContact(
        currentUser.uid,
      );

      if (result.isSuccess) {
        selectedEmergencyContact = result.data;
        return;
      }

      selectedEmergencyContact = null;

      debugPrint(
        '⚠️ SafeArrivalViewModel: primary contact load failed - ${result.error}',
      );
    } catch (e, stackTrace) {
      selectedEmergencyContact = null;
      debugPrint(
        '⚠️ SafeArrivalViewModel: Failed to load primary contact - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // ♻️ Active Trip Restore
  // ==========================================

  Future<void> _restoreActiveTripIfAny({bool showMessage = false}) async {
    if (_isRestoringActiveTrip) return;

    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    _isRestoringActiveTrip = true;

    try {
      final result = await _repository.getActiveTrip(currentUser.uid);

      if (result.isFailure) {
        warningMessage = 'تعذر التحقق من الرحلات النشطة.';
        debugPrint(
          '⚠️ SafeArrivalViewModel: restore active trip failed - ${result.error}',
        );
        return;
      }

      final trip = result.data;

      if (trip == null) return;

      // رحلة ready تعني غالبًا أن إنشاء الوثيقة تم لكن التتبع لم يبدأ.
      // ننظفها حتى لا تعلق المستخدم برسالة "رحلة نشطة بالفعل".
      if (trip.status == SafeArrivalTripStatus.ready) {
        await _repository.cancelTrip(
          tripId: trip.id,
          reason: 'stale_ready_trip_restored',
        );

        _resetTripUiState();

        if (showMessage) {
          warningMessage =
              'تم تنظيف رحلة غير مكتملة. يمكنك بدء رحلة جديدة الآن.';
        }

        return;
      }

      _applyRestoredTripToState(trip);

      if (trip.status == SafeArrivalTripStatus.danger) {
        currentState = SafeArrivalState.danger;
        warningMessage = 'تم استعادة رحلة وصول آمن تحتاج إلى مراجعة.';
        return;
      }

      if (trip.status == SafeArrivalTripStatus.paused) {
        currentState = SafeArrivalState.tracking;
        _stopCountdown();

        if (showMessage) {
          warningMessage = 'تم استعادة رحلة متوقفة مؤقتًا.';
        }

        unawaited(loadRoutePreviewForSelectedDestination());
        return;
      }

      if (trip.status == SafeArrivalTripStatus.tracking) {
        currentState = SafeArrivalState.tracking;
        remainingSeconds = _remainingSecondsFromTrip(trip);
        _startCountdown();

        unawaited(loadRoutePreviewForSelectedDestination());
        unawaited(_resumeTrackingEngineForRestoredTrip(trip));

        if (showMessage) {
          successMessage = 'تم استعادة الرحلة النشطة.';
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalViewModel: restore active trip exception - $e');
      debugPrintStack(stackTrace: stackTrace);
      warningMessage = 'تعذر استعادة رحلة الوصول الآمن.';
    } finally {
      _isRestoringActiveTrip = false;
      _safeNotify();
    }
  }

  void _applyRestoredTripToState(SafeArrivalTripModel trip) {
    currentTrip = trip;
    latestReport = trip.report;
    _tripStartTime = trip.startedAt;
    _lastCloudSyncAt = DateTime.now();

    selectedDestination = trip.destination;

    if (trip.destination != null) {
      _isUpdatingDestinationText = true;
      try {
        destinationController.text = trip.destination!.displayName;
      } finally {
        _isUpdatingDestinationText = false;
      }
    }

    if (trip.hasCurrentLocation && trip.distanceToDestinationMeters != null) {
      latestTrackingUpdate = null;
    }

    remainingSeconds = _remainingSecondsFromTrip(trip);
  }

  int _remainingSecondsFromTrip(SafeArrivalTripModel trip) {
    final estimatedArrivalAt = trip.estimatedArrivalAt;

    if (estimatedArrivalAt != null) {
      final seconds = estimatedArrivalAt.difference(DateTime.now()).inSeconds;
      return seconds < 0 ? 0 : seconds;
    }

    final estimatedDuration = trip.estimatedDurationSeconds;
    if (estimatedDuration != null && estimatedDuration > 0) {
      return estimatedDuration;
    }

    return routePreview?.durationSeconds ?? 0;
  }

  Future<bool> _resumeTrackingEngineForRestoredTrip(
    SafeArrivalTripModel trip,
  ) async {
    final destination = trip.destination;

    if (destination == null || !destination.isValid) {
      warningMessage = 'تعذر استئناف التتبع لأن بيانات الوجهة غير مكتملة.';
      _safeNotify();
      return false;
    }

    final estimatedDurationSeconds =
        trip.estimatedDurationSeconds ??
        routePreview?.durationSeconds ??
        AppThresholds.safeArrivalMinDurationMinutes * 60;

    final estimatedArrivalAt =
        trip.estimatedArrivalAt ??
        DateTime.now().add(Duration(seconds: estimatedDurationSeconds));

    final result = await _trackingService.startTracking(
      tripId: trip.id,
      destination: destination,
      estimatedArrivalAt: estimatedArrivalAt,
      estimatedDurationSeconds: estimatedDurationSeconds,
      onUpdate: _handleTrackingUpdate,
      onArrived: _handleArrivalDetected,
      onDanger: _handleDangerDetected,
      onWarning: _handleTrackingWarning,
    );

    if (result.isFailure) {
      warningMessage = _friendlyTrackingError(result.error);
      _safeNotify();
      return false;
    }

    latestTrackingUpdate = result.data;
    _safeNotify();
    return true;
  }

  // ==========================================
  // 🔎 Destination Search
  // ==========================================

  void searchDestinations(String query) {
    if (currentState != SafeArrivalState.setup) return;

    final safeQuery = _cleanText(query);

    _destinationSearchDebounce?.cancel();

    if (safeQuery.length < 2) {
      destinationPredictions = const <SafeArrivalPlacePrediction>[];
      isSearchingDestinations = false;
      _destinationSearchGeneration++;
      _safeNotify();
      return;
    }

    final generation = ++_destinationSearchGeneration;

    isSearchingDestinations = true;
    _safeNotify();

    _destinationSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_searchDestinationsNow(safeQuery, generation));
    });
  }

  Future<void> _searchDestinationsNow(String query, int generation) async {
    try {
      final result = await _placesService.searchDestinations(query: query);

      if (generation != _destinationSearchGeneration) return;

      if (result.isFailure) {
        destinationPredictions = const <SafeArrivalPlacePrediction>[];
        warningMessage = _friendlyPlacesError(result.error);
        return;
      }

      destinationPredictions =
          result.data ?? const <SafeArrivalPlacePrediction>[];

      if (destinationPredictions.isEmpty) {
        warningMessage = 'لا توجد نتائج مطابقة للوجهة المدخلة.';
      } else {
        warningMessage = '';
      }
    } catch (e, stackTrace) {
      if (generation != _destinationSearchGeneration) return;

      debugPrint('❌ SafeArrivalViewModel: destination search failed - $e');
      debugPrintStack(stackTrace: stackTrace);

      destinationPredictions = const <SafeArrivalPlacePrediction>[];
      warningMessage = 'تعذر البحث عن الوجهة حالياً.';
    } finally {
      if (generation == _destinationSearchGeneration) {
        isSearchingDestinations = false;
        _safeNotify();
      }
    }
  }

  Future<void> selectDestinationPrediction(
    SafeArrivalPlacePrediction prediction,
  ) async {
    if (isResolvingDestination) return;

    clearMessages();

    if (!prediction.isValid) {
      errorMessage = 'يرجى اختيار وجهة صحيحة من نتائج البحث.';
      _safeNotify();
      return;
    }

    isResolvingDestination = true;
    _safeNotify();

    try {
      final result = await _placesService.resolveDestination(
        prediction: prediction,
      );

      if (result.isFailure || result.data == null) {
        errorMessage = _friendlyPlacesError(result.error);
        return;
      }

      _setTrustedDestination(result.data!);
      destinationPredictions = const <SafeArrivalPlacePrediction>[];

      unawaited(loadRoutePreviewForSelectedDestination());
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalViewModel: destination resolve failed - $e');
      debugPrintStack(stackTrace: stackTrace);

      errorMessage = 'تعذر اختيار الوجهة حالياً.';
    } finally {
      isResolvingDestination = false;
      _safeNotify();
    }
  }

  /// يتم استدعاؤها لاحقاً من شاشة البحث عن الوجهة أو الاختبارات.
  ///
  /// لا نقبل نصاً حراً كوجهة نهائية.
  /// الوجهة تصبح صالحة فقط بعد اختيار مكان موثوق فيه إحداثيات.
  void selectTrustedDestination(SafeArrivalDestinationModel destination) {
    clearMessages();

    if (!destination.isValid) {
      selectedDestination = null;
      destinationPredictions = const <SafeArrivalPlacePrediction>[];
      routePreview = null;
      destinationController.clear();
      errorMessage = 'يرجى اختيار وجهة صحيحة من نتائج البحث.';
      _safeNotify();
      return;
    }

    _setTrustedDestination(destination);
    destinationPredictions = const <SafeArrivalPlacePrediction>[];
    _safeNotify();

    unawaited(loadRoutePreviewForSelectedDestination());
  }

  void _setTrustedDestination(SafeArrivalDestinationModel destination) {
    selectedDestination = destination;
    routePreview = null;
    latestTrackingUpdate = null;

    _isUpdatingDestinationText = true;
    try {
      destinationController.text = destination.displayName;
    } finally {
      _isUpdatingDestinationText = false;
    }
  }

  void clearSelectedDestination() {
    _destinationSearchDebounce?.cancel();
    _destinationSearchGeneration++;

    selectedDestination = null;
    destinationPredictions = const <SafeArrivalPlacePrediction>[];
    routePreview = null;

    destinationController.clear();

    _safeNotify();
  }

  void _handleDestinationTextChanged() {
    if (_isUpdatingDestinationText) return;
    if (currentState != SafeArrivalState.setup) return;

    final currentText = destinationController.text.trim();

    final destination = selectedDestination;

    if (currentText.isEmpty) {
      selectedDestination = null;
      destinationPredictions = const <SafeArrivalPlacePrediction>[];
      routePreview = null;
      _destinationSearchGeneration++;
      _safeNotify();
      return;
    }

    if (destination != null) {
      final matchesSelectedDestination =
          currentText == destination.displayName ||
          currentText == destination.displayAddress;

      if (!matchesSelectedDestination) {
        selectedDestination = null;
        routePreview = null;
        warningMessage =
            'تم تعديل الوجهة يدوياً. يرجى اختيار وجهة من نتائج البحث.';
      }
    }

    searchDestinations(currentText);
  }

  // ==========================================
  // 🛣️ Route Preview
  // ==========================================

  Future<bool> loadRoutePreviewForSelectedDestination() async {
    final destination = selectedDestination;

    if (destination == null || !destination.isValid) {
      errorMessage = 'يرجى اختيار وجهة صحيحة قبل تجهيز المسار.';
      _safeNotify();
      return false;
    }

    if (isLoadingRoutePreview) return false;

    isLoadingRoutePreview = true;
    _safeNotify();

    try {
      final positionResult = await _gpsService.getCurrentPosition(
        accuracy: LocationAccuracy.high,
      );

      if (positionResult.isFailure || positionResult.data == null) {
        errorMessage = 'تعذر الحصول على موقعك الحالي لتجهيز المسار.';
        debugPrint(
          '⚠️ SafeArrivalViewModel: route origin location failed - ${positionResult.error}',
        );
        return false;
      }

      final position = positionResult.data!;
      final origin = LatLng(position.latitude, position.longitude);

      final routeResult = await _routeService.previewRoute(
        origin: origin,
        destination: destination,
      );

      if (routeResult.isFailure || routeResult.data == null) {
        routePreview = null;
        errorMessage = _friendlyRouteError(routeResult.error);
        return false;
      }

      routePreview = routeResult.data;

      successMessage = 'تم تجهيز مسار الرحلة بنجاح.';
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalViewModel: route preview failed - $e');
      debugPrintStack(stackTrace: stackTrace);

      routePreview = null;
      errorMessage = 'تعذر تجهيز مسار الرحلة حالياً.';
      return false;
    } finally {
      isLoadingRoutePreview = false;
      _safeNotify();
    }
  }

  int? get _routePreviewDurationSeconds {
    final preview = routePreview;
    if (preview == null) return null;

    final seconds = preview.durationSeconds;

    if (seconds <= 0) return null;

    final minSeconds = AppThresholds.safeArrivalMinDurationMinutes * 60;
    final maxSeconds = AppThresholds.safeArrivalMaxDurationHours * 3600;

    if (seconds < minSeconds) return minSeconds;
    if (seconds > maxSeconds) return null;

    return seconds;
  }

  // ==========================================
  // 🚗 Start Tracking
  // ==========================================

  /// Public method kept as void for compatibility with current button callbacks.
  void startTracking() {
    unawaited(_startTrackingInternal());
  }

  Future<void> _startTrackingInternal() async {
    if (_isStartingTrip || isLoading) return;

    clearMessages();

    final currentUser = _authService.currentUser;

    if (currentUser == null) {
      errorMessage = 'يرجى تسجيل الدخول قبل بدء رحلة الوصول الآمن.';
      _safeNotify();
      return;
    }

    final destination = selectedDestination;

    if (destination == null || !destination.isValid) {
      errorMessage = 'يرجى اختيار وجهة صحيحة من نتائج البحث قبل بدء الرحلة.';
      _safeNotify();
      return;
    }

    if (routePreview == null) {
      final routePrepared = await loadRoutePreviewForSelectedDestination();

      if (!routePrepared || routePreview == null) {
        if (errorMessage.trim().isEmpty) {
          errorMessage = 'تعذر تجهيز مسار الرحلة. حاول مرة أخرى.';
          _safeNotify();
        }
        return;
      }
    }

    final estimatedDurationSeconds = _routePreviewDurationSeconds;

    if (estimatedDurationSeconds == null) {
      errorMessage =
          'تعذر تحديد وقت الرحلة من المسار. يرجى إعادة تجهيز المسار أو اختيار وجهة أخرى.';
      _safeNotify();
      return;
    }

    _isStartingTrip = true;
    isLoading = true;
    _safeNotify();

    try {
      if (selectedEmergencyContact == null) {
        await _loadPrimaryEmergencyContact();
      }

      final estimatedArrivalAt = DateTime.now().add(
        Duration(seconds: estimatedDurationSeconds),
      );

      final contact = selectedEmergencyContact;

      final draftTrip = SafeArrivalTripModel.createDraft(
        userId: currentUser.uid,
        destination: destination,
        selectedContactName: contact?.name,
        selectedContactPhone: contact?.phone,
      ).copyWith(status: SafeArrivalTripStatus.ready);

      final createResult = await _repository.createTrip(draftTrip);

      if (createResult.isFailure || createResult.data == null) {
        if (createResult.error?.code == 'active-trip-already-exists') {
          await _restoreActiveTripIfAny(showMessage: true);

          if (currentTrip != null) {
            errorMessage = '';
            warningMessage =
                'تم العثور على رحلة وصول آمن نشطة. يمكنك استكمالها أو إلغاؤها.';
            return;
          }

          if (warningMessage.trim().isNotEmpty) {
            errorMessage = '';
            return;
          }
        }

        errorMessage = _friendlyRepositoryError(createResult.error);
        return;
      }

      currentTrip = createResult.data;

      final trackingResult = await _trackingService.startTracking(
        tripId: currentTrip!.id,
        destination: destination,
        estimatedArrivalAt: estimatedArrivalAt,
        estimatedDurationSeconds: estimatedDurationSeconds,
        onUpdate: _handleTrackingUpdate,
        onArrived: _handleArrivalDetected,
        onDanger: _handleDangerDetected,
        onWarning: _handleTrackingWarning,
      );

      if (trackingResult.isFailure || trackingResult.data == null) {
        await _repository.cancelTrip(
          tripId: currentTrip!.id,
          reason: trackingResult.error?.code ?? 'tracking-start-failed',
        );

        currentTrip = null;
        errorMessage = _friendlyTrackingError(trackingResult.error);
        return;
      }

      final initialUpdate = trackingResult.data!;

      final startResult = await _repository.startTrip(
        trip: currentTrip!,
        startLatitude: initialUpdate.latitude,
        startLongitude: initialUpdate.longitude,
        startLocationName: '',
        selectedContactName: contact?.name,
        selectedContactPhone: contact?.phone,
        estimatedArrivalAt: estimatedArrivalAt,
        estimatedDistanceMeters:
            routePreview?.distanceMeters ??
            initialUpdate.distanceToDestinationMeters,
        estimatedDurationSeconds: estimatedDurationSeconds,
      );

      if (startResult.isFailure || startResult.data == null) {
        await _trackingService.stopTracking();

        await _repository.cancelTrip(
          tripId: currentTrip!.id,
          reason: startResult.error?.code ?? 'trip-start-failed',
        );

        currentTrip = null;
        errorMessage = _friendlyRepositoryError(startResult.error);
        return;
      }

      currentTrip = startResult.data;
      latestTrackingUpdate = initialUpdate;

      _tripStartTime = currentTrip!.startedAt ?? DateTime.now();
      _lastCloudSyncAt = DateTime.now();

      final initialEtaSeconds = _calculateDynamicEtaSeconds(initialUpdate);
      remainingSeconds = initialEtaSeconds ?? estimatedDurationSeconds;

      _startCountdown();

      currentState = SafeArrivalState.tracking;
      successMessage = 'تم بدء تتبع رحلة الوصول الآمن.';

      if (currentTrip != null) {
        _notifySafeArrivalStarted(currentTrip!);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalViewModel: startTracking failed - $e');
      debugPrintStack(stackTrace: stackTrace);

      errorMessage = 'حدث خطأ أثناء بدء رحلة الوصول الآمن.';
      await _trackingService.stopTracking();
    } finally {
      _isStartingTrip = false;
      isLoading = false;
      _safeNotify();
    }
  }

  // ==========================================
  // 📍 Tracking Callbacks
  // ==========================================

  void _handleTrackingUpdate(SafeArrivalTrackingUpdate update) {
    latestTrackingUpdate = update;

    final trip = currentTrip;

    if (trip != null) {
      currentTrip = trip.copyWith(
        currentLatitude: update.latitude,
        currentLongitude: update.longitude,
        actualDistanceMeters: update.actualDistanceMeters,
        distanceToDestinationMeters: update.distanceToDestinationMeters,
        updatedAt: update.createdAt,
      );
    }

    final etaSeconds = _calculateDynamicEtaSeconds(update);
    if (etaSeconds != null) {
      remainingSeconds = etaSeconds;
    }

    unawaited(_syncTrackingUpdateIfNeeded(update));

    _safeNotify();
  }

  Future<void> _syncTrackingUpdateIfNeeded(
    SafeArrivalTrackingUpdate update,
  ) async {
    if (_isSyncingLocation) return;

    final trip = currentTrip;
    if (trip == null) return;

    final now = DateTime.now();
    final lastSync = _lastCloudSyncAt;

    if (lastSync != null) {
      final secondsSinceSync = now.difference(lastSync).inSeconds;

      if (secondsSinceSync < AppThresholds.safeArrivalCloudUpdateSeconds) {
        return;
      }
    }

    _isSyncingLocation = true;
    _lastCloudSyncAt = now;

    try {
      final result = await _repository.updateTripLocation(
        tripId: trip.id,
        latitude: update.latitude,
        longitude: update.longitude,
        currentLocationName: '',
        actualDistanceMeters: update.actualDistanceMeters,
        distanceToDestinationMeters: update.distanceToDestinationMeters,
      );

      if (result.isFailure) {
        debugPrint(
          '⚠️ SafeArrivalViewModel: location cloud sync failed - ${result.error}',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('⚠️ SafeArrivalViewModel: location cloud sync exception - $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isSyncingLocation = false;
    }
  }

  void _handleArrivalDetected(SafeArrivalArrivalResult result) {
    unawaited(
      _completeArrival(
        latitude: result.latitude,
        longitude: result.longitude,
        actualDistanceMeters: result.actualDistanceMeters,
        distanceToDestinationMeters: result.distanceToDestinationMeters,
        report: result.report,
        arrivedAt: result.arrivedAt,
      ),
    );
  }

  void _handleDangerDetected(SafeArrivalDangerEvent event) {
    unawaited(
      _triggerDangerInternal(
        reasonCode: event.reasonCode,
        message: event.message,
        latitude: event.latitude,
        longitude: event.longitude,
        actualDistanceMeters: event.actualDistanceMeters,
        distanceToDestinationMeters: event.distanceToDestinationMeters,
        report: event.report,
      ),
    );
  }

  void _handleTrackingWarning(SafeArrivalTrackingWarning warning) {
    final friendlyMessage = _friendlyTrackingWarning(warning);

    if (friendlyMessage.trim().isEmpty) {
      return;
    }

    warningMessage = friendlyMessage;

    if (warning.code == SafeArrivalTrackingWarningCode.nearDestination) {
      final trip = currentTrip;

      if (trip != null) {
        _notifySafeArrivalNearDestination(
          trip: trip,
          distanceToDestinationMeters:
              latestTrackingUpdate?.distanceToDestinationMeters ??
              trip.distanceToDestinationMeters,
        );
      }
    }

    _safeNotify();
  }

  // ==========================================
  // ✅ Confirm Arrival
  // ==========================================

  /// Public method kept as void for compatibility with current button callbacks.
  void confirmArrival() {
    unawaited(_confirmArrivalInternal());
  }

  Future<void> _confirmArrivalInternal() async {
    if (_isCompletingArrival) return;

    clearMessages();

    if (currentState != SafeArrivalState.tracking) {
      errorMessage = 'لا توجد رحلة وصول آمن نشطة.';
      _safeNotify();
      return;
    }

    final update = latestTrackingUpdate;

    if (update == null) {
      errorMessage = 'لم يتم استلام موقع GPS كافٍ لتأكيد الوصول.';
      _safeNotify();
      return;
    }

    if (!update.canConfirmArrival) {
      errorMessage =
          'لا يمكن تأكيد الوصول بعد. اقترب من الوجهة وانتظر ثبات قراءة GPS.';
      _safeNotify();
      return;
    }

    final report = _trackingService.buildReport(arrived: true);

    await _completeArrival(
      latitude: update.latitude,
      longitude: update.longitude,
      actualDistanceMeters: update.actualDistanceMeters,
      distanceToDestinationMeters: update.distanceToDestinationMeters,
      report: report,
      arrivedAt: DateTime.now(),
    );
  }

  Future<void> _completeArrival({
    required double latitude,
    required double longitude,
    required double actualDistanceMeters,
    required double distanceToDestinationMeters,
    required SafeArrivalReportModel report,
    required DateTime arrivedAt,
  }) async {
    if (_isCompletingArrival) return;

    final trip = currentTrip;

    if (trip == null) {
      errorMessage = 'تعذر إنهاء الرحلة لأن بيانات الرحلة غير متوفرة.';
      _safeNotify();
      return;
    }

    _isCompletingArrival = true;
    isLoading = true;
    _safeNotify();

    try {
      _stopCountdown();

      final endLocationName = await _trackingService
          .resolveAddressForLastPosition();

      final result = await _repository.markArrived(
        tripId: trip.id,
        endLatitude: latitude,
        endLongitude: longitude,
        endLocationName: endLocationName,
        actualDistanceMeters: actualDistanceMeters,
        report: report,
      );

      if (result.isFailure) {
        errorMessage = _friendlyRepositoryError(result.error);
        return;
      }

      await _trackingService.stopTracking();

      latestReport = report;

      currentTrip = trip.copyWith(
        status: SafeArrivalTripStatus.arrived,
        currentLatitude: latitude,
        currentLongitude: longitude,
        currentLocationName: endLocationName,
        endLatitude: latitude,
        endLongitude: longitude,
        endLocationName: endLocationName,
        actualDistanceMeters: actualDistanceMeters,
        distanceToDestinationMeters: distanceToDestinationMeters,
        report: report,
        arrivedAt: arrivedAt,
        updatedAt: DateTime.now(),
      );

      currentState = SafeArrivalState.arrived;
      successMessage = 'تم تأكيد الوصول بسلامة.';

      if (currentTrip != null) {
        _notifySafeArrivalArrived(currentTrip!);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalViewModel: complete arrival failed - $e');
      debugPrintStack(stackTrace: stackTrace);
      errorMessage = 'حدث خطأ أثناء تأكيد الوصول.';
    } finally {
      _isCompletingArrival = false;
      isLoading = false;
      _safeNotify();
    }
  }

  void finishTripManually() {
    unawaited(_finishTripManuallyInternal());
  }

  Future<void> _finishTripManuallyInternal() async {
    if (_isCompletingArrival || isLoading) return;

    clearMessages();

    if (currentState != SafeArrivalState.tracking) {
      errorMessage = 'لا توجد رحلة وصول آمن نشطة.';
      _safeNotify();
      return;
    }

    final trip = currentTrip;
    final update = latestTrackingUpdate;

    if (trip == null || update == null) {
      errorMessage = 'لم يتم استلام موقع GPS كافٍ لإنهاء الرحلة.';
      _safeNotify();
      return;
    }

    if (!canFinishManually) {
      errorMessage = 'يمكن إنهاء الرحلة يدويًا عند الاقتراب من الوجهة.';
      _safeNotify();
      return;
    }

    _isCompletingArrival = true;
    isLoading = true;
    _safeNotify();

    try {
      _stopCountdown();

      final endLocationName = await _trackingService
          .resolveAddressForLastPosition();

      final report = _trackingService.buildReport(arrived: true);

      final result = await _repository.finishTripManually(
        tripId: trip.id,
        endLatitude: update.latitude,
        endLongitude: update.longitude,
        endLocationName: endLocationName,
        actualDistanceMeters: update.actualDistanceMeters,
        distanceToDestinationMeters: update.distanceToDestinationMeters,
        report: report,
        reason: 'manual_finish_near_destination',
      );

      if (result.isFailure) {
        errorMessage = _friendlyRepositoryError(result.error);
        return;
      }

      await _trackingService.stopTracking();

      latestReport = report;

      currentTrip = trip.copyWith(
        status: SafeArrivalTripStatus.arrived,
        currentLatitude: update.latitude,
        currentLongitude: update.longitude,
        currentLocationName: endLocationName,
        endLatitude: update.latitude,
        endLongitude: update.longitude,
        endLocationName: endLocationName,
        actualDistanceMeters: update.actualDistanceMeters,
        distanceToDestinationMeters: update.distanceToDestinationMeters,
        report: report,
        finishReason: 'manual_finish_near_destination',
        manualFinishedAt: DateTime.now(),
        arrivedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      currentState = SafeArrivalState.arrived;
      successMessage = 'تم إنهاء الرحلة بنجاح.';

      if (currentTrip != null) {
        _notifySafeArrivalArrived(currentTrip!);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalViewModel: manual finish failed - $e');
      debugPrintStack(stackTrace: stackTrace);
      errorMessage = 'تعذر إنهاء الرحلة يدويًا.';
    } finally {
      _isCompletingArrival = false;
      isLoading = false;
      _safeNotify();
    }
  }

  // ==========================================
  // 🚨 Danger
  // ==========================================

  /// Public method kept for compatibility with current UI.
  void triggerDanger() {
    unawaited(
      _triggerDangerInternal(
        reasonCode: SafeArrivalDangerReason.userNotResponding.value,
        message: 'لم يتم تأكيد الوصول الآمن ضمن الوقت المتوقع.',
      ),
    );
  }

  Future<void> _triggerDangerInternal({
    required String reasonCode,
    required String message,
    double? latitude,
    double? longitude,
    double? actualDistanceMeters,
    double? distanceToDestinationMeters,
    SafeArrivalReportModel? report,
  }) async {
    if (_isTriggeringDanger) return;

    final trip = currentTrip;

    if (trip == null) {
      currentState = SafeArrivalState.danger;
      errorMessage = message;
      _safeNotify();
      return;
    }

    _isTriggeringDanger = true;
    isLoading = true;
    _safeNotify();

    try {
      _stopCountdown();

      final update = latestTrackingUpdate;

      final resolvedLatitude = latitude ?? update?.latitude;
      final resolvedLongitude = longitude ?? update?.longitude;
      final resolvedActualDistance =
          actualDistanceMeters ??
          update?.actualDistanceMeters ??
          trip.actualDistanceMeters;
      final resolvedDistanceToDestination =
          distanceToDestinationMeters ?? update?.distanceToDestinationMeters;

      final currentLocationName = await _trackingService
          .resolveAddressForLastPosition();

      final resolvedReport =
          report ?? _trackingService.buildReport(arrived: false);

      final result = await _repository.markDanger(
        tripId: trip.id,
        reason: reasonCode,
        latitude: resolvedLatitude,
        longitude: resolvedLongitude,
        currentLocationName: currentLocationName,
        actualDistanceMeters: resolvedActualDistance,
        distanceToDestinationMeters: resolvedDistanceToDestination,
        report: resolvedReport,
      );

      if (result.isFailure) {
        errorMessage = _friendlyRepositoryError(result.error);
        return;
      }

      await _trackingService.stopTracking();

      latestReport = resolvedReport;

      currentTrip = trip.copyWith(
        status: SafeArrivalTripStatus.danger,
        currentLatitude: resolvedLatitude,
        currentLongitude: resolvedLongitude,
        currentLocationName: currentLocationName,
        actualDistanceMeters: resolvedActualDistance,
        distanceToDestinationMeters: resolvedDistanceToDestination,
        report: resolvedReport,
        dangerReason: reasonCode,
        dangerTriggeredAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      currentState = SafeArrivalState.danger;
      errorMessage = message;

      if (currentTrip != null) {
        _notifySafeArrivalDanger(trip: currentTrip!, reasonCode: reasonCode);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalViewModel: trigger danger failed - $e');
      debugPrintStack(stackTrace: stackTrace);

      currentState = SafeArrivalState.danger;
      errorMessage = 'تم تفعيل حالة الخطر، لكن حدث خطأ أثناء المزامنة.';
    } finally {
      _isTriggeringDanger = false;
      isLoading = false;
      _safeNotify();
    }
  }

  // ==========================================
  // ⏸️ Pause / Resume
  // ==========================================

  void pauseTrip() {
    unawaited(_pauseTripInternal());
  }

  Future<void> _pauseTripInternal() async {
    if (_isPausingTrip || isLoading) return;

    clearMessages();

    final trip = currentTrip;

    if (trip == null || trip.status != SafeArrivalTripStatus.tracking) {
      errorMessage = 'لا توجد رحلة نشطة لإيقافها مؤقتًا.';
      _safeNotify();
      return;
    }

    _isPausingTrip = true;
    isLoading = true;
    _safeNotify();

    try {
      _stopCountdown();
      await _trackingService.stopTracking();

      final result = await _repository.pauseTrip(
        tripId: trip.id,
        reason: 'user_paused',
      );

      if (result.isFailure) {
        errorMessage = _friendlyRepositoryError(result.error);
        return;
      }

      currentTrip = trip.copyWith(
        status: SafeArrivalTripStatus.paused,
        pausedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      currentState = SafeArrivalState.tracking;
      successMessage = 'تم إيقاف التتبع مؤقتًا.';

      if (currentTrip != null) {
        _notifySafeArrivalPaused(currentTrip!);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalViewModel: pause trip failed - $e');
      debugPrintStack(stackTrace: stackTrace);
      errorMessage = 'تعذر إيقاف التتبع مؤقتًا.';
    } finally {
      _isPausingTrip = false;
      isLoading = false;
      _safeNotify();
    }
  }

  void resumeTrip() {
    unawaited(_resumeTripInternal());
  }

  Future<void> _resumeTripInternal() async {
    if (_isResumingTrip || isLoading) return;

    clearMessages();

    final trip = currentTrip;

    if (trip == null || trip.status != SafeArrivalTripStatus.paused) {
      errorMessage = 'لا توجد رحلة متوقفة لاستئنافها.';
      _safeNotify();
      return;
    }

    _isResumingTrip = true;
    isLoading = true;
    _safeNotify();

    try {
      final result = await _repository.resumeTrip(tripId: trip.id);

      if (result.isFailure) {
        errorMessage = _friendlyRepositoryError(result.error);
        return;
      }

      final resumedTrip = trip.copyWith(
        status: SafeArrivalTripStatus.tracking,
        resumedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      currentTrip = resumedTrip;
      currentState = SafeArrivalState.tracking;

      final trackingResumed = await _resumeTrackingEngineForRestoredTrip(
        resumedTrip,
      );

      if (!trackingResumed) {
        _stopCountdown();

        await _repository.pauseTrip(
          tripId: trip.id,
          reason: 'resume_tracking_failed',
        );

        currentTrip = trip.copyWith(updatedAt: DateTime.now());
        currentState = SafeArrivalState.tracking;

        if (warningMessage.trim().isEmpty) {
          errorMessage = 'تعذر استئناف GPS. بقيت الرحلة متوقفة مؤقتًا.';
        }

        return;
      }

      remainingSeconds = _remainingSecondsFromTrip(resumedTrip);
      _startCountdown();

      successMessage = 'تم استئناف التتبع.';
      _notifySafeArrivalResumed(resumedTrip);
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalViewModel: resume trip failed - $e');
      debugPrintStack(stackTrace: stackTrace);
      errorMessage = 'تعذر استئناف التتبع.';
    } finally {
      _isResumingTrip = false;
      isLoading = false;
      _safeNotify();
    }
  }

  // ==========================================
  // 🛑 Cancel
  // ==========================================

  /// Public method kept as void for compatibility with current button callbacks.
  void cancelTrip() {
    unawaited(_cancelTripInternal());
  }

  Future<void> _cancelTripInternal() async {
    if (isLoading) return;

    clearMessages();

    isLoading = true;
    _safeNotify();

    try {
      _stopCountdown();
      await _trackingService.stopTracking();

      final trip = currentTrip;

      final currentUser = _authService.currentUser;

      if (trip == null && currentUser != null) {
        final cleanupResult = await _repository.cancelOpenTripsForUser(
          userId: currentUser.uid,
          reason: 'user_cancelled_without_loaded_trip',
        );

        if (cleanupResult.isFailure) {
          errorMessage = _friendlyRepositoryError(cleanupResult.error);
          return;
        }

        _resetTripUiState();
        successMessage = 'تم إلغاء أي رحلة وصول آمن مفتوحة.';
        return;
      }

      if (trip != null && !trip.isClosed) {
        final result = await _repository.cancelTrip(
          tripId: trip.id,
          reason: 'user_cancelled',
        );

        if (result.isFailure) {
          errorMessage = _friendlyRepositoryError(result.error);
          return;
        }

        final cancelledTrip = trip.copyWith(
          status: SafeArrivalTripStatus.cancelled,
          cancelledAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        _notifySafeArrivalCancelled(cancelledTrip);
      }

      _resetTripUiState();
      successMessage = 'تم إلغاء رحلة الوصول الآمن.';
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalViewModel: cancel trip failed - $e');
      debugPrintStack(stackTrace: stackTrace);
      errorMessage = 'حدث خطأ أثناء إلغاء الرحلة.';
    } finally {
      isLoading = false;
      _safeNotify();
    }
  }

  // ==========================================
  // 📱 WhatsApp
  // ==========================================

  Future<void> shareArrivalUpdate() async {
    if (isSharingWhatsApp) return;

    clearMessages();

    final trip = currentTrip;

    if (trip == null || currentState != SafeArrivalState.arrived) {
      errorMessage = 'لا توجد رحلة وصول مكتملة لمشاركتها.';
      _safeNotify();
      return;
    }

    isSharingWhatsApp = true;
    _safeNotify();

    try {
      final message = _whatsappShareService.buildArrivalMessage(
        trip: trip,
        userName: userName,
      );

      final result = await _whatsappShareService.openPreparedMessage(
        message: message,
      );

      if (result.isFailure) {
        errorMessage = _friendlyWhatsAppError(result.error);
        return;
      }

      final updateResult = await _repository.markFamilyNotified(
        tripId: trip.id,
        whatsappMessage: message,
      );

      if (updateResult.isFailure) {
        warningMessage =
            'تم فتح WhatsApp، لكن تعذر تحديث حالة الإشعار في السحابة.';
        debugPrint(
          '⚠️ SafeArrivalViewModel: family notified sync failed - ${updateResult.error}',
        );
      }

      currentTrip = trip.copyWith(
        whatsappMessage: message,
        familyNotifiedAt: DateTime.now(),
      );

      successMessage = 'تم فتح WhatsApp برسالة الطمأنة.';
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalViewModel: shareArrivalUpdate failed - $e');
      debugPrintStack(stackTrace: stackTrace);
      errorMessage = 'حدث خطأ أثناء فتح WhatsApp.';
    } finally {
      isSharingWhatsApp = false;
      _safeNotify();
    }
  }

  // ==========================================
  // 📊 Current UI helpers
  // ==========================================

  String getTripDuration() {
    final seconds = currentTrip?.elapsedSeconds;

    if (seconds != null) {
      return _formatElapsedSeconds(seconds);
    }

    final start = _tripStartTime;

    if (start == null) return '--';

    final elapsed = DateTime.now().difference(start);

    if (elapsed.inSeconds < 60) {
      return 'أقل من دقيقة';
    }

    return _formatElapsedSeconds(elapsed.inSeconds);
  }

  String getTripDistance() {
    final meters =
        currentTrip?.actualDistanceMeters ??
        latestTrackingUpdate?.actualDistanceMeters ??
        0.0;

    return _formatDistance(meters);
  }

  // ==========================================
  // ⏱️ Countdown
  // ==========================================

  void _startCountdown() {
    _stopCountdown();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingSeconds > 0) {
        remainingSeconds--;
        _safeNotify();
        return;
      }

      _stopCountdown();

      warningMessage =
          'انتهى الوقت المتوقع. سيتم تفعيل الخطر إذا تجاوزت الرحلة فترة السماح.';
      _safeNotify();
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  // ==========================================
  // 🧹 Helpers
  // ==========================================

  void _resetTripUiState() {
    currentState = SafeArrivalState.setup;
    remainingSeconds = 0;

    currentTrip = null;
    latestTrackingUpdate = null;
    latestReport = null;

    _tripStartTime = null;
    _lastCloudSyncAt = null;

    destinationController.clear();

    selectedDestination = null;
    destinationPredictions = const <SafeArrivalPlacePrediction>[];
    routePreview = null;
  }

  bool _markSafeArrivalNotificationSent(String key) {
    final safeKey = _cleanText(key);

    if (safeKey.isEmpty) return false;
    if (_sentSafeArrivalNotificationKeys.contains(safeKey)) return false;

    _sentSafeArrivalNotificationKeys.add(safeKey);
    return true;
  }

  void _dispatchSafeArrivalNotification({
    required String key,
    required Future<dynamic> Function() send,
  }) {
    if (!_markSafeArrivalNotificationSent(key)) return;

    unawaited(
      send().then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          debugPrint(
            '⚠️ SafeArrivalViewModel: Safe Arrival notification failed ($key) - $error',
          );
          debugPrintStack(stackTrace: stackTrace);
        },
      ),
    );
  }

  void _notifySafeArrivalStarted(SafeArrivalTripModel trip) {
    final uid = _authService.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return;

    _dispatchSafeArrivalNotification(
      key: 'safe-arrival-started-${trip.id}',
      send: () =>
          _safeArrivalNotificationService.notifyStarted(uid: uid, trip: trip),
    );
  }

  void _notifySafeArrivalPaused(SafeArrivalTripModel trip) {
    final uid = _authService.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return;

    _dispatchSafeArrivalNotification(
      key: 'safe-arrival-paused-${trip.id}',
      send: () =>
          _safeArrivalNotificationService.notifyPaused(uid: uid, trip: trip),
    );
  }

  void _notifySafeArrivalResumed(SafeArrivalTripModel trip) {
    final uid = _authService.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return;

    _dispatchSafeArrivalNotification(
      key: 'safe-arrival-resumed-${trip.id}',
      send: () =>
          _safeArrivalNotificationService.notifyResumed(uid: uid, trip: trip),
    );
  }

  void _notifySafeArrivalNearDestination({
    required SafeArrivalTripModel trip,
    double? distanceToDestinationMeters,
  }) {
    final uid = _authService.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return;

    _dispatchSafeArrivalNotification(
      key: 'safe-arrival-near-${trip.id}',
      send: () => _safeArrivalNotificationService.notifyNearDestination(
        uid: uid,
        trip: trip,
        distanceToDestinationMeters: distanceToDestinationMeters,
      ),
    );
  }

  void _notifySafeArrivalArrived(SafeArrivalTripModel trip) {
    final uid = _authService.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return;

    _dispatchSafeArrivalNotification(
      key: 'safe-arrival-arrived-${trip.id}',
      send: () =>
          _safeArrivalNotificationService.notifyArrived(uid: uid, trip: trip),
    );
  }

  void _notifySafeArrivalCancelled(SafeArrivalTripModel trip) {
    final uid = _authService.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return;

    _dispatchSafeArrivalNotification(
      key: 'safe-arrival-cancelled-${trip.id}',
      send: () =>
          _safeArrivalNotificationService.notifyCancelled(uid: uid, trip: trip),
    );
  }

  void _notifySafeArrivalDanger({
    required SafeArrivalTripModel trip,
    String? reasonCode,
  }) {
    final uid = _authService.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return;

    _dispatchSafeArrivalNotification(
      key: 'safe-arrival-danger-${trip.id}',
      send: () => _safeArrivalNotificationService.notifyDanger(
        uid: uid,
        trip: trip,
        reasonCode: reasonCode,
      ),
    );
  }

  void clearMessages() {
    errorMessage = '';
    successMessage = '';
    warningMessage = '';
  }

  String _friendlyRepositoryError(SafeArrivalRepositoryException? error) {
    switch (error?.code) {
      case 'active-trip-already-exists':
        return 'لديك رحلة وصول آمن نشطة بالفعل.';
      case 'invalid-destination':
        return 'يرجى اختيار وجهة صحيحة من نتائج البحث.';
      case 'invalid-user-id':
        return 'يرجى تسجيل الدخول مرة أخرى.';
      case 'contacts-load-timeout':
      case 'contacts-load-failed':
        return 'تعذر تحميل جهات الطوارئ حالياً.';
      case 'trip-create-timeout':
      case 'trip-start-timeout':
        return 'استغرق بدء الرحلة وقتاً طويلاً. تحقق من الاتصال وحاول مجدداً.';
      case 'trip-pause-timeout':
      case 'trip-pause-failed':
        return 'تعذر إيقاف التتبع مؤقتًا. حاول مرة أخرى.';
      case 'trip-resume-timeout':
      case 'trip-resume-failed':
        return 'تعذر استئناف التتبع. حاول مرة أخرى.';
      case 'manual-finish-timeout':
      case 'manual-finish-failed':
        return 'تعذر إنهاء الرحلة يدويًا. حاول مرة أخرى.';
      case 'open-trips-cancel-timeout':
      case 'open-trips-cancel-failed':
        return 'تعذر إلغاء الرحلات المفتوحة. حاول مرة أخرى.';
      default:
        return 'حدث خطأ أثناء مزامنة رحلة الوصول الآمن.';
    }
  }

  String _friendlyTrackingError(SafeArrivalTrackingException? error) {
    switch (error?.code) {
      case 'current-location-failed':
        return 'تعذر الحصول على موقعك الحالي. تحقق من GPS والصلاحيات.';
      case 'tracking-start-failed':
        return 'تعذر بدء تتبع GPS.';
      case 'invalid-destination':
        return 'الوجهة المختارة غير صالحة.';
      case 'tracking-already-active':
        return 'يوجد تتبع وصول آمن نشط بالفعل.';
      default:
        return 'حدث خطأ أثناء تشغيل التتبع.';
    }
  }

  String _friendlyPlacesError(SafeArrivalPlacesException? error) {
    switch (error?.code) {
      case 'missing-api-key':
        return 'مفتاح خرائط Google غير مفعّل للتطبيق.';
      case 'places-search-timeout':
      case 'place-details-timeout':
        return 'استغرق البحث عن الوجهة وقتاً طويلاً.';
      case 'places-status-request_denied':
      case 'place-details-status-request_denied':
        return 'خدمة Google Places غير مفعّلة أو المفتاح غير مصرح.';
      case 'invalid-prediction':
      case 'invalid-resolved-destination':
      case 'invalid-place-coordinates':
        return 'الوجهة المختارة غير صالحة.';
      default:
        return 'تعذر البحث عن الوجهة حالياً.';
    }
  }

  String _friendlyRouteError(SafeArrivalRouteException? error) {
    switch (error?.code) {
      case 'missing-api-key':
        return 'مفتاح خرائط Google غير مفعّل للتطبيق.';
      case 'route-preview-timeout':
        return 'استغرق تجهيز المسار وقتاً طويلاً.';
      case 'directions-status-request_denied':
        return 'خدمة Directions API غير مفعّلة أو المفتاح غير مصرح.';
      case 'directions-status-zero_results':
      case 'route-not-found':
        return 'تعذر العثور على مسار مناسب لهذه الوجهة.';
      case 'invalid-origin':
        return 'تعذر تحديد موقع البداية.';
      case 'invalid-destination':
        return 'الوجهة المختارة غير صالحة.';
      default:
        return 'تعذر تجهيز مسار الرحلة حالياً.';
    }
  }

  String _friendlyWhatsAppError(WhatsAppShareException? error) {
    switch (error?.code) {
      case 'invalid-message':
        return 'تعذر تجهيز رسالة WhatsApp.';
      case 'whatsapp-unavailable':
        return 'لا يمكن فتح WhatsApp على هذا الجهاز.';
      case 'whatsapp-launch-failed':
        return 'فشل فتح WhatsApp.';
      default:
        return 'حدث خطأ أثناء فتح WhatsApp.';
    }
  }

  String _friendlyTrackingWarning(SafeArrivalTrackingWarning warning) {
    switch (warning.code) {
      case SafeArrivalTrackingWarningCode.weakGps:
        return 'إشارة GPS ضعيفة حالياً.';
      case SafeArrivalTrackingWarningCode.poorAccuracy:
        return 'دقة الموقع ضعيفة، قد يتأخر تأكيد الوصول.';
      case SafeArrivalTrackingWarningCode.nearDestination:
        return 'أنت قريب من الوجهة.';
      case SafeArrivalTrackingWarningCode.longStop:
        return 'يبدو أنك متوقف منذ فترة أثناء الرحلة.';
      case SafeArrivalTrackingWarningCode.invalidGpsReading:
        return '';
      case SafeArrivalTrackingWarningCode.processingError:
        return '';
    }
  }

  int? _calculateDynamicEtaSeconds(SafeArrivalTrackingUpdate update) {
    final remainingMeters = update.distanceToDestinationMeters;

    if (remainingMeters.isNaN ||
        remainingMeters.isInfinite ||
        remainingMeters < 0) {
      return null;
    }

    if (remainingMeters <= AppThresholds.safeArrivalRadiusMeters) {
      return 0;
    }

    final speedKmh = update.speedKmh;

    if (AppThresholds.isValidSpeed(speedKmh) && speedKmh >= 5.0) {
      final metersPerSecond = speedKmh / 3.6;

      if (metersPerSecond > 0) {
        final eta = (remainingMeters / metersPerSecond).ceil();

        if (eta >= 0) {
          return eta;
        }
      }
    }

    if (remainingSeconds > 0) {
      return remainingSeconds;
    }

    final tripEta = currentTrip?.estimatedArrivalAt;
    if (tripEta != null) {
      final seconds = tripEta.difference(DateTime.now()).inSeconds;
      return seconds < 0 ? 0 : seconds;
    }

    return routePreview?.durationSeconds;
  }

  String _formatElapsedSeconds(int seconds) {
    if (seconds < 60) return 'أقل من دقيقة';

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0 && minutes > 0) {
      return '$hours ساعة و $minutes دقيقة';
    }

    if (hours > 0) {
      return '$hours ساعة';
    }

    return '$minutes دقيقة';
  }

  String _formatDistance(double meters) {
    final safeMeters = meters.isNaN || meters.isInfinite || meters < 0.0
        ? 0.0
        : meters;

    if (safeMeters < 1000) {
      return '${safeMeters.toStringAsFixed(0)} م';
    }

    return '${(safeMeters / 1000).toStringAsFixed(2)} كم';
  }

  String _cleanText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    destinationController.removeListener(_handleDestinationTextChanged);

    _destinationSearchDebounce?.cancel();
    _stopCountdown();

    unawaited(_trackingService.dispose());

    if (_ownsPlacesService) {
      _placesService.dispose();
    }

    if (_ownsRouteService) {
      _routeService.dispose();
    }

    destinationController.dispose();

    super.dispose();
  }
}
