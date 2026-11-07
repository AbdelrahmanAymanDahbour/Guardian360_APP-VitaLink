import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'firebase_service.dart';
import 'geocoding_service.dart';
import 'gps_location_service.dart';

class TripTrackingService {
  TripTrackingService({
    required GPSLocationService gpsService,
    required GeocodingService geocodingService,
    required FirebaseService firebaseService,
  }) : _gpsService = gpsService,
       _geocodingService = geocodingService,
       _firebaseService = firebaseService;

  final GPSLocationService _gpsService;
  final GeocodingService _geocodingService;
  final FirebaseService _firebaseService;

  String? _currentTripId;
  Position? _tripStartPosition;
  Position? _lastTrackedPosition;
  double _totalDistance = 0.0;

  Timer? _locationUpdateTimer;

  void Function(Position)? _onLocationUpdate;
  void Function(double)? _onDistanceUpdate;
  void Function(String)? _onError;

  Future<TripResult<String>> startTrip({
    required String userId,
    required String destination,
    DateTime? estimatedArrival,
    void Function(Position)? onLocationUpdate,
    void Function(double)? onDistanceUpdate,
    void Function(String)? onError,
  }) async {
    try {
      if (_currentTripId != null) {
        return TripResult.failure(
          TripException(
            message: 'A trip is already active',
            code: 'trip-already-active',
          ),
        );
      }

      _onLocationUpdate = onLocationUpdate;
      _onDistanceUpdate = onDistanceUpdate;
      _onError = onError;

      final positionResult = await _gpsService.getCurrentPosition();
      if (positionResult.isFailure || positionResult.data == null) {
        return TripResult.failure(
          TripException(
            message: 'Failed to get current position',
            code: 'position-fetch-failed',
            originalError: positionResult.error,
          ),
        );
      }

      final startPosition = positionResult.data!;
      _tripStartPosition = startPosition;
      _lastTrackedPosition = startPosition;
      _totalDistance = 0.0;

      final startLocationName = await _geocodingService
          .getAddressFromCoordinates(
            LatLng(startPosition.latitude, startPosition.longitude),
          );

      final tripResult = await _firebaseService.startTrip(
        userId: userId,
        destination: destination,
        startLatitude: startPosition.latitude,
        startLongitude: startPosition.longitude,
        startLocationName: startLocationName,
        estimatedArrival: estimatedArrival,
      );

      if (tripResult.isFailure || tripResult.data == null) {
        _resetTripState();
        return TripResult.failure(
          TripException(
            message: 'Failed to create trip in Firebase',
            code: 'firebase-trip-creation-failed',
            originalError: tripResult.error,
          ),
        );
      }

      _currentTripId = tripResult.data!;
      await _startLocationTracking();

      debugPrint('🚗 TripTrackingService: Trip started - $_currentTripId');
      return TripResult.success(_currentTripId!);
    } catch (e, stackTrace) {
      _resetTripState();
      debugPrint('❌ TripTrackingService: Failed to start trip - $e');
      return TripResult.failure(
        TripException(
          message: 'Failed to start trip',
          code: 'trip-start-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<TripResult<void>> endTrip() async {
    final tripId = _currentTripId;

    if (tripId == null) {
      return TripResult.failure(
        TripException(message: 'No active trip to end', code: 'no-active-trip'),
      );
    }

    try {
      await _stopLocationTracking();

      final positionResult = await _gpsService.getCurrentPosition();

      if (positionResult.isSuccess && positionResult.data != null) {
        final endPosition = positionResult.data!;

        final endLocationName = await _geocodingService
            .getAddressFromCoordinates(
              LatLng(endPosition.latitude, endPosition.longitude),
            );

        await _firebaseService.endTrip(
          tripId,
          endLatitude: endPosition.latitude,
          endLongitude: endPosition.longitude,
          endLocationName: endLocationName,
        );
      }

      debugPrint('🏁 TripTrackingService: Trip ended - $tripId');
      debugPrint(
        '   └─ Total distance: ${_totalDistance.toStringAsFixed(2)} m',
      );

      _resetTripState();
      return TripResult.success(null);
    } catch (e, stackTrace) {
      debugPrint('❌ TripTrackingService: Failed to end trip - $e');
      _resetTripState();
      return TripResult.failure(
        TripException(
          message: 'Failed to end trip',
          code: 'trip-end-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> _startLocationTracking() async {
    final trackingResult = await _gpsService.startLocationTracking(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      interval: const Duration(seconds: 5),
    );

    if (trackingResult.isFailure) {
      _onError?.call('Failed to start location tracking');
      return;
    }

    _gpsService.addLocationListener(_handleLocationUpdate);

    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _updateFirebaseLocation(),
    );

    debugPrint('📍 TripTrackingService: Location tracking started');
  }

  Future<void> _stopLocationTracking() async {
    await _gpsService.stopLocationTracking();
    _gpsService.removeLocationListener(_handleLocationUpdate);
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;

    debugPrint('🛑 TripTrackingService: Location tracking stopped');
  }

  void _handleLocationUpdate(Position position) {
    try {
      if (_lastTrackedPosition != null) {
        final distance = _gpsService.calculateDistance(
          startLatitude: _lastTrackedPosition!.latitude,
          startLongitude: _lastTrackedPosition!.longitude,
          endLatitude: position.latitude,
          endLongitude: position.longitude,
        );

        _totalDistance += distance;
        _onDistanceUpdate?.call(_totalDistance);
      }

      _lastTrackedPosition = position;
      _onLocationUpdate?.call(position);

      debugPrint(
        '📍 TripTrackingService: Location updated - (${position.latitude}, ${position.longitude})',
      );
    } catch (e) {
      debugPrint('❌ TripTrackingService: Error handling location update - $e');
      _onError?.call('Error processing location update');
    }
  }

  Future<void> _updateFirebaseLocation() async {
    if (_currentTripId == null || _lastTrackedPosition == null) return;

    try {
      final currentLocationName = await _geocodingService
          .getAddressFromCoordinates(
            LatLng(
              _lastTrackedPosition!.latitude,
              _lastTrackedPosition!.longitude,
            ),
          );

      await _firebaseService.updateTripLocation(
        tripId: _currentTripId!,
        latitude: _lastTrackedPosition!.latitude,
        longitude: _lastTrackedPosition!.longitude,
        currentLocationName: currentLocationName,
        totalDistance: _totalDistance,
      );

      debugPrint('🔄 TripTrackingService: Firebase location updated');
    } catch (e) {
      debugPrint('❌ TripTrackingService: Failed to update Firebase - $e');
    }
  }

  TripInfo? getCurrentTripInfo() {
    if (_currentTripId == null || _tripStartPosition == null) {
      return null;
    }

    return TripInfo(
      tripId: _currentTripId!,
      startPosition: _tripStartPosition!,
      currentPosition: _lastTrackedPosition,
      totalDistance: _totalDistance,
      isActive: true,
    );
  }

  bool get hasActiveTrip => _currentTripId != null;
  String? get currentTripId => _currentTripId;
  double get totalDistance => _totalDistance;

  double? getDistanceFromStart() {
    if (_tripStartPosition == null || _lastTrackedPosition == null) {
      return null;
    }

    return _gpsService.calculateDistance(
      startLatitude: _tripStartPosition!.latitude,
      startLongitude: _tripStartPosition!.longitude,
      endLatitude: _lastTrackedPosition!.latitude,
      endLongitude: _lastTrackedPosition!.longitude,
    );
  }

  Future<TripResult<double>> getDistanceToDestination({
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    try {
      if (_lastTrackedPosition == null) {
        return TripResult.failure(
          TripException(
            message: 'No current position available',
            code: 'no-current-position',
          ),
        );
      }

      final distance = _gpsService.calculateDistance(
        startLatitude: _lastTrackedPosition!.latitude,
        startLongitude: _lastTrackedPosition!.longitude,
        endLatitude: destinationLatitude,
        endLongitude: destinationLongitude,
      );

      return TripResult.success(distance);
    } catch (e, stackTrace) {
      return TripResult.failure(
        TripException(
          message: 'Failed to calculate distance to destination',
          code: 'distance-calculation-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<void> dispose() async {
    if (_currentTripId != null) {
      await endTrip();
      return;
    }

    await _stopLocationTracking();
    _resetTripState();
    debugPrint('🧹 TripTrackingService: Disposed');
  }

  void _resetTripState() {
    _currentTripId = null;
    _tripStartPosition = null;
    _lastTrackedPosition = null;
    _totalDistance = 0.0;
    _onLocationUpdate = null;
    _onDistanceUpdate = null;
    _onError = null;
  }
}

class TripResult<T> {
  final T? data;
  final TripException? error;
  final bool isSuccess;

  TripResult._({this.data, this.error, required this.isSuccess});

  factory TripResult.success(T? data) {
    return TripResult._(data: data, isSuccess: true);
  }

  factory TripResult.failure(TripException error) {
    return TripResult._(error: error, isSuccess: false);
  }

  bool get isFailure => !isSuccess;
}

class TripException {
  final String message;
  final String code;
  final Object? originalError;
  final StackTrace? stackTrace;

  TripException({
    required this.message,
    required this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'TripException(code: $code, message: $message)';
  }
}

class TripInfo {
  final String tripId;
  final Position startPosition;
  final Position? currentPosition;
  final double totalDistance;
  final bool isActive;

  TripInfo({
    required this.tripId,
    required this.startPosition,
    this.currentPosition,
    required this.totalDistance,
    required this.isActive,
  });

  @override
  String toString() {
    return 'TripInfo(tripId: $tripId, distance: ${totalDistance.toStringAsFixed(2)}m, active: $isActive)';
  }
}
