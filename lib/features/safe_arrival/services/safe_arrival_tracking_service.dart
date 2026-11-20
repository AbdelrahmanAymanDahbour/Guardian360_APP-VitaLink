import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/app_thresholds.dart';
import '../../../core/services/geocoding_service.dart';
import '../../../core/services/gps_location_service.dart';
import '../models/safe_arrival_destination_model.dart';
import '../models/safe_arrival_report_model.dart';

/// ==========================================
/// 🛰️ Safe Arrival Tracking Service
/// ==========================================
/// High-level tracking logic for the Safe Arrival feature.
///
/// Responsibilities:
/// - Start/stop live GPS tracking.
/// - Calculate actual travelled distance.
/// - Calculate distance to trusted destination.
/// - Detect real arrival using stable GPS readings.
/// - Detect weak GPS tracking.
/// - Detect long stops.
/// - Emit tracking updates/warnings/danger events.
///
/// Not responsible for:
/// - Firestore writes.
/// - UI state.
/// - Google Places search.
/// - WhatsApp launch.
/// - Accident detection.
///
/// Important:
/// Route deviation is intentionally not guessed here. Accurate route deviation
/// requires a route polyline from Google Routes API, which will be added later.
class SafeArrivalTrackingService {
  SafeArrivalTrackingService({
    GPSLocationService? gpsService,
    GeocodingService? geocodingService,
  }) : _gpsService = gpsService ?? GPSLocationService(),
       _geocodingService = geocodingService ?? GeocodingService();

  final GPSLocationService _gpsService;
  final GeocodingService _geocodingService;

  String? _tripId;
  SafeArrivalDestinationModel? _destination;

  DateTime? _startedAt;
  DateTime? _estimatedArrivalAt;
  DateTime? _lastLocationUpdateAt;
  DateTime? _stationarySince;
  DateTime? _lastProgressAt;
  double? _bestDistanceToDestinationMeters;

  Position? _lastPosition;

  double _actualDistanceMeters = 0.0;
  double? _distanceToDestinationMeters;

  double _speedSumKmh = 0.0;
  int _speedSamples = 0;
  double _maxSpeedKmh = 0.0;

  int _stableArrivalReadings = 0;
  int _weakGpsEvents = 0;
  int _longStopEvents = 0;
  int _routeDeviationEvents = 0;

  bool _isTracking = false;
  bool _arrivalEmitted = false;
  bool _dangerEmitted = false;
  bool _weakGpsEpisodeActive = false;
  bool _longStopEpisodeActive = false;
  bool _nearDestinationEpisodeActive = false;

  Timer? _healthTimer;

  void Function(SafeArrivalTrackingUpdate update)? _onUpdate;
  void Function(SafeArrivalArrivalResult result)? _onArrived;
  void Function(SafeArrivalDangerEvent event)? _onDanger;
  void Function(SafeArrivalTrackingWarning warning)? _onWarning;

  bool get isTracking => _isTracking;

  String? get currentTripId => _tripId;

  double get actualDistanceMeters => _actualDistanceMeters;

  double? get distanceToDestinationMeters => _distanceToDestinationMeters;

  int get weakGpsEvents => _weakGpsEvents;

  int get longStopEvents => _longStopEvents;

  int get routeDeviationEvents => _routeDeviationEvents;

  Position? get lastPosition => _lastPosition;

  // ==========================================
  // 🚀 Start / Stop
  // ==========================================

  Future<SafeArrivalTrackingResult<SafeArrivalTrackingUpdate>> startTracking({
    required String tripId,
    required SafeArrivalDestinationModel destination,
    DateTime? estimatedArrivalAt,
    int? estimatedDurationSeconds,
    void Function(SafeArrivalTrackingUpdate update)? onUpdate,
    void Function(SafeArrivalArrivalResult result)? onArrived,
    void Function(SafeArrivalDangerEvent event)? onDanger,
    void Function(SafeArrivalTrackingWarning warning)? onWarning,
  }) async {
    try {
      final safeTripId = _cleanText(tripId);

      if (safeTripId.isEmpty) {
        return SafeArrivalTrackingResult.failure(
          SafeArrivalTrackingException(
            message: 'Trip ID is required',
            code: 'invalid-trip-id',
          ),
        );
      }

      if (!destination.isValid) {
        return SafeArrivalTrackingResult.failure(
          SafeArrivalTrackingException(
            message: 'Trusted destination is required',
            code: 'invalid-destination',
          ),
        );
      }

      if (_isTracking) {
        return SafeArrivalTrackingResult.failure(
          SafeArrivalTrackingException(
            message: 'Safe Arrival tracking is already active',
            code: 'tracking-already-active',
          ),
        );
      }

      _resetInternalState();

      _tripId = safeTripId;
      _destination = destination;

      final now = DateTime.now();
      _startedAt = now;

      _estimatedArrivalAt =
          estimatedArrivalAt ??
          (estimatedDurationSeconds != null && estimatedDurationSeconds > 0
              ? now.add(Duration(seconds: estimatedDurationSeconds))
              : null);

      _onUpdate = onUpdate;
      _onArrived = onArrived;
      _onDanger = onDanger;
      _onWarning = onWarning;

      final positionResult = await _gpsService.getCurrentPosition(
        accuracy: LocationAccuracy.high,
      );

      if (positionResult.isFailure || positionResult.data == null) {
        _resetInternalState();

        return SafeArrivalTrackingResult.failure(
          SafeArrivalTrackingException(
            message: 'Failed to get current location',
            code: 'current-location-failed',
            originalError: positionResult.error,
          ),
        );
      }

      final startPosition = positionResult.data!;

      final trackingResult = await _gpsService.startLocationTracking(
        accuracy: LocationAccuracy.high,
        distanceFilter: AppThresholds.safeArrivalTrackingDistanceFilterMeters,
        interval: const Duration(
          seconds: AppThresholds.safeArrivalLocationUpdateSeconds,
        ),
      );

      if (trackingResult.isFailure) {
        await stopTracking();
        _resetInternalState();

        return SafeArrivalTrackingResult.failure(
          SafeArrivalTrackingException(
            message: 'Failed to start GPS tracking',
            code: 'tracking-start-failed',
            originalError: trackingResult.error,
          ),
        );
      }

      _gpsService.addLocationListener(_handlePositionUpdate);
      _startHealthTimer();

      _isTracking = true;

      final initialUpdate = _buildUpdateFromPosition(startPosition);
      _emitUpdate(initialUpdate);

      debugPrint(
        '✅ SafeArrivalTrackingService: tracking started - $safeTripId',
      );

      return SafeArrivalTrackingResult.success(initialUpdate);
    } catch (e, stackTrace) {
      await stopTracking();
      _resetInternalState();

      debugPrint('❌ SafeArrivalTrackingService: startTracking failed - $e');
      return SafeArrivalTrackingResult.failure(
        SafeArrivalTrackingException(
          message: 'Failed to start Safe Arrival tracking',
          code: 'tracking-start-exception',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> stopTracking() async {
    try {
      _healthTimer?.cancel();
      _healthTimer = null;

      _gpsService.removeLocationListener(_handlePositionUpdate);
      await _gpsService.stopLocationTracking();
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalTrackingService: stopTracking failed - $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isTracking = false;
      debugPrint('🛑 SafeArrivalTrackingService: tracking stopped');
    }
  }

  Future<void> dispose() async {
    await stopTracking();
    _resetInternalState();
    debugPrint('🧹 SafeArrivalTrackingService: disposed');
  }

  // ==========================================
  // 📍 Location Processing
  // ==========================================

  void _handlePositionUpdate(Position position) {
    unawaited(_processPositionUpdate(position));
  }

  Future<void> _processPositionUpdate(Position position) async {
    if (!_isTracking || _tripId == null || _destination == null) return;

    try {
      if (!_isUsablePosition(position)) {
        _emitWarning(
          SafeArrivalTrackingWarning(
            code: SafeArrivalTrackingWarningCode.invalidGpsReading,
            message: 'Invalid GPS reading ignored',
            createdAt: DateTime.now(),
          ),
        );
        return;
      }

      final update = _buildUpdateFromPosition(position);
      _emitUpdate(update);

      _checkNearDestination(update);
      _checkArrival(update);
      _checkLongStop(update);
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalTrackingService: update processing failed - $e');
      debugPrintStack(stackTrace: stackTrace);

      _emitWarning(
        SafeArrivalTrackingWarning(
          code: SafeArrivalTrackingWarningCode.processingError,
          message: 'Failed to process GPS update',
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  SafeArrivalTrackingUpdate _buildUpdateFromPosition(Position position) {
    final now = DateTime.now();
    final destination = _destination!;

    final previous = _lastPosition;
    final previousUpdateAt = _lastLocationUpdateAt;

    if (previous != null) {
      final segmentDistance = _gpsService.calculateDistance(
        startLatitude: previous.latitude,
        startLongitude: previous.longitude,
        endLatitude: position.latitude,
        endLongitude: position.longitude,
      );

      final elapsedSeconds = previousUpdateAt == null
          ? null
          : now.difference(previousUpdateAt).inSeconds;

      final shouldCountSegment = _shouldCountTravelSegment(
        distanceMeters: segmentDistance,
        previous: previous,
        current: position,
        elapsedSeconds: elapsedSeconds,
      );

      if (shouldCountSegment) {
        _actualDistanceMeters += segmentDistance;
      }
    }

    final distanceToDestination = _gpsService.calculateDistance(
      startLatitude: position.latitude,
      startLongitude: position.longitude,
      endLatitude: destination.latitude,
      endLongitude: destination.longitude,
    );

    _registerDestinationProgress(distanceToDestination, now);

    final speedKmh = _gpsService.calculateSpeed(position);

    if (_isValidSpeed(speedKmh)) {
      _speedSumKmh += speedKmh;
      _speedSamples++;

      if (speedKmh > _maxSpeedKmh) {
        _maxSpeedKmh = speedKmh;
      }
    }

    _lastPosition = position;
    _lastLocationUpdateAt = now;
    _distanceToDestinationMeters = distanceToDestination;

    final isAccuracyAcceptable =
        position.accuracy <= AppThresholds.safeArrivalMaxAccuracyMeters;

    final isInsideArrivalRadius =
        distanceToDestination <= AppThresholds.safeArrivalRadiusMeters;

    final isNearDestination =
        distanceToDestination <= AppThresholds.safeArrivalNearDestinationMeters;

    if (isAccuracyAcceptable && isInsideArrivalRadius) {
      _stableArrivalReadings++;
    } else if (!isInsideArrivalRadius) {
      _stableArrivalReadings = 0;
    }

    if (position.accuracy > AppThresholds.safeArrivalMaxAccuracyMeters) {
      _registerWeakGps(
        SafeArrivalTrackingWarningCode.poorAccuracy,
        'GPS accuracy is weaker than the Safe Arrival threshold',
      );
    } else {
      _weakGpsEpisodeActive = false;
    }

    return SafeArrivalTrackingUpdate(
      tripId: _tripId!,
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      speedKmh: speedKmh,
      actualDistanceMeters: _actualDistanceMeters,
      distanceToDestinationMeters: distanceToDestination,
      isInsideArrivalRadius: isInsideArrivalRadius,
      isNearDestination: isNearDestination,
      isAccuracyAcceptable: isAccuracyAcceptable,
      stableArrivalReadings: _stableArrivalReadings,
      requiredStableArrivalReadings:
          AppThresholds.safeArrivalRequiredStableReadings,
      weakGpsEvents: _weakGpsEvents,
      longStopEvents: _longStopEvents,
      routeDeviationEvents: _routeDeviationEvents,
      createdAt: now,
    );
  }

  void _checkNearDestination(SafeArrivalTrackingUpdate update) {
    if (_arrivalEmitted || _dangerEmitted) return;

    if (!update.isNearDestination) {
      _nearDestinationEpisodeActive = false;
      return;
    }

    if (update.isInsideArrivalRadius || _nearDestinationEpisodeActive) {
      return;
    }

    _nearDestinationEpisodeActive = true;

    _emitWarning(
      SafeArrivalTrackingWarning(
        code: SafeArrivalTrackingWarningCode.nearDestination,
        message: 'User is near the Safe Arrival destination',
        createdAt: DateTime.now(),
      ),
    );
  }

  void _checkArrival(SafeArrivalTrackingUpdate update) {
    if (_arrivalEmitted || _dangerEmitted) return;

    final hasStableArrival =
        update.stableArrivalReadings >=
        AppThresholds.safeArrivalRequiredStableReadings;

    if (!hasStableArrival) return;

    _arrivalEmitted = true;

    final report = buildReport(arrived: true);

    final result = SafeArrivalArrivalResult(
      tripId: update.tripId,
      latitude: update.latitude,
      longitude: update.longitude,
      actualDistanceMeters: update.actualDistanceMeters,
      distanceToDestinationMeters: update.distanceToDestinationMeters,
      report: report,
      arrivedAt: DateTime.now(),
    );

    debugPrint(
      '✅ SafeArrivalTrackingService: arrival detected - ${update.tripId}',
    );

    _onArrived?.call(result);
  }

  void _checkLongStop(SafeArrivalTrackingUpdate update) {
    if (_arrivalEmitted || _dangerEmitted) return;

    if (update.isNearDestination) {
      _stationarySince = null;
      _longStopEpisodeActive = false;
      return;
    }

    final isNearlyStopped = update.speedKmh <= 2.0;

    if (!isNearlyStopped) {
      _stationarySince = null;
      _longStopEpisodeActive = false;
      return;
    }

    _stationarySince ??= update.createdAt;

    final stationaryDuration = update.createdAt.difference(_stationarySince!);

    if (stationaryDuration.inMinutes >=
            AppThresholds.safeArrivalLongStopMinutes &&
        !_longStopEpisodeActive) {
      _longStopEpisodeActive = true;
      _longStopEvents++;

      _emitWarning(
        SafeArrivalTrackingWarning(
          code: SafeArrivalTrackingWarningCode.longStop,
          message: 'Long stop detected during Safe Arrival trip',
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  // ==========================================
  // 🩺 Tracking Health / Delay
  // ==========================================

  void _startHealthTimer() {
    _healthTimer?.cancel();

    _healthTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkTrackingHealth(),
    );
  }

  void _checkTrackingHealth() {
    if (!_isTracking || _tripId == null) return;
    if (_arrivalEmitted || _dangerEmitted) return;

    final now = DateTime.now();

    final lastUpdate = _lastLocationUpdateAt;
    if (lastUpdate != null) {
      final secondsSinceLastUpdate = now.difference(lastUpdate).inSeconds;

      if (secondsSinceLastUpdate >= AppThresholds.safeArrivalWeakGpsSeconds) {
        _registerWeakGps(
          SafeArrivalTrackingWarningCode.weakGps,
          'No GPS update received within the Safe Arrival health window',
        );
      }
    }

    final eta = _estimatedArrivalAt;
    if (eta != null) {
      final dangerAt = eta.add(
        const Duration(minutes: AppThresholds.safeArrivalDelayGraceMinutes),
      );

      if (!now.isAfter(dangerAt)) return;

      final distance = _distanceToDestinationMeters;

      final isNearDestination =
          distance != null &&
          distance <= AppThresholds.safeArrivalNearDestinationMeters;

      if (isNearDestination) return;

      final lastProgress = _lastProgressAt;
      final hasRecentProgress =
          lastProgress != null &&
          now.difference(lastProgress).inMinutes <
              AppThresholds.safeArrivalNoProgressDangerMinutes;

      if (hasRecentProgress) return;

      _emitDangerOnce(
        reasonCode: SafeArrivalDangerReason.delayed.value,
        message: 'Safe Arrival trip exceeded ETA without recent progress',
      );
    }
  }

  void _registerWeakGps(SafeArrivalTrackingWarningCode code, String message) {
    if (_weakGpsEpisodeActive) return;

    _weakGpsEpisodeActive = true;
    _weakGpsEvents++;

    _emitWarning(
      SafeArrivalTrackingWarning(
        code: code,
        message: message,
        createdAt: DateTime.now(),
      ),
    );
  }

  void _emitDangerOnce({required String reasonCode, required String message}) {
    if (_dangerEmitted || _arrivalEmitted) return;

    _dangerEmitted = true;

    final position = _lastPosition;

    final event = SafeArrivalDangerEvent(
      tripId: _tripId!,
      reasonCode: reasonCode,
      message: message,
      latitude: position?.latitude,
      longitude: position?.longitude,
      actualDistanceMeters: _actualDistanceMeters,
      distanceToDestinationMeters: _distanceToDestinationMeters,
      report: buildReport(arrived: false),
      createdAt: DateTime.now(),
    );

    debugPrint(
      '🚨 SafeArrivalTrackingService: danger emitted - '
      '${event.tripId}, reason=${event.reasonCode}',
    );

    _onDanger?.call(event);
  }

  // ==========================================
  // 🧠 Report / Address
  // ==========================================

  SafeArrivalReportModel buildReport({required bool arrived}) {
    final arrivedOnTime = _isArrivedOnTime();

    var score = 100.0;

    if (!arrived) score -= 25.0;
    if (!arrivedOnTime) score -= 10.0;

    score -= (_weakGpsEvents * 5.0).clamp(0.0, 15.0);
    score -= (_longStopEvents * 10.0).clamp(0.0, 20.0);
    score -= (_routeDeviationEvents * 10.0).clamp(0.0, 20.0);

    score = score.clamp(0.0, 100.0).toDouble();

    return SafeArrivalReportModel.create(
      safetyScore: score,
      guardianReport: _buildGuardianReportText(
        arrived: arrived,
        arrivedOnTime: arrivedOnTime,
      ),
      arrivedOnTime: arrivedOnTime,
      hadLongStop: _longStopEvents > 0,
      hadWeakGps: _weakGpsEvents > 0,
      hadRouteDeviation: _routeDeviationEvents > 0,
      weakGpsEvents: _weakGpsEvents,
      longStopEvents: _longStopEvents,
      routeDeviationEvents: _routeDeviationEvents,
      averageSpeedKmh: _averageSpeedKmh,
      maxSpeedKmh: _maxSpeedKmh,
      actualDistanceMeters: _actualDistanceMeters,
      createdAt: DateTime.now(),
    );
  }

  Future<String> resolveAddressForLastPosition() async {
    final position = _lastPosition;

    if (position == null) return '';

    try {
      return await _geocodingService.getAddressFromCoordinates(
        LatLng(position.latitude, position.longitude),
      );
    } catch (e) {
      debugPrint('⚠️ SafeArrivalTrackingService: address resolve failed - $e');
      return '';
    }
  }

  bool _isArrivedOnTime() {
    final eta = _estimatedArrivalAt;

    if (eta == null) return true;

    final now = DateTime.now();
    final graceEta = eta.add(
      const Duration(minutes: AppThresholds.safeArrivalDelayGraceMinutes),
    );

    return now.isBefore(graceEta) || now.isAtSameMomentAs(graceEta);
  }

  String _buildGuardianReportText({
    required bool arrived,
    required bool arrivedOnTime,
  }) {
    final parts = <String>[];

    if (arrived) {
      parts.add('تم الوصول بنجاح إلى الوجهة المحددة.');
    } else {
      parts.add('لم يتم تأكيد الوصول الآمن ضمن الوقت المتوقع.');
    }

    if (arrivedOnTime) {
      parts.add('لم يتم تجاوز وقت الوصول المتوقع بشكل مقلق.');
    } else {
      parts.add('تم رصد تأخير بعد وقت الوصول المتوقع وفترة السماح.');
    }

    if (_longStopEvents > 0) {
      parts.add('تم رصد توقف طويل أثناء الرحلة.');
    } else {
      parts.add('لم يتم رصد توقف طويل مؤثر أثناء الرحلة.');
    }

    if (_weakGpsEvents > 0) {
      parts.add('حدث ضعف في جودة تتبع GPS خلال الرحلة.');
    } else {
      parts.add('كانت جودة تتبع الموقع مستقرة بشكل عام.');
    }

    if (_routeDeviationEvents > 0) {
      parts.add('تم رصد انحراف محتمل عن المسار.');
    }

    final elapsedText = _formatElapsedTripDuration();
    if (elapsedText.isNotEmpty) {
      parts.add(elapsedText);
    }

    parts.add(
      'المسافة المسجلة تقريبياً: ${(_actualDistanceMeters / 1000).toStringAsFixed(2)} كم.',
    );

    final text = parts.join(' ');

    if (text.length <= AppThresholds.safeArrivalMaxGuardianReportLength) {
      return text;
    }

    return text.substring(0, AppThresholds.safeArrivalMaxGuardianReportLength);
  }

  String _formatElapsedTripDuration() {
    final start = _startedAt;

    if (start == null) {
      return '';
    }

    final elapsed = DateTime.now().difference(start);

    if (elapsed.inSeconds < 60) {
      return 'مدة الرحلة أقل من دقيقة.';
    }

    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);

    if (hours > 0 && minutes > 0) {
      return 'مدة الرحلة المسجلة: $hours ساعة و $minutes دقيقة.';
    }

    if (hours > 0) {
      return 'مدة الرحلة المسجلة: $hours ساعة.';
    }

    return 'مدة الرحلة المسجلة: ${elapsed.inMinutes} دقيقة.';
  }

  // ==========================================
  // Emitters
  // ==========================================

  void _emitUpdate(SafeArrivalTrackingUpdate update) {
    _onUpdate?.call(update);
  }

  void _emitWarning(SafeArrivalTrackingWarning warning) {
    debugPrint(
      '⚠️ SafeArrivalTrackingService warning: '
      '${warning.code.value} - ${warning.message}',
    );

    _onWarning?.call(warning);
  }

  // ==========================================
  // Helpers
  // ==========================================

  double? get _averageSpeedKmh {
    if (_speedSamples <= 0) return null;
    return _speedSumKmh / _speedSamples;
  }

  bool _isUsablePosition(Position position) {
    return _hasValidCoordinates(position.latitude, position.longitude) &&
        !position.accuracy.isNaN &&
        !position.accuracy.isInfinite &&
        position.accuracy >= 0.0;
  }

  bool _hasValidCoordinates(double latitude, double longitude) {
    return !latitude.isNaN &&
        !latitude.isInfinite &&
        !longitude.isNaN &&
        !longitude.isInfinite &&
        latitude >= -90.0 &&
        latitude <= 90.0 &&
        longitude >= -180.0 &&
        longitude <= 180.0 &&
        !(latitude == 0.0 && longitude == 0.0);
  }

  bool _isValidDistance(double value) {
    return !value.isNaN && !value.isInfinite && value >= 0.0;
  }

  bool _isValidSpeed(double value) {
    return !value.isNaN &&
        !value.isInfinite &&
        value >= 0.0 &&
        value <= AppThresholds.maxReasonableSpeedKmh;
  }

  bool _shouldCountTravelSegment({
    required double distanceMeters,
    required Position previous,
    required Position current,
    required int? elapsedSeconds,
  }) {
    if (!_isValidDistance(distanceMeters)) return false;

    if (distanceMeters < AppThresholds.safeArrivalMinMovementSegmentMeters) {
      return false;
    }

    final bothReadingsWeak =
        previous.accuracy > AppThresholds.safeArrivalMaxAccuracyMeters &&
        current.accuracy > AppThresholds.safeArrivalMaxAccuracyMeters;

    if (bothReadingsWeak) return false;

    if (elapsedSeconds == null || elapsedSeconds <= 0) {
      return distanceMeters <=
          AppThresholds.safeArrivalFallbackMaxSegmentMeters;
    }

    final maxExpectedBySpeed =
        (AppThresholds.maxReasonableSpeedKmh / 3.6) * elapsedSeconds;

    final allowedDistance =
        maxExpectedBySpeed +
        previous.accuracy +
        current.accuracy +
        AppThresholds.safeArrivalGpsJumpAccuracyBufferMeters;

    return distanceMeters <= allowedDistance;
  }

  void _registerDestinationProgress(
    double distanceToDestination,
    DateTime now,
  ) {
    if (!_isValidDistance(distanceToDestination)) return;

    final bestDistance = _bestDistanceToDestinationMeters;

    if (bestDistance == null) {
      _bestDistanceToDestinationMeters = distanceToDestination;
      _lastProgressAt = now;
      return;
    }

    final improvedBy = bestDistance - distanceToDestination;

    if (improvedBy >= AppThresholds.safeArrivalProgressThresholdMeters) {
      _bestDistanceToDestinationMeters = distanceToDestination;
      _lastProgressAt = now;
      return;
    }

    if (distanceToDestination < bestDistance) {
      _bestDistanceToDestinationMeters = distanceToDestination;
    }
  }

  String _cleanText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  void _resetInternalState() {
    _tripId = null;
    _destination = null;

    _startedAt = null;
    _estimatedArrivalAt = null;
    _lastLocationUpdateAt = null;
    _stationarySince = null;
    _lastProgressAt = null;
    _bestDistanceToDestinationMeters = null;

    _lastPosition = null;

    _actualDistanceMeters = 0.0;
    _distanceToDestinationMeters = null;

    _speedSumKmh = 0.0;
    _speedSamples = 0;
    _maxSpeedKmh = 0.0;

    _stableArrivalReadings = 0;
    _weakGpsEvents = 0;
    _longStopEvents = 0;
    _routeDeviationEvents = 0;

    _isTracking = false;
    _arrivalEmitted = false;
    _dangerEmitted = false;
    _weakGpsEpisodeActive = false;
    _longStopEpisodeActive = false;
    _nearDestinationEpisodeActive = false;

    _onUpdate = null;
    _onArrived = null;
    _onDanger = null;
    _onWarning = null;
  }
}

/// ==========================================
/// 📍 Tracking Update
/// ==========================================
class SafeArrivalTrackingUpdate {
  final String tripId;
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final double speedKmh;

  final double actualDistanceMeters;
  final double distanceToDestinationMeters;

  final bool isInsideArrivalRadius;
  final bool isNearDestination;
  final bool isAccuracyAcceptable;

  final int stableArrivalReadings;
  final int requiredStableArrivalReadings;

  final int weakGpsEvents;
  final int longStopEvents;
  final int routeDeviationEvents;

  final DateTime createdAt;

  const SafeArrivalTrackingUpdate({
    required this.tripId,
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.speedKmh,
    required this.actualDistanceMeters,
    required this.distanceToDestinationMeters,
    required this.isInsideArrivalRadius,
    required this.isNearDestination,
    required this.isAccuracyAcceptable,
    required this.stableArrivalReadings,
    required this.requiredStableArrivalReadings,
    required this.weakGpsEvents,
    required this.longStopEvents,
    required this.routeDeviationEvents,
    required this.createdAt,
  });

  bool get canConfirmArrival {
    return isInsideArrivalRadius &&
        isAccuracyAcceptable &&
        stableArrivalReadings >= requiredStableArrivalReadings;
  }
}

/// ==========================================
/// ✅ Arrival Result
/// ==========================================
class SafeArrivalArrivalResult {
  final String tripId;
  final double latitude;
  final double longitude;
  final double actualDistanceMeters;
  final double distanceToDestinationMeters;
  final SafeArrivalReportModel report;
  final DateTime arrivedAt;

  const SafeArrivalArrivalResult({
    required this.tripId,
    required this.latitude,
    required this.longitude,
    required this.actualDistanceMeters,
    required this.distanceToDestinationMeters,
    required this.report,
    required this.arrivedAt,
  });
}

/// ==========================================
/// 🚨 Danger Event
/// ==========================================
class SafeArrivalDangerEvent {
  final String tripId;
  final String reasonCode;
  final String message;
  final double? latitude;
  final double? longitude;
  final double actualDistanceMeters;
  final double? distanceToDestinationMeters;
  final SafeArrivalReportModel report;
  final DateTime createdAt;

  const SafeArrivalDangerEvent({
    required this.tripId,
    required this.reasonCode,
    required this.message,
    this.latitude,
    this.longitude,
    required this.actualDistanceMeters,
    this.distanceToDestinationMeters,
    required this.report,
    required this.createdAt,
  });
}

/// ==========================================
/// ⚠️ Tracking Warning
/// ==========================================
class SafeArrivalTrackingWarning {
  final SafeArrivalTrackingWarningCode code;
  final String message;
  final DateTime createdAt;

  const SafeArrivalTrackingWarning({
    required this.code,
    required this.message,
    required this.createdAt,
  });
}

enum SafeArrivalTrackingWarningCode {
  weakGps('weak_gps'),
  poorAccuracy('poor_accuracy'),
  nearDestination('near_destination'),
  longStop('long_stop'),
  invalidGpsReading('invalid_gps_reading'),
  processingError('processing_error');

  final String value;
  const SafeArrivalTrackingWarningCode(this.value);
}

enum SafeArrivalDangerReason {
  delayed('delayed'),
  trackingLost('tracking_lost'),
  userNotResponding('user_not_responding');

  final String value;
  const SafeArrivalDangerReason(this.value);
}

/// ==========================================
/// 📦 Tracking Result
/// ==========================================
class SafeArrivalTrackingResult<T> {
  final T? data;
  final SafeArrivalTrackingException? error;
  final bool isSuccess;

  const SafeArrivalTrackingResult._({
    this.data,
    this.error,
    required this.isSuccess,
  });

  factory SafeArrivalTrackingResult.success(T? data) {
    return SafeArrivalTrackingResult._(data: data, isSuccess: true);
  }

  factory SafeArrivalTrackingResult.failure(
    SafeArrivalTrackingException error,
  ) {
    return SafeArrivalTrackingResult._(error: error, isSuccess: false);
  }

  bool get isFailure => !isSuccess;
}

/// ==========================================
/// ⚠️ Tracking Exception
/// ==========================================
class SafeArrivalTrackingException {
  final String message;
  final String code;
  final Object? originalError;
  final StackTrace? stackTrace;

  const SafeArrivalTrackingException({
    required this.message,
    required this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'SafeArrivalTrackingException(code: $code, message: $message)';
  }
}
