import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/app_thresholds.dart';

/// ==========================================
/// 📍 GPS Location Service - Guardian 360
/// ==========================================
/// خدمة مركزية لإدارة الموقع الجغرافي.
///
/// مسؤولياتها:
/// - إدارة صلاحيات GPS.
/// - جلب الموقع الحالي للطوارئ.
/// - جلب آخر موقع معروف.
/// - تتبع الموقع الحي.
/// - حساب المسافات والسرعة.
///
/// غير مسؤولة عن:
/// - إرسال بلاغات.
/// - كتابة Firestore.
/// - تشغيل SOS.
/// - حساب شدة الحادث.
///
/// مستخدمة بشكل حساس داخل:
/// SOSViewModel.executeEmergencyAction()
class GPSLocationService {
  GPSLocationService();

  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _lastKnownPosition;

  final List<void Function(Position)> _locationListeners = [];

  bool _isDisposed = false;
  bool _isTracking = false;

  static const Duration _permissionTimeout = Duration(seconds: 8);
  static const Duration _serviceCheckTimeout = Duration(seconds: 5);
  static const Duration _lastKnownTimeout = Duration(seconds: 4);
  static const Duration _settingsTimeout = Duration(seconds: 5);

  bool get isTracking => _isTracking;
  Position? get cachedLastKnownPosition => _lastKnownPosition;

  // ==========================================
  // 🔐 PERMISSION MANAGEMENT
  // ==========================================

  Future<LocationResult<bool>> requestPermission() async {
    if (_isDisposed) {
      return LocationResult.failure(
        LocationException(
          message: 'GPSLocationService is disposed',
          code: 'service-disposed',
        ),
      );
    }

    try {
      var permission = await Geolocator.checkPermission().timeout(
        _permissionTimeout,
      );

      if (permission == LocationPermission.denied) {
        debugPrint('📍 GPSLocationService: Requesting location permission...');
        permission = await Geolocator.requestPermission().timeout(
          _permissionTimeout,
        );
      }

      if (permission == LocationPermission.denied) {
        return LocationResult.failure(
          LocationException(
            message: 'Location permission denied by user',
            code: 'permission-denied',
          ),
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationResult.failure(
          LocationException(
            message: 'Location permission denied forever',
            code: 'permission-denied-forever',
          ),
        );
      }

      debugPrint('✅ GPSLocationService: Location permission granted');
      return LocationResult.success(true);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ GPSLocationService: Permission request timeout');
      return LocationResult.failure(
        LocationException(
          message: 'Location permission request timed out',
          code: 'permission-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ GPSLocationService: Failed to request permission - $e');
      return LocationResult.failure(
        LocationException(
          message: 'Failed to request location permission',
          code: 'permission-request-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<LocationResult<LocationPermission>> checkPermission() async {
    if (_isDisposed) {
      return LocationResult.failure(
        LocationException(
          message: 'GPSLocationService is disposed',
          code: 'service-disposed',
        ),
      );
    }

    try {
      final permission = await Geolocator.checkPermission().timeout(
        _permissionTimeout,
      );

      return LocationResult.success(permission);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ GPSLocationService: Permission check timeout');
      return LocationResult.failure(
        LocationException(
          message: 'Location permission check timed out',
          code: 'permission-check-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ GPSLocationService: Failed to check permission - $e');
      return LocationResult.failure(
        LocationException(
          message: 'Failed to check location permission',
          code: 'permission-check-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<LocationResult<bool>> isLocationServiceEnabled() async {
    if (_isDisposed) {
      return LocationResult.failure(
        LocationException(
          message: 'GPSLocationService is disposed',
          code: 'service-disposed',
        ),
      );
    }

    try {
      final isEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        _serviceCheckTimeout,
      );

      return LocationResult.success(isEnabled);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ GPSLocationService: Service check timeout');
      return LocationResult.failure(
        LocationException(
          message: 'Location service status check timed out',
          code: 'service-check-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ GPSLocationService: Failed to check service status - $e');
      return LocationResult.failure(
        LocationException(
          message: 'Failed to check location service status',
          code: 'service-check-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ==========================================
  // 📍 LOCATION FETCHING
  // ==========================================

  Future<LocationResult<Position>> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(
      seconds: AppThresholds.locationTimeoutSeconds,
    ),
  }) async {
    if (_isDisposed) {
      return LocationResult.failure(
        LocationException(
          message: 'GPSLocationService is disposed',
          code: 'service-disposed',
        ),
      );
    }

    try {
      final serviceResult = await isLocationServiceEnabled();

      if (serviceResult.isFailure || serviceResult.data != true) {
        return LocationResult.failure(
          serviceResult.error ??
              LocationException(
                message: 'Location service is disabled',
                code: 'service-disabled',
              ),
        );
      }

      final permissionResult = await requestPermission();

      if (permissionResult.isFailure) {
        return LocationResult.failure(permissionResult.error!);
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeout,
        ),
      ).timeout(timeout + const Duration(seconds: 2));

      if (!_isUsablePosition(position)) {
        debugPrint(
          '⚠️ GPSLocationService: Fresh position invalid '
          '(${position.latitude}, ${position.longitude})',
        );

        final fallback = await getLastKnownPosition();
        if (fallback.isSuccess) return fallback;

        return LocationResult.failure(
          LocationException(
            message: 'Fresh position has invalid coordinates',
            code: 'invalid-current-position',
          ),
        );
      }

      _lastKnownPosition = position;

      debugPrint(
        '📍 GPSLocationService: Position fetched - '
        '(${position.latitude}, ${position.longitude}), '
        'accuracy=${position.accuracy.toStringAsFixed(1)}m',
      );

      return LocationResult.success(position);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ GPSLocationService: Timeout getting position');

      final lastPosition = await getLastKnownPosition();

      if (lastPosition.isSuccess) {
        debugPrint('✅ GPSLocationService: Using last known position fallback');
        return lastPosition;
      }

      return LocationResult.failure(
        LocationException(
          message: 'Timeout getting current position',
          code: 'position-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ GPSLocationService: Failed to get position - $e');

      final lastPosition = await getLastKnownPosition();
      if (lastPosition.isSuccess) {
        debugPrint('✅ GPSLocationService: Using last known position fallback');
        return lastPosition;
      }

      return LocationResult.failure(
        LocationException(
          message: 'Failed to get current position',
          code: 'position-fetch-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<LocationResult<Position>> getLastKnownPosition() async {
    if (_isDisposed) {
      return LocationResult.failure(
        LocationException(
          message: 'GPSLocationService is disposed',
          code: 'service-disposed',
        ),
      );
    }

    try {
      final cached = _lastKnownPosition;

      if (cached != null && _isUsablePosition(cached)) {
        return LocationResult.success(cached);
      }

      final position = await Geolocator.getLastKnownPosition().timeout(
        _lastKnownTimeout,
      );

      if (position == null) {
        return LocationResult.failure(
          LocationException(
            message: 'No last known position available',
            code: 'no-last-position',
          ),
        );
      }

      if (!_isUsablePosition(position)) {
        return LocationResult.failure(
          LocationException(
            message: 'Last known position is invalid',
            code: 'invalid-last-position',
          ),
        );
      }

      _lastKnownPosition = position;

      debugPrint(
        '📍 GPSLocationService: Last known position fetched - '
        '(${position.latitude}, ${position.longitude})',
      );

      return LocationResult.success(position);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ GPSLocationService: Last known position timeout');
      return LocationResult.failure(
        LocationException(
          message: 'Last known position request timed out',
          code: 'last-position-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ GPSLocationService: Failed to get last position - $e');
      return LocationResult.failure(
        LocationException(
          message: 'Failed to get last known position',
          code: 'last-position-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ==========================================
  // 🔄 REAL-TIME TRACKING
  // ==========================================

  Future<LocationResult<void>> startLocationTracking({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
    Duration interval = const Duration(seconds: 5),
  }) async {
    if (_isDisposed) {
      return LocationResult.failure(
        LocationException(
          message: 'GPSLocationService is disposed',
          code: 'service-disposed',
        ),
      );
    }

    try {
      final serviceResult = await isLocationServiceEnabled();

      if (serviceResult.isFailure || serviceResult.data != true) {
        return LocationResult.failure(
          serviceResult.error ??
              LocationException(
                message: 'Location service is disabled',
                code: 'service-disabled',
              ),
        );
      }

      final permissionResult = await requestPermission();

      if (permissionResult.isFailure) {
        return LocationResult.failure(permissionResult.error!);
      }

      await stopLocationTracking();

      final safeDistanceFilter = distanceFilter < 0 ? 0 : distanceFilter;

      // ملاحظة:
      // لا نستخدم timeLimit هنا حتى لا ينتهي stream بشكل غير مقصود.
      // interval محفوظ في التوقيع للتوافق، لكن التحكم الحقيقي بالتحديثات
      // هنا من distanceFilter ودقة الموقع.
      final locationSettings = LocationSettings(
        accuracy: accuracy,
        distanceFilter: safeDistanceFilter,
      );

      _positionStreamSubscription =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen(
            (Position position) {
              if (_isDisposed) return;

              if (!_isUsablePosition(position)) {
                debugPrint(
                  '⚠️ GPSLocationService: Invalid stream position ignored '
                  '(${position.latitude}, ${position.longitude})',
                );
                return;
              }

              _lastKnownPosition = position;
              _notifyLocationListeners(position);

              debugPrint(
                '📍 GPSLocationService: Location updated - '
                '(${position.latitude}, ${position.longitude}), '
                'accuracy=${position.accuracy.toStringAsFixed(1)}m',
              );
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint(
                '❌ GPSLocationService: Location stream error - $error',
              );
              debugPrintStack(stackTrace: stackTrace);
            },
            cancelOnError: false,
          );

      _isTracking = true;

      debugPrint(
        '✅ GPSLocationService: Location tracking started '
        '(distanceFilter=${safeDistanceFilter}m, requestedInterval=${interval.inSeconds}s)',
      );

      return LocationResult.success(null);
    } catch (e, stackTrace) {
      debugPrint('❌ GPSLocationService: Failed to start tracking - $e');
      _isTracking = false;

      return LocationResult.failure(
        LocationException(
          message: 'Failed to start location tracking',
          code: 'tracking-start-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> stopLocationTracking() async {
    try {
      await _positionStreamSubscription?.cancel();
    } catch (e, stackTrace) {
      debugPrint('❌ GPSLocationService: Failed to stop tracking - $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _positionStreamSubscription = null;
      _isTracking = false;
      debugPrint('🛑 GPSLocationService: Location tracking stopped');
    }
  }

  void addLocationListener(void Function(Position) listener) {
    if (_isDisposed) return;

    if (!_locationListeners.contains(listener)) {
      _locationListeners.add(listener);
    }
  }

  void removeLocationListener(void Function(Position) listener) {
    _locationListeners.remove(listener);
  }

  void _notifyLocationListeners(Position position) {
    final listeners = List<void Function(Position)>.from(_locationListeners);

    for (final listener in listeners) {
      try {
        listener(position);
      } catch (e, stackTrace) {
        debugPrint('❌ GPSLocationService: Listener error - $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  // ==========================================
  // 📏 DISTANCE CALCULATIONS
  // ==========================================

  double calculateDistance({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    try {
      if (!_hasValidCoordinates(startLatitude, startLongitude) ||
          !_hasValidCoordinates(endLatitude, endLongitude)) {
        debugPrint('⚠️ GPSLocationService: Invalid coordinates for distance');
        return 0.0;
      }

      final distance = Geolocator.distanceBetween(
        startLatitude,
        startLongitude,
        endLatitude,
        endLongitude,
      );

      if (distance.isNaN || distance.isInfinite || distance < 0.0) {
        return 0.0;
      }

      return distance;
    } catch (e, stackTrace) {
      debugPrint('❌ GPSLocationService: Failed to calculate distance - $e');
      debugPrintStack(stackTrace: stackTrace);
      return 0.0;
    }
  }

  Future<LocationResult<double>> calculateDistanceFromCurrent({
    required double targetLatitude,
    required double targetLongitude,
  }) async {
    try {
      if (!_hasValidCoordinates(targetLatitude, targetLongitude)) {
        return LocationResult.failure(
          LocationException(
            message: 'Target coordinates are invalid',
            code: 'invalid-target-coordinates',
          ),
        );
      }

      final positionResult = await getCurrentPosition();

      if (positionResult.isFailure) {
        return LocationResult.failure(positionResult.error!);
      }

      final position = positionResult.data!;

      final distance = calculateDistance(
        startLatitude: position.latitude,
        startLongitude: position.longitude,
        endLatitude: targetLatitude,
        endLongitude: targetLongitude,
      );

      return LocationResult.success(distance);
    } catch (e, stackTrace) {
      debugPrint('❌ GPSLocationService: Failed to calculate distance - $e');
      return LocationResult.failure(
        LocationException(
          message: 'Failed to calculate distance from current position',
          code: 'distance-calculation-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  double calculateSpeed(Position position) {
    final speedMps = position.speed;

    if (speedMps.isNaN || speedMps.isInfinite || speedMps < 0.0) {
      return 0.0;
    }

    final speedKmh = speedMps * 3.6;

    if (speedKmh > AppThresholds.maxReasonableSpeedKmh) {
      return AppThresholds.maxReasonableSpeedKmh;
    }

    return speedKmh;
  }

  // ==========================================
  // ⚙️ SETTINGS
  // ==========================================

  Future<LocationResult<bool>> openLocationSettings() async {
    try {
      final result = await Geolocator.openLocationSettings().timeout(
        _settingsTimeout,
      );

      return LocationResult.success(result);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ GPSLocationService: Open location settings timeout');
      return LocationResult.failure(
        LocationException(
          message: 'Opening location settings timed out',
          code: 'settings-open-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ GPSLocationService: Failed to open settings - $e');
      return LocationResult.failure(
        LocationException(
          message: 'Failed to open location settings',
          code: 'settings-open-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<LocationResult<bool>> openAppSettings() async {
    try {
      final result = await Geolocator.openAppSettings().timeout(
        _settingsTimeout,
      );

      return LocationResult.success(result);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ GPSLocationService: Open app settings timeout');
      return LocationResult.failure(
        LocationException(
          message: 'Opening app settings timed out',
          code: 'app-settings-open-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ GPSLocationService: Failed to open app settings - $e');
      return LocationResult.failure(
        LocationException(
          message: 'Failed to open app settings',
          code: 'app-settings-open-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ==========================================
  // Helpers
  // ==========================================

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

  // ==========================================
  // 🧹 CLEANUP
  // ==========================================

  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    await stopLocationTracking();

    _locationListeners.clear();
    _lastKnownPosition = null;

    debugPrint('🧹 GPSLocationService: Disposed');
  }
}

// ==========================================
// 📦 DATA MODELS
// ==========================================

class LocationResult<T> {
  final T? data;
  final LocationException? error;
  final bool isSuccess;

  LocationResult._({this.data, this.error, required this.isSuccess});

  factory LocationResult.success(T? data) {
    return LocationResult._(data: data, isSuccess: true);
  }

  factory LocationResult.failure(LocationException error) {
    return LocationResult._(error: error, isSuccess: false);
  }

  bool get isFailure => !isSuccess;
}

class LocationException {
  final String message;
  final String code;
  final Object? originalError;
  final StackTrace? stackTrace;

  LocationException({
    required this.message,
    required this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'LocationException(code: $code, message: $message)';
  }
}
