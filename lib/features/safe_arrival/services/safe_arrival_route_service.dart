import 'dart:async';
import 'dart:convert';
import 'dart:math' show min;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_env.dart';
import '../models/safe_arrival_destination_model.dart';

/// ==========================================
/// 🛣️ Safe Arrival Route Service
/// ==========================================
/// Responsible for preparing route preview data before live tracking starts.
///
/// Responsibilities:
/// - Validate origin and destination.
/// - Request route details from Google Directions API.
/// - Extract distance, duration, and traffic-aware duration when available.
/// - Decode route polyline points for map rendering.
///
/// Not responsible for:
/// - UI state.
/// - Firestore writes.
/// - GPS live tracking.
/// - Arrival detection.
///
/// API key:
/// Pass using:
/// --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
class SafeArrivalRouteService {
  SafeArrivalRouteService({http.Client? httpClient, String? apiKey})
    : _httpClient = httpClient ?? http.Client(),
      _ownsHttpClient = httpClient == null,
      _apiKey = (apiKey ?? AppEnv.googleMapsApiKey).trim();

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final String _apiKey;

  static const Duration _timeout = Duration(seconds: 12);

  static const String _defaultMode = 'driving';

  static const Set<String> _supportedModes = <String>{
    'driving',
    'walking',
    'bicycling',
    'transit',
  };

  bool get hasApiKey => _apiKey.isNotEmpty;

  Future<SafeArrivalRouteResult<SafeArrivalRoutePreview>> previewRoute({
    required LatLng origin,
    required SafeArrivalDestinationModel destination,
    String language = 'ar',
    String mode = _defaultMode,
  }) async {
    if (!hasApiKey) {
      return SafeArrivalRouteResult.failure(
        const SafeArrivalRouteException(
          message: 'Google Maps API key is missing',
          code: 'missing-api-key',
        ),
      );
    }

    if (!_hasValidCoordinates(origin.latitude, origin.longitude)) {
      return SafeArrivalRouteResult.failure(
        const SafeArrivalRouteException(
          message: 'Origin coordinates are invalid',
          code: 'invalid-origin',
        ),
      );
    }

    if (!destination.isValid) {
      return SafeArrivalRouteResult.failure(
        const SafeArrivalRouteException(
          message: 'Destination is invalid',
          code: 'invalid-destination',
        ),
      );
    }

    try {
      final safeMode = _normalizeMode(mode);
      final queryParameters = <String, String>{
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': _destinationParameter(destination),
        'mode': safeMode,
        'language': _normalizeLanguage(language),
        'units': 'metric',
        'alternatives': 'false',
        'key': _apiKey,
      };

      if (safeMode == 'driving') {
        queryParameters['departure_time'] = 'now';
        queryParameters['traffic_model'] = 'best_guess';
      }

      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/directions/json',
        queryParameters,
      );

      final response = await _httpClient.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        return SafeArrivalRouteResult.failure(
          SafeArrivalRouteException(
            message: 'Directions HTTP error',
            code: 'directions-http-${response.statusCode}',
          ),
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return SafeArrivalRouteResult.failure(
          const SafeArrivalRouteException(
            message: 'Invalid Directions response',
            code: 'invalid-directions-response',
          ),
        );
      }

      final status = _stringOrFallback(decoded['status']);

      if (status != 'OK') {
        return SafeArrivalRouteResult.failure(
          SafeArrivalRouteException(
            message: _stringOrFallback(
              decoded['error_message'],
              fallback: 'Directions request failed',
            ),
            code: 'directions-status-${status.toLowerCase()}',
          ),
        );
      }

      final routes = decoded['routes'];

      if (routes is! List || routes.isEmpty || routes.first is! Map) {
        return SafeArrivalRouteResult.failure(
          const SafeArrivalRouteException(
            message: 'No route found',
            code: 'route-not-found',
          ),
        );
      }

      final firstRoute = (routes.first as Map).map(
        (key, dynamic value) => MapEntry(key.toString(), value),
      );

      final legs = firstRoute['legs'];

      if (legs is! List || legs.isEmpty || legs.first is! Map) {
        return SafeArrivalRouteResult.failure(
          const SafeArrivalRouteException(
            message: 'Route legs are missing',
            code: 'route-legs-missing',
          ),
        );
      }

      final firstLeg = (legs.first as Map).map(
        (key, dynamic value) => MapEntry(key.toString(), value),
      );

      final distanceMap = _asStringKeyMap(firstLeg['distance']);
      final durationMap = _asStringKeyMap(firstLeg['duration']);
      final durationInTrafficMap = _asStringKeyMap(
        firstLeg['duration_in_traffic'],
      );
      final overviewPolylineMap = _asStringKeyMap(
        firstRoute['overview_polyline'],
      );

      final distanceMeters = _toInt(distanceMap?['value']);
      final normalDurationSeconds = _toInt(durationMap?['value']);
      final trafficDurationSeconds = _toInt(durationInTrafficMap?['value']);

      final durationSeconds =
          _safePositiveInt(trafficDurationSeconds) ??
          _safePositiveInt(normalDurationSeconds);

      final encodedPolyline = _stringOrFallback(overviewPolylineMap?['points']);

      if (distanceMeters == null || distanceMeters < 0) {
        return SafeArrivalRouteResult.failure(
          const SafeArrivalRouteException(
            message: 'Route distance is invalid',
            code: 'invalid-route-distance',
          ),
        );
      }

      if (durationSeconds == null) {
        return SafeArrivalRouteResult.failure(
          const SafeArrivalRouteException(
            message: 'Route duration is invalid',
            code: 'invalid-route-duration',
          ),
        );
      }

      final decodedPolyline = encodedPolyline.isEmpty
          ? <LatLng>[]
          : decodePolyline(encodedPolyline);

      final fallbackPolyline = <LatLng>[
        origin,
        LatLng(destination.latitude, destination.longitude),
      ];

      final preview = SafeArrivalRoutePreview(
        origin: origin,
        destination: LatLng(destination.latitude, destination.longitude),
        distanceMeters: distanceMeters.toDouble(),
        durationSeconds: durationSeconds,
        normalDurationSeconds: normalDurationSeconds,
        trafficDurationSeconds: trafficDurationSeconds,
        polylinePoints: decodedPolyline.length >= 2
            ? decodedPolyline
            : fallbackPolyline,
      );

      return SafeArrivalRouteResult.success(preview);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ SafeArrivalRouteService: preview timeout');

      return SafeArrivalRouteResult.failure(
        SafeArrivalRouteException(
          message: 'Route preview timed out',
          code: 'route-preview-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } on FormatException catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalRouteService: invalid JSON response - $e');

      return SafeArrivalRouteResult.failure(
        SafeArrivalRouteException(
          message: 'Directions response could not be parsed',
          code: 'route-preview-parse-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalRouteService: preview failed - $e');
      debugPrintStack(stackTrace: stackTrace);

      return SafeArrivalRouteResult.failure(
        SafeArrivalRouteException(
          message: 'Failed to preview route',
          code: 'route-preview-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  List<LatLng> decodePolyline(String encoded) {
    final safeEncoded = encoded.trim();

    if (safeEncoded.isEmpty) {
      return const <LatLng>[];
    }

    try {
      final points = <LatLng>[];

      var index = 0;
      var latitude = 0;
      var longitude = 0;

      while (index < safeEncoded.length) {
        var shift = 0;
        var result = 0;
        int byte;

        do {
          if (index >= safeEncoded.length) {
            return const <LatLng>[];
          }

          byte = safeEncoded.codeUnitAt(index++) - 63;
          result |= (byte & 0x1F) << shift;
          shift += 5;
        } while (byte >= 0x20);

        final deltaLatitude = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
        latitude += deltaLatitude;

        shift = 0;
        result = 0;

        do {
          if (index >= safeEncoded.length) {
            return const <LatLng>[];
          }

          byte = safeEncoded.codeUnitAt(index++) - 63;
          result |= (byte & 0x1F) << shift;
          shift += 5;
        } while (byte >= 0x20);

        final deltaLongitude = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
        longitude += deltaLongitude;

        final point = LatLng(latitude / 100000.0, longitude / 100000.0);

        if (_hasValidCoordinates(point.latitude, point.longitude)) {
          points.add(point);
        }
      }

      return points;
    } catch (e, stackTrace) {
      debugPrint('⚠️ SafeArrivalRouteService: polyline decode failed - $e');
      debugPrintStack(stackTrace: stackTrace);
      return const <LatLng>[];
    }
  }

  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  String _destinationParameter(SafeArrivalDestinationModel destination) {
    final placeId = _stringOrFallback(destination.placeId);

    if (placeId.isNotEmpty) {
      return 'place_id:$placeId';
    }

    return '${destination.latitude},${destination.longitude}';
  }

  static String _normalizeMode(String mode) {
    final normalized = mode.trim().toLowerCase();

    if (_supportedModes.contains(normalized)) {
      return normalized;
    }

    return _defaultMode;
  }

  static String _normalizeLanguage(String language) {
    final normalized = language.trim().toLowerCase();

    if (normalized.isEmpty) {
      return 'ar';
    }

    return normalized;
  }

  static Map<String, dynamic>? _asStringKeyMap(dynamic value) {
    if (value is! Map) return null;

    return value.map(
      (key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
    );
  }

  static String _stringOrFallback(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;

    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();

    if (value is String) {
      return int.tryParse(value.trim());
    }

    return null;
  }

  static int? _safePositiveInt(int? value) {
    if (value == null || value <= 0) return null;
    return value;
  }

  static bool _hasValidCoordinates(double latitude, double longitude) {
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
}

/// ==========================================
/// 🛣️ Route Preview
/// ==========================================
class SafeArrivalRoutePreview {
  final LatLng origin;
  final LatLng destination;
  final double distanceMeters;
  final int durationSeconds;
  final int? normalDurationSeconds;
  final int? trafficDurationSeconds;
  final List<LatLng> polylinePoints;

  const SafeArrivalRoutePreview({
    required this.origin,
    required this.destination,
    required this.distanceMeters,
    required this.durationSeconds,
    this.normalDurationSeconds,
    this.trafficDurationSeconds,
    required this.polylinePoints,
  });

  bool get hasTrafficAwareDuration {
    return trafficDurationSeconds != null && trafficDurationSeconds! > 0;
  }

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(0)} م';
    }

    return '${(distanceMeters / 1000).toStringAsFixed(1)} كم';
  }

  String get formattedDuration {
    return _formatDuration(durationSeconds);
  }

  String get formattedNormalDuration {
    final seconds = normalDurationSeconds;
    if (seconds == null || seconds <= 0) return formattedDuration;
    return _formatDuration(seconds);
  }

  String get formattedTrafficDuration {
    final seconds = trafficDurationSeconds;
    if (seconds == null || seconds <= 0) return formattedDuration;
    return _formatDuration(seconds);
  }

  LatLng get center {
    final allPoints = polylinePoints.isEmpty
        ? <LatLng>[origin, destination]
        : polylinePoints;

    final limited = allPoints.take(min(allPoints.length, 1000)).toList();

    final latSum = limited.fold<double>(
      0.0,
      (sum, point) => sum + point.latitude,
    );

    final lngSum = limited.fold<double>(
      0.0,
      (sum, point) => sum + point.longitude,
    );

    return LatLng(latSum / limited.length, lngSum / limited.length);
  }

  static String _formatDuration(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final totalMinutes = (safeSeconds / 60).ceil();

    if (totalMinutes < 60) {
      return '$totalMinutes دقيقة';
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (minutes == 0) return '$hours ساعة';

    return '$hours ساعة و $minutes دقيقة';
  }
}

/// ==========================================
/// 📦 Route Result
/// ==========================================
class SafeArrivalRouteResult<T> {
  final T? data;
  final SafeArrivalRouteException? error;
  final bool isSuccess;

  const SafeArrivalRouteResult._({
    this.data,
    this.error,
    required this.isSuccess,
  });

  factory SafeArrivalRouteResult.success(T? data) {
    return SafeArrivalRouteResult._(data: data, isSuccess: true);
  }

  factory SafeArrivalRouteResult.failure(SafeArrivalRouteException error) {
    return SafeArrivalRouteResult._(error: error, isSuccess: false);
  }

  bool get isFailure => !isSuccess;
}

/// ==========================================
/// ⚠️ Route Exception
/// ==========================================
class SafeArrivalRouteException {
  final String message;
  final String code;
  final Object? originalError;
  final StackTrace? stackTrace;

  const SafeArrivalRouteException({
    required this.message,
    required this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'SafeArrivalRouteException(code: $code, message: $message)';
  }
}
