import 'package:cloud_firestore/cloud_firestore.dart';

/// ==========================================
/// 📍 Safe Arrival Destination Model
/// ==========================================
/// Represents a trusted destination selected by the user.
///
/// Rules:
/// - A valid Safe Arrival destination must come from a trusted provider.
/// - Free text typed by the user must never become a valid destination by itself.
/// - A valid destination must have:
///   1. placeId
///   2. readable name
///   3. valid latitude/longitude
class SafeArrivalDestinationModel {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String provider;
  final DateTime? resolvedAt;

  const SafeArrivalDestinationModel({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.provider = 'google_places',
    this.resolvedAt,
  });

  factory SafeArrivalDestinationModel.fromTrustedPlace({
    required String placeId,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    String provider = 'google_places',
    DateTime? resolvedAt,
  }) {
    return SafeArrivalDestinationModel(
      placeId: _cleanText(placeId),
      name: _cleanText(name),
      address: _cleanText(address),
      latitude: latitude,
      longitude: longitude,
      provider: _cleanProvider(provider),
      resolvedAt: resolvedAt ?? DateTime.now(),
    );
  }

  factory SafeArrivalDestinationModel.fromMap(Map<String, dynamic> map) {
    return SafeArrivalDestinationModel(
      placeId: _stringOrFallback(map['placeId']),
      name: _stringOrFallback(map['name']),
      address: _stringOrFallback(map['address']),
      latitude: _toDouble(map['latitude']) ?? 0.0,
      longitude: _toDouble(map['longitude']) ?? 0.0,
      provider: _cleanProvider(
        _stringOrFallback(map['provider'], fallback: 'google_places'),
      ),
      resolvedAt: _toDateTime(map['resolvedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return _removeNullValues({
      'placeId': placeId,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'location': hasValidCoordinates ? GeoPoint(latitude, longitude) : null,
      'provider': provider,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
    });
  }

  SafeArrivalDestinationModel copyWith({
    String? placeId,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    String? provider,
    DateTime? resolvedAt,
  }) {
    return SafeArrivalDestinationModel(
      placeId: placeId != null ? _cleanText(placeId) : this.placeId,
      name: name != null ? _cleanText(name) : this.name,
      address: address != null ? _cleanText(address) : this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      provider: provider != null ? _cleanProvider(provider) : this.provider,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }

  bool get hasPlaceId => placeId.trim().isNotEmpty;

  bool get hasName => name.trim().isNotEmpty;

  bool get hasAddress => address.trim().isNotEmpty;

  bool get hasValidProvider => provider.trim().isNotEmpty;

  bool get hasValidCoordinates {
    return _hasValidCoordinates(latitude, longitude);
  }

  bool get isValid {
    return hasPlaceId && hasName && hasValidProvider && hasValidCoordinates;
  }

  String get displayName {
    final safeName = name.trim();
    if (safeName.isNotEmpty) return safeName;

    final safeAddress = address.trim();
    if (safeAddress.isNotEmpty) return safeAddress;

    final safePlaceId = placeId.trim();
    if (safePlaceId.isNotEmpty) return safePlaceId;

    return '';
  }

  String get displayAddress {
    final safeAddress = address.trim();
    if (safeAddress.isNotEmpty) return safeAddress;

    return displayName;
  }

  GeoPoint? get geoPoint {
    if (!hasValidCoordinates) return null;
    return GeoPoint(latitude, longitude);
  }

  Uri? get googleMapsUri {
    if (!hasValidCoordinates) return null;

    return Uri.https('www.google.com', '/maps/search/', <String, String>{
      'api': '1',
      'query': '$latitude,$longitude',
      if (placeId.trim().isNotEmpty) 'query_place_id': placeId.trim(),
    });
  }

  String get googleMapsUrl {
    return googleMapsUri?.toString() ?? '';
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

  static String _cleanText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _cleanProvider(String value) {
    final safeValue = _cleanText(value);
    return safeValue.isEmpty ? 'google_places' : safeValue;
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

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }

    if (value is String) {
      return DateTime.tryParse(value.trim());
    }

    return null;
  }

  static Map<String, dynamic> _removeNullValues(Map<String, dynamic> map) {
    final result = Map<String, dynamic>.from(map);
    result.removeWhere((_, value) => value == null);
    return result;
  }

  @override
  String toString() {
    return 'SafeArrivalDestinationModel('
        'placeId: $placeId, '
        'name: $name, '
        'latitude: $latitude, '
        'longitude: $longitude, '
        'provider: $provider, '
        'isValid: $isValid'
        ')';
  }
}
