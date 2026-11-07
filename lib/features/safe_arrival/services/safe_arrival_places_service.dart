import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_env.dart';
import '../models/safe_arrival_destination_model.dart';

/// ==========================================
/// 📍 Safe Arrival Places Service
/// ==========================================
/// Handles trusted destination search for Safe Arrival.
///
/// Responsibilities:
/// - Search Google Places Autocomplete.
/// - Resolve selected prediction into a trusted destination.
/// - Return placeId, name, address, latitude, longitude.
///
/// Not responsible for:
/// - UI state.
/// - Firestore writes.
/// - GPS tracking.
/// - Route drawing.
///
/// API key:
/// Pass using:
/// --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
class SafeArrivalPlacesService {
  SafeArrivalPlacesService({http.Client? httpClient, String? apiKey})
    : _httpClient = httpClient ?? http.Client(),
      _ownsHttpClient = httpClient == null,
      _apiKey = (apiKey ?? AppEnv.googleMapsApiKey).trim();

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final String _apiKey;

  static const Duration _timeout = Duration(seconds: 10);

  static const int _minQueryLength = 2;
  static const int _maxPredictions = 8;
  static const int _defaultBiasRadiusMeters = 50000;

  bool get hasApiKey => _apiKey.isNotEmpty;

  Future<SafeArrivalPlacesResult<List<SafeArrivalPlacePrediction>>>
  searchDestinations({
    required String query,
    String language = 'ar',
    String countryCode = 'jo',
    LatLng? locationBias,
    int radiusMeters = _defaultBiasRadiusMeters,
  }) async {
    final safeQuery = _cleanText(query);

    if (safeQuery.length < _minQueryLength) {
      return SafeArrivalPlacesResult.success(
        const <SafeArrivalPlacePrediction>[],
      );
    }

    if (!hasApiKey) {
      return SafeArrivalPlacesResult.failure(
        const SafeArrivalPlacesException(
          message: 'Google Maps API key is missing',
          code: 'missing-api-key',
        ),
      );
    }

    try {
      final queryParameters = <String, String>{
        'input': safeQuery,
        'key': _apiKey,
        'language': _normalizeLanguage(language),
      };

      final safeCountryCode = _normalizeCountryCode(countryCode);
      if (safeCountryCode.isNotEmpty) {
        queryParameters['components'] = 'country:$safeCountryCode';
      }

      if (locationBias != null &&
          _hasValidCoordinates(locationBias.latitude, locationBias.longitude)) {
        queryParameters['location'] =
            '${locationBias.latitude},${locationBias.longitude}';
        queryParameters['radius'] = _safeRadiusMeters(radiusMeters).toString();
      }

      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        queryParameters,
      );

      final response = await _httpClient.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        return SafeArrivalPlacesResult.failure(
          SafeArrivalPlacesException(
            message: 'Places autocomplete HTTP error',
            code: 'places-http-${response.statusCode}',
          ),
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return SafeArrivalPlacesResult.failure(
          const SafeArrivalPlacesException(
            message: 'Invalid Places autocomplete response',
            code: 'invalid-places-response',
          ),
        );
      }

      final status = _stringOrFallback(decoded['status']).toUpperCase();

      if (status == 'ZERO_RESULTS') {
        return SafeArrivalPlacesResult.success(
          const <SafeArrivalPlacePrediction>[],
        );
      }

      if (status != 'OK') {
        return SafeArrivalPlacesResult.failure(
          SafeArrivalPlacesException(
            message: _stringOrFallback(
              decoded['error_message'],
              fallback: 'Places autocomplete failed',
            ),
            code: 'places-status-${_safeStatusCode(status)}',
          ),
        );
      }

      final predictionsRaw = decoded['predictions'];

      if (predictionsRaw is! List) {
        return SafeArrivalPlacesResult.success(
          const <SafeArrivalPlacePrediction>[],
        );
      }

      final seenPlaceIds = <String>{};
      final predictions = <SafeArrivalPlacePrediction>[];

      for (final rawPrediction in predictionsRaw) {
        if (rawPrediction is! Map) continue;

        final prediction = SafeArrivalPlacePrediction.fromMap(
          rawPrediction.map(
            (key, dynamic value) => MapEntry(key.toString(), value),
          ),
        );

        if (!prediction.isValid) continue;
        if (!seenPlaceIds.add(prediction.placeId)) continue;

        predictions.add(prediction);

        if (predictions.length >= _maxPredictions) break;
      }

      return SafeArrivalPlacesResult.success(
        List<SafeArrivalPlacePrediction>.unmodifiable(predictions),
      );
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ SafeArrivalPlacesService: search timeout');

      return SafeArrivalPlacesResult.failure(
        SafeArrivalPlacesException(
          message: 'Places search timed out',
          code: 'places-search-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } on FormatException catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalPlacesService: invalid JSON response - $e');

      return SafeArrivalPlacesResult.failure(
        SafeArrivalPlacesException(
          message: 'Places search response could not be parsed',
          code: 'places-search-parse-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalPlacesService: search failed - $e');
      debugPrintStack(stackTrace: stackTrace);

      return SafeArrivalPlacesResult.failure(
        SafeArrivalPlacesException(
          message: 'Failed to search destinations',
          code: 'places-search-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<SafeArrivalPlacesResult<SafeArrivalDestinationModel>>
  resolveDestination({
    required SafeArrivalPlacePrediction prediction,
    String language = 'ar',
  }) async {
    if (!prediction.isValid) {
      return SafeArrivalPlacesResult.failure(
        const SafeArrivalPlacesException(
          message: 'Place prediction is invalid',
          code: 'invalid-prediction',
        ),
      );
    }

    if (!hasApiKey) {
      return SafeArrivalPlacesResult.failure(
        const SafeArrivalPlacesException(
          message: 'Google Maps API key is missing',
          code: 'missing-api-key',
        ),
      );
    }

    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        <String, String>{
          'place_id': prediction.placeId,
          'key': _apiKey,
          'language': _normalizeLanguage(language),
          'fields': 'place_id,name,formatted_address,geometry',
        },
      );

      final response = await _httpClient.get(uri).timeout(_timeout);

      if (response.statusCode != 200) {
        return SafeArrivalPlacesResult.failure(
          SafeArrivalPlacesException(
            message: 'Place details HTTP error',
            code: 'place-details-http-${response.statusCode}',
          ),
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        return SafeArrivalPlacesResult.failure(
          const SafeArrivalPlacesException(
            message: 'Invalid Place details response',
            code: 'invalid-place-details-response',
          ),
        );
      }

      final status = _stringOrFallback(decoded['status']).toUpperCase();

      if (status != 'OK') {
        return SafeArrivalPlacesResult.failure(
          SafeArrivalPlacesException(
            message: _stringOrFallback(
              decoded['error_message'],
              fallback: 'Place details failed',
            ),
            code: 'place-details-status-${_safeStatusCode(status)}',
          ),
        );
      }

      final result = _asStringKeyMap(decoded['result']);

      if (result == null) {
        return SafeArrivalPlacesResult.failure(
          const SafeArrivalPlacesException(
            message: 'Place details result is missing',
            code: 'place-details-result-missing',
          ),
        );
      }

      final geometry = _asStringKeyMap(result['geometry']);
      final location = _asStringKeyMap(geometry?['location']);

      if (location == null) {
        return SafeArrivalPlacesResult.failure(
          const SafeArrivalPlacesException(
            message: 'Place coordinates are missing',
            code: 'place-coordinates-missing',
          ),
        );
      }

      final latitude = _toDouble(location['lat']);
      final longitude = _toDouble(location['lng']);

      if (!_hasValidCoordinates(latitude, longitude)) {
        return SafeArrivalPlacesResult.failure(
          const SafeArrivalPlacesException(
            message: 'Place coordinates are invalid',
            code: 'invalid-place-coordinates',
          ),
        );
      }

      final fallbackName = prediction.mainText.trim().isNotEmpty
          ? prediction.mainText
          : prediction.description;

      final destination = SafeArrivalDestinationModel.fromTrustedPlace(
        placeId: _stringOrFallback(
          result['place_id'],
          fallback: prediction.placeId,
        ),
        name: _stringOrFallback(result['name'], fallback: fallbackName),
        address: _stringOrFallback(
          result['formatted_address'],
          fallback: prediction.description,
        ),
        latitude: latitude!,
        longitude: longitude!,
        provider: 'google_places',
      );

      if (!destination.isValid) {
        return SafeArrivalPlacesResult.failure(
          const SafeArrivalPlacesException(
            message: 'Resolved destination is invalid',
            code: 'invalid-resolved-destination',
          ),
        );
      }

      return SafeArrivalPlacesResult.success(destination);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ SafeArrivalPlacesService: details timeout');

      return SafeArrivalPlacesResult.failure(
        SafeArrivalPlacesException(
          message: 'Place details timed out',
          code: 'place-details-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } on FormatException catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalPlacesService: invalid details JSON - $e');

      return SafeArrivalPlacesResult.failure(
        SafeArrivalPlacesException(
          message: 'Place details response could not be parsed',
          code: 'place-details-parse-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalPlacesService: details failed - $e');
      debugPrintStack(stackTrace: stackTrace);

      return SafeArrivalPlacesResult.failure(
        SafeArrivalPlacesException(
          message: 'Failed to resolve destination',
          code: 'place-details-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  void dispose() {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  static String _cleanText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _normalizeLanguage(String language) {
    final normalized = language.trim().toLowerCase();

    if (normalized.isEmpty) return 'ar';

    return normalized;
  }

  static String _normalizeCountryCode(String countryCode) {
    final normalized = countryCode.trim().toLowerCase();

    if (normalized.isEmpty) return '';

    if (!RegExp(r'^[a-z]{2}$').hasMatch(normalized)) {
      return 'jo';
    }

    return normalized;
  }

  static int _safeRadiusMeters(int value) {
    if (value < 1000) return 1000;
    if (value > 50000) return 50000;
    return value;
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

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();

    if (value is String) {
      return double.tryParse(value.trim());
    }

    return null;
  }

  static String _safeStatusCode(String status) {
    final safeStatus = status.trim().toLowerCase();

    if (safeStatus.isEmpty) return 'unknown';

    return safeStatus.replaceAll(RegExp(r'[^a-z0-9_]+'), '-');
  }

  static bool _hasValidCoordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) return false;

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
/// 🔎 Place Prediction
/// ==========================================
class SafeArrivalPlacePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  const SafeArrivalPlacePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory SafeArrivalPlacePrediction.fromMap(Map<String, dynamic> map) {
    final formatting = _asStringKeyMap(map['structured_formatting']);

    return SafeArrivalPlacePrediction(
      placeId: _stringOrFallback(map['place_id']),
      description: _stringOrFallback(map['description']),
      mainText: _stringOrFallback(formatting?['main_text']),
      secondaryText: _stringOrFallback(formatting?['secondary_text']),
    );
  }

  bool get isValid {
    return placeId.trim().isNotEmpty &&
        (description.trim().isNotEmpty || mainText.trim().isNotEmpty);
  }

  String get displayTitle {
    return mainText.trim().isNotEmpty ? mainText : description;
  }

  String get displaySubtitle {
    if (secondaryText.trim().isNotEmpty) return secondaryText;

    if (description.trim().isNotEmpty && description != displayTitle) {
      return description;
    }

    return '';
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
}

/// ==========================================
/// 📦 Places Result
/// ==========================================
class SafeArrivalPlacesResult<T> {
  final T? data;
  final SafeArrivalPlacesException? error;
  final bool isSuccess;

  const SafeArrivalPlacesResult._({
    this.data,
    this.error,
    required this.isSuccess,
  });

  factory SafeArrivalPlacesResult.success(T? data) {
    return SafeArrivalPlacesResult._(data: data, isSuccess: true);
  }

  factory SafeArrivalPlacesResult.failure(SafeArrivalPlacesException error) {
    return SafeArrivalPlacesResult._(error: error, isSuccess: false);
  }

  bool get isFailure => !isSuccess;
}

/// ==========================================
/// ⚠️ Places Exception
/// ==========================================
class SafeArrivalPlacesException {
  final String message;
  final String code;
  final Object? originalError;
  final StackTrace? stackTrace;

  const SafeArrivalPlacesException({
    required this.message,
    required this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'SafeArrivalPlacesException(code: $code, message: $message)';
  }
}
