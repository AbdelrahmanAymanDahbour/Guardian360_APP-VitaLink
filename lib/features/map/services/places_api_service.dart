import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/place_model.dart';

/// ==========================================
/// 🌐 Ultra Pro Service: Google Places & Distance Matrix API
/// ==========================================
/// مسؤول عن جلب الأماكن الحيوية للطوارئ، وحساب المسافة
/// والوقت الفعلي (ETA) بناءً على حركة المرور الحالية.
class PlacesApiService {
  // 🔑 مفتاح API
  static const String _apiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  static const String _placesBaseUrl =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
  static const String _matrixBaseUrl =
      'https://maps.googleapis.com/maps/api/distancematrix/json';

  /// 🏥 جلب المستشفيات القريبة
  Future<List<PlaceModel>> fetchNearbyHospitals(
    LatLng userLocation, {
    int radius = 15000, // وسعنا الرادار لـ 15 كم عشان نغطي مأدبا وضواحيها
    required String locale,
  }) async {
    return _fetchNearbyPlaces(
      userLocation,
      type: 'hospital',
      radius: radius,
      locale: locale,
    );
  }

  /// 🩺 جلب المراكز الصحية والعيادات القريبة
  Future<List<PlaceModel>> fetchNearbyClinics(
    LatLng userLocation, {
    int radius = 15000,
    required String locale,
  }) async {
    // 🛠️ التعديل الجذري الأول: جوجل يستخدم 'doctor' للمراكز الصحية
    return _fetchNearbyPlaces(
      userLocation,
      type: 'doctor',
      radius: radius,
      locale: locale,
    );
  }

  /// 🛡️ جلب مراكز الأمن القريبة
  Future<List<PlaceModel>> fetchNearbySecurityCenters(
    LatLng userLocation, {
    int radius = 15000,
    required String locale,
  }) async {
    return _fetchNearbyPlaces(
      userLocation,
      type: 'police',
      radius: radius,
      locale: locale,
    );
  }

  /// 💊 جلب الصيدليات القريبة
  Future<List<PlaceModel>> fetchNearbyPharmacies(
    LatLng userLocation, {
    int radius = 15000,
    required String locale,
  }) async {
    return _fetchNearbyPlaces(
      userLocation,
      type: 'pharmacy',
      radius: radius,
      locale: locale,
    );
  }

  /// 🚒 جلب محطات الإطفاء القريبة
  Future<List<PlaceModel>> fetchNearbyFireStations(
    LatLng userLocation, {
    int radius = 15000,
    required String locale,
  }) async {
    return _fetchNearbyPlaces(
      userLocation,
      type: 'fire_station',
      radius: radius,
      locale: locale,
    );
  }

  /// 🚀 [Ultra Pro] جلب الأماكن، دمجها، فلترتها، وحساب الوقت الفعلي للأزمة
  Future<List<PlaceModel>> fetchNearestSafePlaces(
    LatLng userLocation, {
    int radius = 15000,
    required String locale,
  }) async {
    try {
      final language = _sanitizeLocale(locale);
      final results = await Future.wait([
        fetchNearbyHospitals(userLocation, radius: radius, locale: language),
        fetchNearbyClinics(userLocation, radius: radius, locale: language),
        fetchNearbySecurityCenters(
          userLocation,
          radius: radius,
          locale: language,
        ),
        fetchNearbyPharmacies(userLocation, radius: radius, locale: language),
        fetchNearbyFireStations(userLocation, radius: radius, locale: language),
      ]);

      final allPlaces = <PlaceModel>[];

      // 🛠️ التعديل الجذري الثاني: نأخذ أقرب 4 أماكن من كل تصنيف بدل (.first)
      // عشان إذا الأول طلع بعيد، الثاني والثالث يغطوا مكانه والشاشة ما تفضى!
      for (var placesList in results) {
        if (placesList.isNotEmpty) {
          allPlaces.addAll(placesList.take(4));
        }
      }

      // 🛡️ فلترة استباقية (Pre-filtering):
      // نحذف أي مكان تصنيفه "عام" أو مسافته أكثر من 20 كم قبل إرساله للـ Matrix
      // لمنع ظهور عمان أو أماكن عشوائية في شاشة المستخدم.
      allPlaces.removeWhere(
        (place) =>
            place.type == PlaceType.other ||
            (place.distanceInKm != null && place.distanceInKm! > 20.0),
      );

      // إذا لم نجد أي أماكن بعد الفلترة، نرجع قائمة فارغة فوراً
      if (allPlaces.isEmpty) return [];

      // 🔮 السحر الحقيقي: إرسال جميع الأماكن النظيفة لجوجل لحساب المسافة والوقت الفعلي دفعة واحدة (Batch)
      final enrichedPlaces = await _enrichWithRealDistanceAndETA(
        userLocation,
        allPlaces,
        locale: language,
      );

      // ترتيب النتائج النهائية حسب *وقت الوصول* لأن الأسرع هو الأهم في الطوارئ
      enrichedPlaces.sort((a, b) {
        final aVal =
            a.durationInSeconds ??
            (a.distanceInKm != null
                ? (a.distanceInKm! * 1000).toInt()
                : 999999);
        final bVal =
            b.durationInSeconds ??
            (b.distanceInKm != null
                ? (b.distanceInKm! * 1000).toInt()
                : 999999);
        return aVal.compareTo(bVal);
      });

      return enrichedPlaces;
    } catch (e) {
      debugPrint('❌ Error fetching nearest safe places: $e');
      return [];
    }
  }

  /// 🌐 الدالة الأساسية لجلب الأماكن من API
  Future<List<PlaceModel>> _fetchNearbyPlaces(
    LatLng userLocation, {
    required String type,
    required int radius,
    required String locale,
  }) async {
    try {
      final url = Uri.parse(_placesBaseUrl).replace(
        queryParameters: {
          'location': '${userLocation.latitude},${userLocation.longitude}',
          'radius': radius.toString(),
          'type': type,
          'key': _apiKey,
          'language': _sanitizeLocale(locale),
        },
      );

      final response = await http.get(url).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final results = data['results'] as List<dynamic>;
          return results
              .map((json) => PlaceModel.fromJson(json, userLocation))
              .toList();
        } else if (data['status'] == 'ZERO_RESULTS') {
          debugPrint('⚠️ No $type found nearby');
          return [];
        } else {
          throw 'API Error: ${data['status']} - ${data['error_message'] ?? 'Unknown error'}';
        }
      } else {
        throw 'HTTP Error: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('❌ Error fetching $type: $e');
      return [];
    }
  }

  /// ⏱️ [Matrix API] جلب المسافة والوقت الفعلي لجميع الأماكن المحددة دفعة واحدة
  Future<List<PlaceModel>> _enrichWithRealDistanceAndETA(
    LatLng origin,
    List<PlaceModel> destinations, {
    required String locale,
  }) async {
    try {
      final originsStr = '${origin.latitude},${origin.longitude}';

      final destinationsStr = destinations
          .map((p) => '${p.location.latitude},${p.location.longitude}')
          .join('|');

      final url = Uri.parse(_matrixBaseUrl).replace(
        queryParameters: {
          'origins': originsStr,
          'destinations': destinationsStr,
          'mode': 'driving',
          'departure_time': 'now',
          'language': _sanitizeLocale(locale),
          'key': _apiKey,
        },
      );

      final response = await http.get(url).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK') {
          final elements = data['rows'][0]['elements'] as List<dynamic>;

          for (int i = 0; i < destinations.length; i++) {
            final element = elements[i];

            if (element['status'] == 'OK') {
              final realDistanceText = element['distance']['text'];
              final realDistanceValue = element['distance']['value'] as int;

              final durationInfo =
                  element['duration_in_traffic'] ?? element['duration'];
              final durationText = durationInfo['text'];
              final durationValue = durationInfo['value'] as int;

              destinations[i] = destinations[i].copyWithMatrixData(
                realDistanceText: realDistanceText,
                realDistanceValue: realDistanceValue,
                durationText: durationText,
                durationValue: durationValue,
              );
            }
          }
        }
      }
      return destinations;
    } catch (e) {
      debugPrint('❌ Matrix API Error: $e');
      return destinations;
    }
  }

  /// 📍 جلب تفاصيل مكان محدد
  Future<PlaceModel?> fetchPlaceDetails(
    String placeId,
    LatLng userLocation, {
    required String locale,
  }) async {
    try {
      final url =
          Uri.parse(
            'https://maps.googleapis.com/maps/api/place/details/json',
          ).replace(
            queryParameters: {
              'place_id': placeId,
              'fields':
                  'name,formatted_address,geometry,rating,formatted_phone_number,opening_hours,types',
              'key': _apiKey,
              'language': _sanitizeLocale(locale),
            },
          );

      final response = await http.get(url).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return PlaceModel.fromJson(data['result'], userLocation);
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching place details: $e');
      return null;
    }
  }

  String _sanitizeLocale(String locale) {
    final language = locale.trim().toLowerCase();
    if (language.startsWith('ar')) return 'ar';
    return 'en';
  }
}
