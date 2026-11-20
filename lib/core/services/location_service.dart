import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/app_thresholds.dart';

/// ==========================================
/// 📍 Location Service - Guardian 360
/// ==========================================
/// خدمة خفيفة لجلب الموقع الحالي وعمليات الموقع الأساسية.
///
/// ملاحظة معمارية:
/// - GPSLocationService هو الأقوى لمسار SOS والطوارئ.
/// - LocationService هنا طبقة compatibility/service خفيفة مستخدمة في AlertService.
///
/// مسؤولة عن:
/// - فحص خدمة الموقع.
/// - فحص وطلب الصلاحيات.
/// - جلب الموقع الحالي.
/// - fallback إلى آخر موقع معروف.
/// - حساب المسافات.
///
/// غير مسؤولة عن:
/// - إرسال بلاغات.
/// - كتابة Firestore.
/// - تشغيل SOS.
/// - تتبع الرحلة الكامل.
class LocationService {
  const LocationService();

  static const Duration _serviceCheckTimeout = Duration(seconds: 5);
  static const Duration _permissionTimeout = Duration(seconds: 8);
  static const Duration _lastKnownTimeout = Duration(seconds: 4);
  static const Duration _settingsTimeout = Duration(seconds: 5);

  /// ==========================================
  /// 📍 جلب الموقع الحالي
  /// ==========================================
  ///
  /// يحاول:
  /// 1. التأكد من تشغيل خدمة الموقع.
  /// 2. التأكد من الصلاحيات.
  /// 3. جلب موقع حديث.
  /// 4. fallback إلى آخر موقع معروف عند الفشل.
  Future<Position?> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(
      seconds: AppThresholds.locationTimeoutSeconds,
    ),
  }) async {
    try {
      final serviceEnabled = await isLocationServiceEnabled();

      if (!serviceEnabled) {
        debugPrint(
          '⚠️ LocationService: Location service disabled, trying last known position.',
        );

        return getLastKnownPosition(requireServiceEnabled: false);
      }

      final hasPermission = await ensureLocationPermission();

      if (!hasPermission) {
        debugPrint('⚠️ LocationService: Location permission unavailable.');
        return null;
      }

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: accuracy,
            timeLimit: timeout,
          ),
        ).timeout(timeout + const Duration(seconds: 2));

        if (!_isUsablePosition(position)) {
          debugPrint(
            '⚠️ LocationService: Current position invalid '
            '(${position.latitude}, ${position.longitude}), trying fallback.',
          );

          return getLastKnownPosition(requireServiceEnabled: false);
        }

        debugPrint(
          '📍 LocationService: Current position fetched successfully '
          '(${position.latitude}, ${position.longitude}), '
          'accuracy=${position.accuracy.toStringAsFixed(1)}m',
        );

        return position;
      } on TimeoutException {
        debugPrint(
          '⏱️ LocationService: Current position timeout, trying last known position.',
        );
      } catch (e, stackTrace) {
        debugPrint(
          '⚠️ LocationService: Failed to fetch current position, trying fallback - $e',
        );
        debugPrintStack(stackTrace: stackTrace);
      }

      final lastKnown = await getLastKnownPosition(
        requireServiceEnabled: false,
      );

      if (lastKnown != null) {
        debugPrint(
          '📌 LocationService: Using last known position '
          '(${lastKnown.latitude}, ${lastKnown.longitude})',
        );
      } else {
        debugPrint('❌ LocationService: No current or last known position.');
      }

      return lastKnown;
    } catch (e, stackTrace) {
      debugPrint('❌ LocationService: Unexpected getCurrentPosition error - $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  /// ==========================================
  /// 🛰️ فحص خدمة الموقع
  /// ==========================================

  Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled().timeout(
        _serviceCheckTimeout,
      );
    } on TimeoutException {
      debugPrint('⏱️ LocationService: Service status check timeout');
      return false;
    } catch (e, stackTrace) {
      debugPrint('❌ LocationService: Failed to check service status - $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// ==========================================
  /// 🔐 التحقق من الصلاحيات وطلبها
  /// ==========================================

  Future<bool> ensureLocationPermission() async {
    try {
      var permission = await Geolocator.checkPermission().timeout(
        _permissionTimeout,
      );

      if (permission == LocationPermission.denied) {
        debugPrint('📍 LocationService: Requesting location permission...');
        permission = await Geolocator.requestPermission().timeout(
          _permissionTimeout,
        );
      }

      if (permission == LocationPermission.denied) {
        debugPrint('⚠️ LocationService: User denied location permission.');
        return false;
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
          '⚠️ LocationService: Location permission denied forever; app settings required.',
        );
        return false;
      }

      return true;
    } on TimeoutException {
      debugPrint('⏱️ LocationService: Permission request/check timeout');
      return false;
    } catch (e, stackTrace) {
      debugPrint('❌ LocationService: Failed to ensure permission - $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// ==========================================
  /// 📌 آخر موقع معروف
  /// ==========================================

  Future<Position?> getLastKnownPosition({
    bool requireServiceEnabled = true,
  }) async {
    try {
      if (requireServiceEnabled) {
        final serviceEnabled = await isLocationServiceEnabled();
        if (!serviceEnabled) return null;
      }

      final hasPermission = await ensureLocationPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getLastKnownPosition().timeout(
        _lastKnownTimeout,
      );

      if (position == null) {
        debugPrint('⚠️ LocationService: No last known position available.');
        return null;
      }

      if (!_isUsablePosition(position)) {
        debugPrint(
          '⚠️ LocationService: Last known position invalid '
          '(${position.latitude}, ${position.longitude})',
        );
        return null;
      }

      return position;
    } on TimeoutException {
      debugPrint('⏱️ LocationService: Last known position timeout');
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ LocationService: Failed to get last known position - $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  /// ==========================================
  /// ⚙️ فتح إعدادات الموقع
  /// ==========================================

  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings().timeout(_settingsTimeout);
    } on TimeoutException {
      debugPrint('⏱️ LocationService: Open location settings timeout');
      return false;
    } catch (e, stackTrace) {
      debugPrint('❌ LocationService: Failed to open location settings - $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// ==========================================
  /// 🔓 فتح إعدادات التطبيق
  /// ==========================================

  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings().timeout(_settingsTimeout);
    } on TimeoutException {
      debugPrint('⏱️ LocationService: Open app settings timeout');
      return false;
    } catch (e, stackTrace) {
      debugPrint('❌ LocationService: Failed to open app settings - $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// ==========================================
  /// 📏 حساب المسافة بين نقطتين بالمتر
  /// ==========================================

  double calculateDistanceInMeters({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    try {
      if (!_hasValidCoordinates(startLat, startLng) ||
          !_hasValidCoordinates(endLat, endLng)) {
        debugPrint('⚠️ LocationService: Invalid coordinates for distance.');
        return 0.0;
      }

      final distance = Geolocator.distanceBetween(
        startLat,
        startLng,
        endLat,
        endLng,
      );

      if (distance.isNaN || distance.isInfinite || distance < 0.0) {
        return 0.0;
      }

      return distance;
    } catch (e, stackTrace) {
      debugPrint('❌ LocationService: Failed to calculate distance - $e');
      debugPrintStack(stackTrace: stackTrace);
      return 0.0;
    }
  }

  /// ==========================================
  /// ✅ Validation Helpers
  /// ==========================================

  bool isValidCoordinatePair(double latitude, double longitude) {
    return _hasValidCoordinates(latitude, longitude);
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
}
