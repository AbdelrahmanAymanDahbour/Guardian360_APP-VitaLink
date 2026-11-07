import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/trip_model.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/trip_service.dart';
import '../../auth/services/firebase_auth_service.dart';

/// ==========================================
/// 🚗 Trip ViewModel - Guardian 360
/// ==========================================
/// مسؤول عن دورة حياة الرحلة فقط:
/// - بدء الرحلة
/// - إنهاء الرحلة
/// - إلغاء الرحلة
/// - تحميل الرحلة النشطة
/// - تسجيل metadata مرتبطة بالرحلة
///
/// ملاحظة مهمة:
/// لم يعد هذا الملف يحلل الحوادث مباشرة.
/// تحليل الحوادث أصبح مسؤولية:
/// AccidentMonitorViewModel + AccidentDetectionEngine الجديدة
class TripViewModel extends ChangeNotifier {
  TripViewModel({
    TripService? tripService,
    LocationService? locationService,
    FirebaseAuthService? authService,
  }) : _tripService = tripService ?? TripService(),
       _locationService = locationService ?? const LocationService(),
       _authService = authService ?? FirebaseAuthService();

  final TripService _tripService;
  final LocationService _locationService;
  final FirebaseAuthService _authService;

  // ==========================================
  // 📦 State
  // ==========================================

  TripModel? _currentTrip;
  bool _isLoading = false;
  String _statusMessage = AppStrings.tripInactive;
  String _sensitivityLevel = 'medium';

  // آخر قراءة detection مرتبطة بالرحلة - للاستخدام المستقبلي فقط
  double? _lastRecordedGForce;
  double? _lastRecordedRotation;
  DateTime? _lastDetectionRecordedAt;
  bool _lastDetectionWasFalsePositive = false;

  // ==========================================
  // 📖 Getters
  // ==========================================

  TripModel? get currentTrip => _currentTrip;
  bool get isTripActive => _currentTrip != null && _currentTrip!.isActive;
  bool get isLoading => _isLoading;
  String get statusMessage => _statusMessage;
  String get sensitivityLevel => _sensitivityLevel;
  String get tripStatus => _statusMessage;

  double? get lastRecordedGForce => _lastRecordedGForce;
  double? get lastRecordedRotation => _lastRecordedRotation;
  DateTime? get lastDetectionRecordedAt => _lastDetectionRecordedAt;
  bool get lastDetectionWasFalsePositive => _lastDetectionWasFalsePositive;

  // ==========================================
  // 🚀 Trip Management
  // ==========================================

  Future<bool> startTrip({
    String? destination,
    int? estimatedDurationMinutes,
  }) async {
    if (_isLoading) return false;

    _isLoading = true;
    _statusMessage = 'جاري بدء الرحلة...';
    notifyListeners();

    try {
      final user = _authService.currentUser;
      if (user == null) {
        _statusMessage = AppStrings.errorUserNotLoggedIn;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final position = await _locationService.getCurrentPosition();

      final trip = await _tripService.createTrip(
        userId: user.uid,
        destination: destination,
        estimatedDurationMinutes: estimatedDurationMinutes,
        startLatitude: position?.latitude,
        startLongitude: position?.longitude,
        sensitivityLevel: _sensitivityLevel,
      );

      if (trip == null) {
        _statusMessage = 'فشل بدء الرحلة';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentTrip = trip;
      _statusMessage = AppStrings.tripActive;
      _isLoading = false;
      HapticFeedback.mediumImpact();
      notifyListeners();

      debugPrint('✅ TripViewModel: Trip started successfully: ${trip.id}');
      return true;
    } catch (e) {
      debugPrint('❌ TripViewModel: Failed to start trip - $e');
      _statusMessage = 'حدث خطأ أثناء بدء الرحلة';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> endTripSafely() async {
    if (_currentTrip == null || _isLoading) return false;

    _isLoading = true;
    _statusMessage = 'جاري إنهاء الرحلة...';
    notifyListeners();

    try {
      final position = await _locationService.getCurrentPosition();

      final success = await _tripService.endTrip(
        tripId: _currentTrip!.id,
        endLatitude: position?.latitude,
        endLongitude: position?.longitude,
      );

      if (success) {
        _currentTrip = null;
        _statusMessage = AppStrings.tripEnded;
        _isLoading = false;
        _clearLastDetectionMetadata();
        HapticFeedback.heavyImpact();
        notifyListeners();

        debugPrint('✅ TripViewModel: Trip ended successfully');
        return true;
      } else {
        _statusMessage = 'فشل إنهاء الرحلة';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('❌ TripViewModel: Failed to end trip - $e');
      _statusMessage = 'حدث خطأ أثناء إنهاء الرحلة';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelTrip() async {
    if (_currentTrip == null || _isLoading) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final success = await _tripService.cancelTrip(_currentTrip!.id);

      if (success) {
        _currentTrip = null;
        _statusMessage = AppStrings.tripCancelled;
        _isLoading = false;
        _clearLastDetectionMetadata();
        notifyListeners();
        return true;
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('❌ TripViewModel: Failed to cancel trip - $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // 🚨 Detection Metadata Recording
  // ==========================================
  // هذه الطبقة لا تحلل الحادث.
  // فقط تسجل detection واردة من الطبقة الجديدة إذا احتجنا ربطها بالرحلة.

  Future<void> recordDetectionForCurrentTrip({
    required double gForce,
    required double rotation,
    bool isFalsePositive = false,
  }) async {
    if (_currentTrip == null) return;

    try {
      _lastRecordedGForce = gForce;
      _lastRecordedRotation = rotation;
      _lastDetectionRecordedAt = DateTime.now();
      _lastDetectionWasFalsePositive = isFalsePositive;

      await _tripService.recordAccidentDetection(
        tripId: _currentTrip!.id,
        gForce: gForce,
        rotation: rotation,
        isFalsePositive: isFalsePositive,
      );

      _currentTrip = await _tripService.getTripById(_currentTrip!.id);
      notifyListeners();

      debugPrint(
        '📊 TripViewModel: Detection recorded for trip '
        '(gForce=$gForce, rotation=$rotation, falsePositive=$isFalsePositive)',
      );
    } catch (e) {
      debugPrint('❌ TripViewModel: Failed to record detection - $e');
    }
  }

  Future<void> markLastDetectionAsFalsePositive() async {
    if (_currentTrip == null) return;
    if (_lastRecordedGForce == null || _lastRecordedRotation == null) return;

    try {
      await recordDetectionForCurrentTrip(
        gForce: _lastRecordedGForce!,
        rotation: _lastRecordedRotation!,
        isFalsePositive: true,
      );

      debugPrint('📊 TripViewModel: Last detection marked as false positive');
    } catch (e) {
      debugPrint('❌ TripViewModel: Failed to mark false positive - $e');
    }
  }

  void _clearLastDetectionMetadata() {
    _lastRecordedGForce = null;
    _lastRecordedRotation = null;
    _lastDetectionRecordedAt = null;
    _lastDetectionWasFalsePositive = false;
  }

  // ==========================================
  // ⚙️ Settings
  // ==========================================

  void setSensitivity(String level) {
    _sensitivityLevel = level.trim().toLowerCase();
    notifyListeners();
    debugPrint('⚙️ TripViewModel: Sensitivity changed to $_sensitivityLevel');
  }

  // ==========================================
  // 🔄 Sync & Load
  // ==========================================

  Future<void> loadActiveTrip() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      _currentTrip = await _tripService.getActiveTrip(user.uid);
      if (_currentTrip != null) {
        _statusMessage = AppStrings.tripActive;
        _sensitivityLevel = _currentTrip!.sensitivityLevel;
      } else {
        _statusMessage = AppStrings.tripInactive;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ TripViewModel: Failed to load active trip - $e');
    }
  }
}
