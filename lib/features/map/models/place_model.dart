import 'dart:math' show asin, cos, sin, sqrt;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// ==========================================
/// 📍 Model: Place (Location Data)
/// ==========================================
/// يمثل بيانات الأماكن القريبة (مستشفيات، مراكز أمنية، صيدليات)
/// مدمج مع نظام Google Distance Matrix لحساب أزمة السير الحقيقية
class PlaceModel {
  final String id;
  final String name;
  final String address;
  final LatLng location;
  final PlaceType type;
  final double? rating;
  final String? phoneNumber;
  final bool isOpen;

  // 📏 المسافة بخط مستقيم (خطة بديلة - Fallback)
  final double? distanceInKm;

  // 🚗 بيانات الـ Matrix API (القيادة الفعلية في الشارع)
  final String? realDistanceText;
  final int? realDistanceValue;
  final String? durationText;
  final int? durationInSeconds;

  PlaceModel({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
    required this.type,
    this.rating,
    this.phoneNumber,
    this.isOpen = true,
    this.distanceInKm,
    this.realDistanceText,
    this.realDistanceValue,
    this.durationText,
    this.durationInSeconds,
  });

  /// تحويل من JSON (Google Places API Response)
  factory PlaceModel.fromJson(Map<String, dynamic> json, LatLng userLocation) {
    final geometry = json['geometry'];
    final location = geometry['location'];
    final placeLocation = LatLng(
      location['lat'] as double,
      location['lng'] as double,
    );

    // حساب المسافة المبدئية (Haversine) كاحتياط
    final distance = _calculateDistance(userLocation, placeLocation);

    return PlaceModel(
      id: json['place_id'] as String,
      name: json['name'] as String,
      address:
          json['vicinity'] as String? ??
          json['formatted_address'] as String? ??
          '',
      location: placeLocation,
      type: _determineType(json['types'] as List<dynamic>?),
      rating: (json['rating'] as num?)?.toDouble(),
      phoneNumber: json['formatted_phone_number'] as String?,
      distanceInKm: distance,
      isOpen: json['opening_hours']?['open_now'] as bool? ?? true,
    );
  }

  /// 🔄 دالة سحرية لنسخ الموديل وإضافة بيانات (ETA) من Matrix API
  PlaceModel copyWithMatrixData({
    String? realDistanceText,
    int? realDistanceValue,
    String? durationText,
    int? durationValue,
  }) {
    return PlaceModel(
      id: this.id,
      name: this.name,
      address: this.address,
      location: this.location,
      type: this.type,
      rating: this.rating,
      phoneNumber: this.phoneNumber,
      isOpen: this.isOpen,
      distanceInKm: this.distanceInKm, // نحتفظ بالمسافة القديمة كاحتياط
      realDistanceText: realDistanceText ?? this.realDistanceText,
      realDistanceValue: realDistanceValue ?? this.realDistanceValue,
      durationText: durationText ?? this.durationText,
      durationInSeconds: durationValue ?? this.durationInSeconds,
    );
  }

  /// تحديد نوع المكان بناءً على الـ types من API
  static PlaceType _determineType(List<dynamic>? types) {
    if (types == null || types.isEmpty) return PlaceType.other;

    final typeStrings = types.map((e) => e.toString().toLowerCase()).toList();

    if (typeStrings.contains('hospital')) {
      return PlaceType.hospital;
    } else if (typeStrings.contains(
          'doctor',
        ) || // 👈 التعديل هنا: إضافة doctor ليتوافق مع API جوجل
        typeStrings.contains('clinic') ||
        typeStrings.contains('health')) {
      return PlaceType.clinic;
    } else if (typeStrings.contains('police') ||
        typeStrings.contains('security')) {
      return PlaceType.security;
    } else if (typeStrings.contains('pharmacy') ||
        typeStrings.contains('drugstore')) {
      return PlaceType.pharmacy;
    } else if (typeStrings.contains('fire_station')) {
      return PlaceType.fireStation;
    }

    return PlaceType.other;
  }

  /// حساب المسافة بين نقطتين (Haversine Formula)
  static double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371; // نصف قطر الأرض بالكيلومتر

    final dLat = _toRadians(end.latitude - start.latitude);
    final dLng = _toRadians(end.longitude - start.longitude);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(start.latitude)) *
            cos(_toRadians(end.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  static double _toRadians(double degree) {
    return degree * (3.141592653589793 / 180);
  }

  bool get hasMatrixDistance {
    return durationText != null || realDistanceText != null;
  }
}

/// أنواع الأماكن المدعومة (تصنيف شامل)
enum PlaceType { hospital, clinic, security, pharmacy, fireStation, other }
