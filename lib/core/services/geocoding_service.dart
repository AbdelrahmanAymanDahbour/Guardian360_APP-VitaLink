import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// ==========================================
/// 🌍 Service: Reverse Geocoding
/// ==========================================
/// Converts coordinates into the most granular readable address available.
///
/// Resolution order:
///   1) Google Geocoding API  → selects the BEST granular result, not first.
///   2) Platform geocoding    → thoroughfare / subLocality / locality.
///   3) Empty string          → never returns fake names or coordinates.
///
/// Important:
/// - Does NOT return fake/default location names.
/// - Does NOT expose coordinates as a human-readable address.
/// - Does NOT hardcode city/governorate/district names.
/// - Does NOT hardcode the Google API key in source code.
/// - GOOGLE_MAPS_API_KEY must be supplied via --dart-define.
class GeocodingService {
  GeocodingService({
    http.Client? httpClient,
    String? googleMapsApiKey,
    String? languageCode,
    String regionCode = 'jo',
  }) : _httpClient = httpClient ?? http.Client(),
       _googleMapsApiKey =
           googleMapsApiKey?.trim() ??
           const String.fromEnvironment('GOOGLE_MAPS_API_KEY'),
       _languageCode = _normalizeLanguageCode(languageCode),
       _regionCode = regionCode.trim().toLowerCase();

  final http.Client _httpClient;
  final String _googleMapsApiKey;
  final String _languageCode;
  final String _regionCode;

  static const Duration _requestTimeout = Duration(seconds: 8);

  static const String _googleGeocodeUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Short, card-friendly area label.
  ///
  /// Preferred examples:
  ///   "Street Name, Neighborhood, City"
  ///   "Neighborhood, City"
  ///   "City"
  ///
  /// Administrative district is used only as a fallback when no more granular
  /// place is available. This prevents labels like:
  ///   "City, District"
  /// from becoming the default header when street/neighborhood data is absent.
  Future<String> getAreaNameFromCoordinates(LatLng location) async {
    if (!_isValidLocation(location)) return '';

    final googleResult = await _getAddressFromGoogle(
      location: location,
      preferShortAddress: true,
    );
    if (googleResult.isNotEmpty) return googleResult;

    return _getAddressFromPlatformFallback(
      location: location,
      preferShortAddress: true,
    );
  }

  /// Compatibility alias – delegates to [getFullAddress].
  Future<String> getAddressFromCoordinates(LatLng location) {
    return getFullAddress(location);
  }

  /// Full address for details / review screens.
  ///
  /// Preferred examples:
  ///   "Street Name, Sub-locality, Locality, District, Governorate"
  Future<String> getFullAddress(LatLng location) async {
    if (!_isValidLocation(location)) return '';

    final googleResult = await _getAddressFromGoogle(
      location: location,
      preferShortAddress: false,
    );
    if (googleResult.isNotEmpty) return googleResult;

    return _getAddressFromPlatformFallback(
      location: location,
      preferShortAddress: false,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Google Geocoding API
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _getAddressFromGoogle({
    required LatLng location,
    required bool preferShortAddress,
  }) async {
    final apiKey = _googleMapsApiKey.trim();
    if (apiKey.isEmpty) {
      debugPrint(
        '⚠️ GeocodingService: GOOGLE_MAPS_API_KEY not configured. '
        'Falling back to platform geocoding.',
      );
      return '';
    }

    try {
      final uri = Uri.parse(_googleGeocodeUrl).replace(
        queryParameters: {
          'latlng': '${location.latitude},${location.longitude}',
          'key': apiKey,
          'language': _languageCode,
          if (_regionCode.isNotEmpty) 'region': _regionCode,
        },
      );

      final response = await _httpClient.get(uri).timeout(_requestTimeout);

      if (response.statusCode != 200) {
        debugPrint(
          '⚠️ GeocodingService: Google Geocoding HTTP ${response.statusCode}',
        );
        return '';
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return '';

      final status = decoded['status']?.toString() ?? '';
      if (status != 'OK') {
        debugPrint('⚠️ GeocodingService: Google Geocoding status=$status');
        return '';
      }

      final results = decoded['results'];
      if (results is! List || results.isEmpty) return '';

      final candidates = <_AddressCandidate>[];

      for (final rawResult in results) {
        if (rawResult is! Map<String, dynamic>) continue;

        final candidate = _candidateFromGoogleResult(
          rawResult,
          preferShortAddress: preferShortAddress,
        );

        if (candidate != null) {
          candidates.add(candidate);
        }
      }

      if (candidates.isEmpty) return '';

      candidates.sort((a, b) {
        final scoreCompare = b.score.compareTo(a.score);
        if (scoreCompare != 0) return scoreCompare;

        final precisionCompare = b.precisionLevel.compareTo(a.precisionLevel);
        if (precisionCompare != 0) return precisionCompare;

        return a.address.length.compareTo(b.address.length);
      });

      return candidates.first.address;
    } on TimeoutException {
      debugPrint('⏱️ GeocodingService: Google Geocoding timeout');
      return '';
    } catch (e, stackTrace) {
      debugPrint('❌ GeocodingService: Google Geocoding failed – $e');
      debugPrintStack(stackTrace: stackTrace);
      return '';
    }
  }

  /// Converts a Google result into a ranked candidate.
  ///
  /// We do not return the first non-empty result. We score every candidate and
  /// prefer the one with the most granular address data.
  _AddressCandidate? _candidateFromGoogleResult(
    Map<String, dynamic> result, {
    required bool preferShortAddress,
  }) {
    final components = _addressComponents(result);
    if (components.isEmpty) {
      return _candidateFromFormattedAddress(result);
    }

    final street = _componentName(components, types: const {'route'});
    final streetNumber = _componentName(
      components,
      types: const {'street_number'},
    );

    final neighborhood = _componentName(
      components,
      types: const {
        'neighborhood',
        'sublocality',
        'sublocality_level_1',
        'sublocality_level_2',
        'sublocality_level_3',
      },
    );

    final locality = _componentName(components, types: const {'locality'});

    final district = _componentName(
      components,
      types: const {'administrative_area_level_2'},
    );

    final governorate = _componentName(
      components,
      types: const {'administrative_area_level_1'},
    );

    final streetLabel = _mergeStreetParts(streetNumber, street);

    final parts = preferShortAddress
        ? _buildShortAddressParts(
            streetLabel: streetLabel,
            neighborhood: neighborhood,
            locality: locality,
            district: district,
          )
        : _uniqueNonEmptyParts([
            streetLabel,
            neighborhood,
            locality,
            district,
            governorate,
          ]);

    if (parts.isEmpty) {
      return _candidateFromFormattedAddress(result);
    }

    final address = _joinParts(parts, maxParts: preferShortAddress ? 3 : 5);

    if (address.isEmpty || _isWeak(address)) {
      return _candidateFromFormattedAddress(result);
    }

    final resultTypes = _resultTypes(result);

    final precisionLevel = _precisionLevel(
      streetLabel: streetLabel,
      neighborhood: neighborhood,
      locality: locality,
      district: district,
      governorate: governorate,
    );

    final score = _scoreGoogleCandidate(
      resultTypes: resultTypes,
      streetLabel: streetLabel,
      neighborhood: neighborhood,
      locality: locality,
      district: district,
      governorate: governorate,
    );

    return _AddressCandidate(
      address: address,
      score: score,
      precisionLevel: precisionLevel,
    );
  }

  _AddressCandidate? _candidateFromFormattedAddress(
    Map<String, dynamic> result,
  ) {
    final formattedAddress = _normalize(result['formatted_address']);

    if (formattedAddress == null || _isWeak(formattedAddress)) {
      return null;
    }

    return _AddressCandidate(
      address: formattedAddress,
      score: 1,
      precisionLevel: 0,
    );
  }

  /// Short address policy:
  ///
  /// - Street exists:
  ///     Street, Neighborhood, City
  /// - No street, neighborhood exists:
  ///     Neighborhood, City
  /// - Only city exists:
  ///     City
  /// - No city, district exists:
  ///     District
  ///
  /// This deliberately avoids returning "City, District" as the common short
  /// label because district is often a broad administrative area.
  List<String> _buildShortAddressParts({
    required String streetLabel,
    required String? neighborhood,
    required String? locality,
    required String? district,
  }) {
    final street = _normalize(streetLabel);
    final area = _normalize(neighborhood);
    final city = _normalize(locality);
    final adminDistrict = _normalize(district);

    if (street != null && !_isWeak(street)) {
      return _uniqueNonEmptyParts([street, area, city ?? adminDistrict]);
    }

    if (area != null && !_isWeak(area)) {
      return _uniqueNonEmptyParts([area, city ?? adminDistrict]);
    }

    if (city != null && !_isWeak(city)) {
      return _uniqueNonEmptyParts([city]);
    }

    if (adminDistrict != null && !_isWeak(adminDistrict)) {
      return _uniqueNonEmptyParts([adminDistrict]);
    }

    return const <String>[];
  }

  int _precisionLevel({
    required String streetLabel,
    required String? neighborhood,
    required String? locality,
    required String? district,
    required String? governorate,
  }) {
    if (streetLabel.isNotEmpty && !_isWeak(streetLabel)) return 5;
    if (_hasUsefulValue(neighborhood)) return 4;
    if (_hasUsefulValue(locality)) return 3;
    if (_hasUsefulValue(district)) return 2;
    if (_hasUsefulValue(governorate)) return 1;
    return 0;
  }

  int _scoreGoogleCandidate({
    required Set<String> resultTypes,
    required String streetLabel,
    required String? neighborhood,
    required String? locality,
    required String? district,
    required String? governorate,
  }) {
    var score = 0;

    if (streetLabel.isNotEmpty && !_isWeak(streetLabel)) score += 90;
    if (_hasUsefulValue(neighborhood)) score += 55;
    if (_hasUsefulValue(locality)) score += 30;
    if (_hasUsefulValue(district)) score += 10;
    if (_hasUsefulValue(governorate)) score += 4;

    if (_hasAnyType(resultTypes, const {'street_address'})) score += 80;
    if (_hasAnyType(resultTypes, const {'route'})) score += 65;
    if (_hasAnyType(resultTypes, const {'premise', 'subpremise'})) score += 45;
    if (_hasAnyType(resultTypes, const {'neighborhood'})) score += 45;
    if (_hasAnyType(resultTypes, const {
      'sublocality',
      'sublocality_level_1',
      'sublocality_level_2',
      'sublocality_level_3',
    })) {
      score += 40;
    }
    if (_hasAnyType(resultTypes, const {'locality'})) score += 20;
    if (_hasAnyType(resultTypes, const {'administrative_area_level_2'})) {
      score += 6;
    }
    if (_hasAnyType(resultTypes, const {'administrative_area_level_1'})) {
      score += 2;
    }

    // These result types are often too broad or not useful for a user-facing
    // emergency location label unless they also contain granular components.
    if (_hasAnyType(resultTypes, const {
      'plus_code',
      'postal_code',
      'country',
    })) {
      score -= 40;
    }

    return score;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Platform Geocoding Fallback  (geocoding package)
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> _getAddressFromPlatformFallback({
    required LatLng location,
    required bool preferShortAddress,
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      ).timeout(_requestTimeout);

      if (placemarks.isEmpty) return '';

      final placemark = placemarks.first;

      final streetLabel = _mergeStreetParts(
        placemark.subThoroughfare,
        placemark.thoroughfare ?? placemark.street,
      );

      final streetOrFallbackName = streetLabel.isNotEmpty
          ? streetLabel
          : _normalize(placemark.name);

      if (preferShortAddress) {
        final parts = _buildShortAddressParts(
          streetLabel: streetOrFallbackName ?? '',
          neighborhood: placemark.subLocality,
          locality: placemark.locality,
          district: placemark.subAdministrativeArea,
        );

        return _joinParts(parts, maxParts: 3);
      }

      final parts = _uniqueNonEmptyParts([
        streetOrFallbackName,
        placemark.subLocality,
        placemark.locality,
        placemark.subAdministrativeArea,
        placemark.administrativeArea,
      ]);

      return _joinParts(parts, maxParts: 5);
    } on TimeoutException {
      debugPrint('⏱️ GeocodingService: Platform geocoding timeout');
      return '';
    } catch (e, stackTrace) {
      debugPrint('❌ GeocodingService: Platform geocoding failed – $e');
      debugPrintStack(stackTrace: stackTrace);
      return '';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Address-component helpers
  // ─────────────────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> _addressComponents(Map<String, dynamic> result) {
    final rawComponents = result['address_components'];
    if (rawComponents is! List) return const <Map<String, dynamic>>[];

    return rawComponents
        .whereType<Map>()
        .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
        .toList(growable: false);
  }

  Set<String> _resultTypes(Map<String, dynamic> result) {
    final rawTypes = result['types'];
    if (rawTypes is! List) return const <String>{};

    return rawTypes.map((type) => type.toString()).toSet();
  }

  String? _componentName(
    List<Map<String, dynamic>> components, {
    required Set<String> types,
  }) {
    for (final component in components) {
      final rawTypes = component['types'];
      if (rawTypes is! List) continue;

      final hasMatch = rawTypes
          .map((type) => type.toString())
          .any(types.contains);

      if (!hasMatch) continue;

      final name = _normalize(component['long_name']);
      if (name != null && !_isWeak(name)) return name;
    }

    return null;
  }

  bool _hasAnyType(Set<String> source, Set<String> target) {
    for (final item in target) {
      if (source.contains(item)) return true;
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // String helpers
  // ─────────────────────────────────────────────────────────────────────────

  String _mergeStreetParts(String? number, String? road) {
    final n = _normalize(number);
    final r = _normalize(road);

    if (n != null && !_isWeak(n) && r != null && !_isWeak(r)) {
      return '$n $r';
    }

    if (r != null && !_isWeak(r)) return r;
    if (n != null && !_isWeak(n)) return n;

    return '';
  }

  List<String> _uniqueNonEmptyParts(List<String?> rawParts) {
    final output = <String>[];
    final seen = <String>{};

    for (final rawPart in rawParts) {
      final part = _normalize(rawPart);

      if (part == null) continue;
      if (_isWeak(part)) continue;

      final key = part.toLowerCase();
      if (seen.contains(key)) continue;

      seen.add(key);
      output.add(part);
    }

    return output;
  }

  String _joinParts(List<String> parts, {required int maxParts}) {
    if (parts.isEmpty) return '';
    return parts.take(maxParts).join('، ');
  }

  String? _normalize(dynamic value) {
    final trimmed = value?.toString().trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final normalized = trimmed.replaceAll(RegExp(r'\s+'), ' ');
    return normalized.isEmpty ? null : normalized;
  }

  bool _hasUsefulValue(String? value) {
    final normalized = _normalize(value);
    return normalized != null && !_isWeak(normalized);
  }

  bool _isWeak(String value) {
    final v = value.trim().toLowerCase();
    if (v.length <= 1) return true;

    const weakSet = <String>{
      'unknown',
      'null',
      'unnamed road',
      'unnamed street',
      'plus code',
      'jordan',
      'الأردن',
      'طريق بلا اسم',
      'شارع بلا اسم',
    };

    if (weakSet.contains(v)) return true;

    if (RegExp(r'^[0-9a-z]{4}\+[0-9a-z]{2,}').hasMatch(v)) {
      return true;
    }

    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Coordinate validation
  // ─────────────────────────────────────────────────────────────────────────

  bool _isValidLocation(LatLng location) {
    final lat = location.latitude;
    final lng = location.longitude;

    return !lat.isNaN &&
        !lat.isInfinite &&
        !lng.isNaN &&
        !lng.isInfinite &&
        lat >= -90.0 &&
        lat <= 90.0 &&
        lng >= -180.0 &&
        lng <= 180.0 &&
        !(lat == 0.0 && lng == 0.0);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Language helpers
  // ─────────────────────────────────────────────────────────────────────────

  static String _normalizeLanguageCode(String? languageCode) {
    final explicit = languageCode?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit.toLowerCase();
    }

    final deviceLanguage = PlatformDispatcher.instance.locale.languageCode
        .trim()
        .toLowerCase();

    return deviceLanguage.isEmpty ? 'ar' : deviceLanguage;
  }
}

class _AddressCandidate {
  const _AddressCandidate({
    required this.address,
    required this.score,
    required this.precisionLevel,
  });

  final String address;
  final int score;
  final int precisionLevel;
}
