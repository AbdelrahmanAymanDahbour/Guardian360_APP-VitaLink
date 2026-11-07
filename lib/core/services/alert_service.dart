import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart'; // 👈 1. تم إضافة مكتبة السيرفر هنا
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/app_strings.dart';
import '../constants/app_thresholds.dart';
import '../models/alert_model.dart';
import '../models/emergency_contact_model.dart';
import '../models/medical_profile_model.dart';
import '../../features/auth/services/firebase_auth_service.dart';
import 'location_service.dart';

/// ==========================================
/// 🚨 Alert Service - Guardian 360
/// ==========================================
/// Manages alert records and alert projections.
///
/// Important architecture note:
/// - `accidents` remains the primary source of truth for emergency reports.
/// - `alerts` is a dashboard/read-optimized projection and compatibility layer.
/// - This service must not duplicate sensor detection or SOS orchestration.
///
/// Current official emergency flow:
/// SOSViewModel / OfflineSyncService
///   → FirebaseService.reportAccident()
///   → accidents collection
///   → AlertService.createAlertProjectionFromAccident()
///   → alerts projection
class AlertService {
  AlertService({
    FirebaseFirestore? firestore,
    LocationService? locationService,
    FirebaseAuthService? authService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _locationService = locationService ?? const LocationService(),
       _authService = authService ?? FirebaseAuthService();

  final FirebaseFirestore _firestore;
  final LocationService _locationService;
  final FirebaseAuthService _authService;

  static const String alertsCollection = 'alerts';
  static const String usersCollection = 'users';
  static const Duration _firestoreTimeout = Duration(seconds: 10);
  static const Duration _locationTimeout = Duration(seconds: 8);

  CollectionReference<Map<String, dynamic>> get _alertsRef =>
      _firestore.collection(alertsCollection);
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection(usersCollection);

  // ==========================================
  // 🧩 Accident → Alert Projection
  // ==========================================

  Future<bool> createAlertProjectionFromAccident({
    required String accidentId,
    required String userId,
    required double gForce,
    required double rotation,
    required double severityScore,
    required String rawSeverity,
    required String displaySeverity,
    required String detectionReason,
    required double latitude,
    required double longitude,
    required bool autoDetected,
    String? eventId,
    String? emergencySource,
    String? locationName,
    Map<String, dynamic>? userSnapshot,
    Map<String, dynamic>? medicalSnapshot,
    List<Map<String, dynamic>>? emergencyContactsSnapshot,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final safeAccidentId = _trimToNull(accidentId);
      final safeUserId = _trimToNull(userId);

      if (safeAccidentId == null || safeUserId == null) {
        debugPrint('⚠️ AlertService: invalid accident projection identifiers');
        return false;
      }

      final safeSeverityScore = _safeScore(severityScore);
      if (!_hasValidSensorValues(
        gForce: gForce,
        rotation: rotation,
        severityScore: safeSeverityScore,
      )) {
        debugPrint('⚠️ AlertService: invalid projection sensor values');
        return false;
      }

      if (!_hasValidCoordinates(latitude, longitude)) {
        debugPrint('⚠️ AlertService: invalid projection coordinates');
        return false;
      }

      final normalizedSeverity = AppThresholds.normalizeSeverityLevel(
        rawSeverity,
      );
      final severity = AlertSeverity.fromValue(normalizedSeverity);

      final resolvedEmergencySource = _resolveEmergencySource(
        explicitEmergencySource: emergencySource,
        autoDetected: autoDetected,
      );
      final source = _alertSourceFromEmergencySource(resolvedEmergencySource);

      final resolvedDisplaySeverity = _firstNotEmpty([
        displaySeverity,
        AppThresholds.severityDisplayArabic(normalizedSeverity),
        severity.displayNameArabic,
      ]);
      final resolvedReason = _firstNotEmpty([
        detectionReason,
        _defaultReasonForSource(source),
      ]);
      final needsUserData =
          _emptyToNull(userSnapshot) == null ||
          _emptyToNull(medicalSnapshot) == null ||
          _emptyListToNull(emergencyContactsSnapshot) == null;

      final userData = needsUserData
          ? await _fetchUserDataBestEffort(safeUserId)
          : null;
      final resolvedUserSnapshot =
          _emptyToNull(userSnapshot) ??
          _buildUserSnapshotFromUserData(
            userId: safeUserId,
            userData: userData,
          );
      final resolvedMedicalSnapshot =
          _emptyToNull(medicalSnapshot) ??
          _buildMedicalSnapshotFromUserData(
            userId: safeUserId,
            userData: userData,
          );
      final resolvedEmergencyContactsSnapshot =
          _emptyListToNull(emergencyContactsSnapshot) ??
          _buildEmergencyContactsSnapshotFromUserData(userData);

      final safeAdditionalData = _jsonSafeMap(additionalData);
      final alertData = _removeNullValues({
        'id': safeAccidentId,
        'accidentId': safeAccidentId,
        'userId': safeUserId,
        'gForce': gForce,
        'rotation': rotation,
        'severityScore': safeSeverityScore,
        'severity': severity.value,
        'rawSeverity': normalizedSeverity,
        'severityDisplay': resolvedDisplaySeverity,
        'detectionReason': resolvedReason,
        'autoDetected': autoDetected,
        'source': source.value,
        'emergencySource': resolvedEmergencySource,
        'alertSource': resolvedEmergencySource,
        'reportType': resolvedEmergencySource,
        'isManualSOS': resolvedEmergencySource == 'manual_sos',
        'latitude': latitude,
        'longitude': longitude,
        'location': GeoPoint(latitude, longitude),
        'locationName': _trimToNull(locationName),
        'status': AlertStatus.active.value,
        'schemaVersion': AlertModel.currentSchemaVersion,
        'isProjection': true,
        'projectionSource': 'accidents',
        'userSnapshot': _emptyToNull(resolvedUserSnapshot),
        'medicalSnapshot': _emptyToNull(resolvedMedicalSnapshot),
        'emergencyContactsSnapshot': _emptyListToNull(
          resolvedEmergencyContactsSnapshot,
        ),
        'userName': resolvedUserSnapshot?['fullName'] ?? '',
        'userPhone': resolvedUserSnapshot?['phone'] ?? '',
        'userEmail': resolvedUserSnapshot?['email'] ?? '',
        'bloodType': resolvedMedicalSnapshot?['bloodType'] ?? '',
        'chronicDiseases': resolvedMedicalSnapshot?['chronicDiseases'] ?? '',
        'allergies': resolvedMedicalSnapshot?['allergies'] ?? '',
        'medications': resolvedMedicalSnapshot?['medications'] ?? '',
        'emergencyContacts': resolvedEmergencyContactsSnapshot,
        if (_trimToNull(eventId) != null) 'eventId': eventId!.trim(),
        'additionalData': _emptyToNull(safeAdditionalData),
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'projectionCreatedAt': FieldValue.serverTimestamp(),
      });
      await _alertsRef
          .doc(safeAccidentId)
          .set(alertData, SetOptions(merge: true))
          .timeout(_firestoreTimeout);
      debugPrint(
        '✅ AlertService: Alert projection created for accident $safeAccidentId',
      );
      return true;
    } on TimeoutException {
      debugPrint('⏱️ AlertService: createAlertProjectionFromAccident timeout');
      return false;
    } catch (e, stackTrace) {
      debugPrint('❌ AlertService: Failed to create alert projection - $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  // ==========================================
  // 📝 Create Alert (تم ربطها بالسيرفر هنا 🚀)
  // ==========================================

  Future<AlertModel?> createAlert({
    required String userId,
    String? tripId,
    AlertSource source = AlertSource.autoDetection,
    bool? autoDetected,
    required double gForce,
    required double rotation,
    required double severityScore,
    required String detectionReason,
    Position? position,
    String? userName,
    String? userPhone,
    String? userEmail,
    MedicalProfileModel? medicalProfile,
    List<EmergencyContactModel>? emergencyContacts,
  }) async {
    try {
      final safeUserId = _trimToNull(userId);

      if (safeUserId == null) {
        debugPrint('⚠️ AlertService: userId is empty');
        return null;
      }

      final safeSeverityScore = _safeScore(severityScore);
      if (!_hasValidSensorValues(
        gForce: gForce,
        rotation: rotation,
        severityScore: safeSeverityScore,
      )) {
        debugPrint('⚠️ AlertService: invalid sensor values');
        return null;
      }

      final currentPosition = await _resolvePosition(position);
      if (currentPosition == null) {
        debugPrint('⚠️ AlertService: Failed to get location for alert');
        return null;
      }

      if (!_hasValidCoordinates(
        currentPosition.latitude,
        currentPosition.longitude,
      )) {
        debugPrint('⚠️ AlertService: invalid current coordinates');
        return null;
      }

      final authUser = _authService.currentUser;
      final finalUserName = _firstNotEmpty([
        userName,
        authUser?.displayName,
        'مستخدم Guardian',
      ]);
      final finalUserPhone = _firstNotEmpty([
        userPhone,
        authUser?.phoneNumber,
        '',
      ]);
      final finalUserEmail = _firstNullableNotEmpty([
        userEmail,
        authUser?.email,
      ]);
      final contactSnapshots = _buildEmergencyContactSnapshots(
        emergencyContacts,
      );
      final resolvedReason = _firstNotEmpty([
        detectionReason,
        _defaultReasonForSource(source),
      ]);

      final alert = AlertModel.create(
        userId: safeUserId,
        tripId: _trimToNull(tripId),
        source: source,
        autoDetected: autoDetected ?? source == AlertSource.autoDetection,
        gForce: gForce,
        rotation: rotation,
        severityScore: safeSeverityScore,
        detectionReason: resolvedReason,
        latitude: currentPosition.latitude,
        longitude: currentPosition.longitude,
        userName: finalUserName,
        userPhone: finalUserPhone,
        userEmail: finalUserEmail,
        bloodType: medicalProfile?.normalizedBloodType,
        chronicDiseases: medicalProfile?.normalizedChronicDiseases,
        medications: medicalProfile?.normalizedMedications,
        allergies: medicalProfile?.normalizedAllergies,
        emergencyContacts: contactSnapshots,
      );

      // 👈 2. التعديل الجوهري: إيقاف الكتابة المباشرة ومناداة السيرفر بدلاً منها
      debugPrint('📡 جاري إرسال البلاغ لغرفة العمليات (Cloud Functions)...');

      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'createEmergencyAlert',
      );
      final response = await callable.call({
        'location': {
          'lat': currentPosition.latitude,
          'lng': currentPosition.longitude,
        },
        'severity': source == AlertSource.manualSos ? 'critical' : 'high',
        'detectionReason': resolvedReason,
        // أرسلنا كل الداتا للسيرفر عشان يقدر يكتبها كاملة للداشبورد بالخطوات الجاية
        'fullData': alert.toFirestore(),
      });

      debugPrint(
        '✅ AlertService: السيرفر استلم البلاغ بنجاح: ${response.data['alertId']}',
      );

      // إرجاع المودل المحلي عشان ما نكسر شاشات الموبايل (UI)
      return alert;
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ خطأ في السيرفر: [${e.code}] ${e.message}');
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ AlertService: Failed to create alert - $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  /// Creates an alert after loading user data from Firestore.
  Future<AlertModel?> createAlertFromUserData({
    required String userId,
    String? tripId,
    AlertSource source = AlertSource.autoDetection,
    bool? autoDetected,
    required double gForce,
    required double rotation,
    required double severityScore,
    required String detectionReason,
    Position? position,
  }) async {
    try {
      final safeUserId = _trimToNull(userId);
      if (safeUserId == null) {
        debugPrint('⚠️ AlertService: userId is empty');
        return null;
      }

      final userDoc = await _usersRef
          .doc(safeUserId)
          .get()
          .timeout(_firestoreTimeout);
      if (!userDoc.exists || userDoc.data() == null) {
        debugPrint('⚠️ AlertService: User document not found: $safeUserId');
        return await createAlert(
          userId: safeUserId,
          tripId: tripId,
          source: source,
          autoDetected: autoDetected,
          gForce: gForce,
          rotation: rotation,
          severityScore: severityScore,
          detectionReason: detectionReason,
          position: position,
        );
      }

      final userData = userDoc.data()!;
      final medicalProfile = MedicalProfileModel.fromMap({
        ...userData,
        'userId': safeUserId,
      });
      final emergencyContacts = _parseEmergencyContactsFromUserData(userData);

      return await createAlert(
        userId: safeUserId,
        tripId: tripId,
        source: source,
        autoDetected: autoDetected,
        gForce: gForce,
        rotation: rotation,
        severityScore: severityScore,
        detectionReason: detectionReason,
        position: position,
        userName:
            _stringOrNull(userData['fullName']) ??
            _stringOrNull(userData['name']) ??
            _stringOrNull(userData['userName']),
        userPhone:
            _stringOrNull(userData['phone']) ??
            _stringOrNull(userData['userPhone']),
        userEmail:
            _stringOrNull(userData['email']) ??
            _stringOrNull(userData['userEmail']),
        medicalProfile: medicalProfile,
        emergencyContacts: emergencyContacts,
      );
    } on TimeoutException {
      debugPrint('⏱️ AlertService: createAlertFromUserData timeout');
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ AlertService: Failed to create alert from user data - $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  // ==========================================
  // 📖 Read Operations
  // ==========================================

  Future<AlertModel?> getAlertById(String alertId) async {
    try {
      final safeAlertId = _trimToNull(alertId);
      if (safeAlertId == null) {
        debugPrint('⚠️ AlertService: alertId is empty');
        return null;
      }

      final doc = await _alertsRef
          .doc(safeAlertId)
          .get()
          .timeout(_firestoreTimeout);
      if (!doc.exists) {
        debugPrint('⚠️ AlertService: Alert not found: $safeAlertId');
        return null;
      }

      return AlertModel.fromFirestore(doc);
    } on TimeoutException {
      debugPrint('⏱️ AlertService: getAlertById timeout');
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ AlertService: Failed to get alert - $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<List<AlertModel>> getUserAlerts(
    String userId, {
    int limit = 100,
    AlertStatus? status,
    AlertSeverity? severity,
  }) async {
    try {
      final safeUserId = _trimToNull(userId);
      if (safeUserId == null) {
        debugPrint('⚠️ AlertService: userId is empty');
        return const [];
      }

      Query<Map<String, dynamic>> query = _alertsRef.where(
        'userId',
        isEqualTo: safeUserId,
      );
      if (status != null) {
        query = query.where('status', isEqualTo: status.value);
      }

      if (severity != null) {
        query = query.where('severity', isEqualTo: severity.value);
      }

      query = query
          .orderBy('timestamp', descending: true)
          .limit(_safeLimit(limit));
      final querySnapshot = await query.get().timeout(_firestoreTimeout);

      return _parseAlertDocs(querySnapshot.docs);
    } on TimeoutException {
      debugPrint('⏱️ AlertService: getUserAlerts timeout');
      return const [];
    } catch (e, stackTrace) {
      debugPrint('❌ AlertService: Failed to get user alerts - $e');
      debugPrintStack(stackTrace: stackTrace);
      return const [];
    }
  }

  Future<List<AlertModel>> getActiveAlerts(String userId) {
    return getUserAlerts(userId, status: AlertStatus.active, limit: 10);
  }

  Future<List<AlertModel>> getTripAlerts(String tripId) async {
    try {
      final safeTripId = _trimToNull(tripId);
      if (safeTripId == null) {
        debugPrint('⚠️ AlertService: tripId is empty');
        return const [];
      }

      final querySnapshot = await _alertsRef
          .where('tripId', isEqualTo: safeTripId)
          .orderBy('timestamp', descending: true)
          .get()
          .timeout(_firestoreTimeout);
      return _parseAlertDocs(querySnapshot.docs);
    } on TimeoutException {
      debugPrint('⏱️ AlertService: getTripAlerts timeout');
      return const [];
    } catch (e, stackTrace) {
      debugPrint('❌ AlertService: Failed to get trip alerts - $e');
      debugPrintStack(stackTrace: stackTrace);
      return const [];
    }
  }

  // ==========================================
  // ✏️ Update Operations
  // ==========================================

  Future<bool> updateAlert(AlertModel alert) async {
    try {
      final safeAlertId = _trimToNull(alert.id);
      if (safeAlertId == null) {
        debugPrint('⚠️ AlertService: alert.id is empty');
        return false;
      }

      await _alertsRef
          .doc(safeAlertId)
          .set(alert.toFirestore(), SetOptions(merge: true))
          .timeout(_firestoreTimeout);
      debugPrint('✅ AlertService: Alert updated successfully: ${alert.id}');
      return true;
    } on TimeoutException {
      debugPrint('⏱️ AlertService: updateAlert timeout');
      return false;
    } catch (e, stackTrace) {
      debugPrint('❌ AlertService: Failed to update alert - $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> updateAlertStatus({
    required String alertId,
    required AlertStatus status,
    String? resolvedBy,
    String? notes,
  }) async {
    try {
      final alert = await getAlertById(alertId);
      if (alert == null) {
        debugPrint(
          '⚠️ AlertService: Alert not found for status update: $alertId',
        );
        return false;
      }

      final isFinalStatus =
          status == AlertStatus.resolved || status == AlertStatus.falseAlarm;

      final updatedAlert = alert.copyWith(
        status: status,
        resolvedTime: isFinalStatus ? DateTime.now() : alert.resolvedTime,
        resolvedBy: _trimToNull(resolvedBy) ?? alert.resolvedBy,
        notes: _trimToNull(notes) ?? alert.notes,
      );
      return updateAlert(updatedAlert);
    } catch (e, stackTrace) {
      debugPrint('❌ AlertService: Failed to update alert status - $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> recordUserResponse({
    required String alertId,
    required String response,
  }) async {
    try {
      final alert = await getAlertById(alertId);
      if (alert == null) {
        debugPrint('⚠️ AlertService: Alert not found for response: $alertId');
        return false;
      }

      final normalizedResponse = response.trim().toLowerCase();
      if (normalizedResponse.isEmpty) {
        debugPrint('⚠️ AlertService: empty user response');
        return false;
      }

      final nextStatus = switch (normalizedResponse) {
        'safe' => AlertStatus.falseAlarm,
        'need_help' => AlertStatus.escalated,
        'no_response' => AlertStatus.active,
        _ => alert.status,
      };
      final updatedAlert = alert.copyWith(
        userResponse: normalizedResponse,
        userResponseTime: DateTime.now(),
        status: nextStatus,
      );
      return updateAlert(updatedAlert);
    } catch (e, stackTrace) {
      debugPrint('❌ AlertService: Failed to record user response - $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<bool> markAsFalseAlarm(String alertId, {String? notes}) {
    return updateAlertStatus(
      alertId: alertId,
      status: AlertStatus.falseAlarm,
      notes: notes ?? AppStrings.accidentFalsePositive,
    );
  }

  Future<bool> resolveAlert(
    String alertId, {
    String? resolvedBy,
    String? notes,
  }) {
    return updateAlertStatus(
      alertId: alertId,
      status: AlertStatus.resolved,
      resolvedBy: resolvedBy,
      notes: notes,
    );
  }

  // ==========================================
  // 📡 Real-time Streams
  // ==========================================

  Stream<List<AlertModel>> watchUserAlerts(String userId, {int limit = 20}) {
    final safeUserId = _trimToNull(userId);
    if (safeUserId == null) {
      return Stream.value(const []);
    }

    return _alertsRef
        .where('userId', isEqualTo: safeUserId)
        .orderBy('timestamp', descending: true)
        .limit(_safeLimit(limit))
        .snapshots()
        .map((snapshot) => _parseAlertDocs(snapshot.docs))
        .handleError((Object error, StackTrace stackTrace) {
          debugPrint('❌ AlertService: watchUserAlerts stream error - $error');
          debugPrintStack(stackTrace: stackTrace);
        });
  }

  Stream<AlertModel?> watchAlert(String alertId) {
    final safeAlertId = _trimToNull(alertId);
    if (safeAlertId == null) {
      return Stream.value(null);
    }

    return _alertsRef
        .doc(safeAlertId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return AlertModel.fromFirestore(doc);
        })
        .handleError((Object error, StackTrace stackTrace) {
          debugPrint('❌ AlertService: watchAlert stream error - $error');

          debugPrintStack(stackTrace: stackTrace);
        });
  }

  Stream<List<AlertModel>> watchActiveAlerts(String userId) {
    final safeUserId = _trimToNull(userId);
    if (safeUserId == null) {
      return Stream.value(const []);
    }

    return _alertsRef
        .where('userId', isEqualTo: safeUserId)
        .where('status', isEqualTo: AlertStatus.active.value)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => _parseAlertDocs(snapshot.docs))
        .handleError((Object error, StackTrace stackTrace) {
          debugPrint('❌ AlertService: watchActiveAlerts stream error - $error');
          debugPrintStack(stackTrace: stackTrace);
        });
  }

  // ==========================================
  // 🗑️ Delete Operations
  // ==========================================

  Future<bool> deleteAlert(String alertId) async {
    try {
      final safeAlertId = _trimToNull(alertId);
      if (safeAlertId == null) {
        debugPrint('⚠️ AlertService: alertId is empty');
        return false;
      }

      await _alertsRef.doc(safeAlertId).delete().timeout(_firestoreTimeout);

      debugPrint('✅ AlertService: Alert deleted successfully: $safeAlertId');
      return true;
    } on TimeoutException {
      debugPrint('⏱️ AlertService: deleteAlert timeout');
      return false;
    } catch (e, stackTrace) {
      debugPrint('❌ AlertService: Failed to delete alert - $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  // ==========================================
  // 📊 Analytics & Statistics
  // ==========================================

  Future<Map<String, dynamic>> getAlertStatistics(String userId) async {
    try {
      final alerts = await getUserAlerts(userId, limit: 1000);
      final totalAlerts = alerts.length;
      final activeAlerts = alerts
          .where((a) => a.status == AlertStatus.active)
          .length;
      final resolvedAlerts = alerts
          .where((a) => a.status == AlertStatus.resolved)
          .length;
      final falseAlarms = alerts
          .where((a) => a.status == AlertStatus.falseAlarm)
          .length;
      final criticalAlerts = alerts
          .where((a) => a.severity == AlertSeverity.critical)
          .length;
      final manualAlerts = alerts
          .where((a) => a.source == AlertSource.manualSos)
          .length;
      final autoAlerts = alerts
          .where((a) => a.source == AlertSource.autoDetection)
          .length;
      var averageResponseTime = 0.0;
      var responsesCount = 0;

      for (final alert in alerts) {
        final responseTime = alert.responseTimeSeconds;
        if (responseTime != null) {
          averageResponseTime += responseTime;
          responsesCount++;
        }
      }

      if (responsesCount > 0) {
        averageResponseTime = averageResponseTime / responsesCount;
      }

      final falseAlarmRate = totalAlerts > 0
          ? (falseAlarms / totalAlerts) * 100
          : 0.0;
      return {
        'totalAlerts': totalAlerts,
        'activeAlerts': activeAlerts,
        'resolvedAlerts': resolvedAlerts,
        'falseAlarms': falseAlarms,
        'criticalAlerts': criticalAlerts,
        'manualAlerts': manualAlerts,
        'autoAlerts': autoAlerts,
        'falseAlarmRate': falseAlarmRate,
        'averageResponseTimeSeconds': averageResponseTime,
      };
    } catch (e, stackTrace) {
      debugPrint('❌ AlertService: Failed to get alert statistics - $e');
      debugPrintStack(stackTrace: stackTrace);
      return const {};
    }
  }

  // ==========================================
  // Private Helpers
  // ==========================================

  Future<Position?> _resolvePosition(Position? providedPosition) async {
    if (providedPosition != null) return providedPosition;
    try {
      return await _locationService.getCurrentPosition().timeout(
        _locationTimeout,
      );
    } on TimeoutException {
      debugPrint('⏱️ AlertService: location timeout');
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ AlertService: failed to resolve location - $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchUserDataBestEffort(String userId) async {
    try {
      final doc = await _usersRef.doc(userId).get().timeout(_firestoreTimeout);
      if (!doc.exists || doc.data() == null) return null;

      return doc.data();
    } catch (e, stackTrace) {
      debugPrint('⚠️ AlertService: user data best-effort fetch failed - $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Map<String, dynamic>? _buildUserSnapshotFromUserData({
    required String userId,
    required Map<String, dynamic>? userData,
  }) {
    if (userData == null) {
      return _removeNullValues({'uid': userId, 'userId': userId});
    }

    return _removeNullValues({
      'uid': userId,
      'userId': userId,
      'fullName':
          _stringOrNull(userData['fullName']) ??
          _stringOrNull(userData['name']) ??
          _stringOrNull(userData['userName']),
      'phone':
          _stringOrNull(userData['phone']) ??
          _stringOrNull(userData['userPhone']),
      'email':
          _stringOrNull(userData['email']) ??
          _stringOrNull(userData['userEmail']),
      'isProfileComplete': userData['isProfileComplete'],
      'isMedicalProfileComplete': userData['isMedicalProfileComplete'],
      'hasEmergencyContacts': userData['hasEmergencyContacts'],
    });
  }

  Map<String, dynamic>? _buildMedicalSnapshotFromUserData({
    required String userId,
    required Map<String, dynamic>? userData,
  }) {
    if (userData == null) return null;
    final profile = MedicalProfileModel.fromMap({
      ...userData,
      'userId': userId,
    });
    final snapshot = profile.toEmergencySnapshot();

    return _removeNullValues({
      ...snapshot,
      'isMedicalProfileComplete': profile.hasRequiredEmergencyData,
      'completionPercentage': profile.calculateCompletion(),
      'medicalProfileUpdatedAt': userData['medicalProfileUpdatedAt'],
    });
  }

  List<Map<String, dynamic>>? _buildEmergencyContactsSnapshotFromUserData(
    Map<String, dynamic>? userData,
  ) {
    if (userData == null) return null;
    final contacts = <Map<String, dynamic>>[];

    final primaryContact = _asStringKeyMap(userData['primaryEmergencyContact']);

    if (primaryContact != null) {
      final name = _stringOrNull(primaryContact['name']);
      final phone = _stringOrNull(primaryContact['phone']);

      if (name != null || phone != null) {
        contacts.add(
          _removeNullValues({
            'name': name ?? '',
            'phone': phone ?? '',
            'relation': _stringOrNull(primaryContact['relation']) ?? 'أساسي',
            'priority': _toInt(primaryContact['priority'], fallback: 1),

            'isPrimary': true,
          }),
        );
      }
    }

    final extraContacts = userData['extraEmergencyContacts'];
    if (extraContacts is List) {
      for (final item in extraContacts) {
        final contactMap = _asStringKeyMap(item);
        if (contactMap == null) continue;

        final name = _stringOrNull(contactMap['name']);
        final phone = _stringOrNull(contactMap['phone']);
        if (name == null && phone == null) continue;

        contacts.add(
          _removeNullValues({
            'name': name ?? '',
            'phone': phone ?? '',
            'relation': _stringOrNull(contactMap['relation']),
            'priority': _toInt(
              contactMap['priority'],

              fallback: contacts.length + 1,
            ),
            'isPrimary': _toBool(contactMap['isPrimary'], fallback: false),
          }),
        );
      }
    }

    return contacts.isEmpty ? null : contacts;
  }

  List<AlertModel> _parseAlertDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final alerts = <AlertModel>[];
    for (final doc in docs) {
      try {
        alerts.add(AlertModel.fromFirestore(doc));
      } catch (e, stackTrace) {
        debugPrint('⚠️ AlertService: skipped invalid alert doc ${doc.id} - $e');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    return alerts;
  }

  List<EmergencyContactSnapshot> _buildEmergencyContactSnapshots(
    List<EmergencyContactModel>? contacts,
  ) {
    if (contacts == null || contacts.isEmpty) {
      return const [];
    }

    final snapshots = <EmergencyContactSnapshot>[];

    for (final contact in contacts) {
      final name = contact.name.trim();
      final phone = contact.phone.trim();

      if (name.isEmpty && phone.isEmpty) continue;

      snapshots.add(
        EmergencyContactSnapshot(
          name: name,
          phone: phone,
          relation: _trimToNull(contact.relation),
        ),
      );
    }

    return List.unmodifiable(snapshots);
  }

  List<EmergencyContactModel> _parseEmergencyContactsFromUserData(
    Map<String, dynamic> userData,
  ) {
    final contacts = <EmergencyContactModel>[];
    final primaryContact = _asStringKeyMap(userData['primaryEmergencyContact']);

    if (primaryContact != null) {
      final primaryName = _stringOrNull(primaryContact['name']) ?? '';
      final primaryPhone = _stringOrNull(primaryContact['phone']) ?? '';

      if (primaryName.isNotEmpty || primaryPhone.isNotEmpty) {
        contacts.add(
          EmergencyContactModel.create(
            name: primaryName,
            phone: primaryPhone,
            relation: _stringOrNull(primaryContact['relation']) ?? 'أساسي',
            priority: 1,
          ),
        );
      }
    }

    final contactsData = userData['extraEmergencyContacts'];
    if (contactsData is List) {
      for (final item in contactsData) {
        final itemMap = _asStringKeyMap(item);
        if (itemMap == null) continue;

        try {
          contacts.add(EmergencyContactModel.fromMap(itemMap));
        } catch (e) {
          debugPrint('⚠️ AlertService: skipped invalid emergency contact - $e');
        }
      }
    }

    return contacts;
  }

  AlertSource _alertSourceFromEmergencySource(String emergencySource) {
    switch (emergencySource) {
      case 'manual_sos':
        return AlertSource.manualSos;
      case 'auto_detection':
        return AlertSource.autoDetection;
      default:
        return AlertSource.unknown;
    }
  }

  String _resolveEmergencySource({
    String? explicitEmergencySource,
    required bool autoDetected,
  }) {
    final normalized = explicitEmergencySource?.trim().toLowerCase();
    if (normalized == 'manual_sos' || normalized == 'auto_detection') {
      return normalized!;
    }

    return autoDetected ? 'auto_detection' : 'manual_sos';
  }

  bool _hasValidSensorValues({
    required double gForce,
    required double rotation,
    required double severityScore,
  }) {
    return _isFiniteNumber(gForce) &&
        _isFiniteNumber(rotation) &&
        _isFiniteNumber(severityScore) &&
        gForce >= 0.0 &&
        rotation >= 0.0 &&
        severityScore >= 0.0 &&
        severityScore <= 100.0;
  }

  bool _hasValidCoordinates(double latitude, double longitude) {
    return _isFiniteNumber(latitude) &&
        _isFiniteNumber(longitude) &&
        latitude >= -90.0 &&
        latitude <= 90.0 &&
        longitude >= -180.0 &&
        longitude <= 180.0 &&
        !(latitude == 0.0 && longitude == 0.0);
  }

  bool _isFiniteNumber(double value) {
    return !value.isNaN && !value.isInfinite;
  }

  double _safeScore(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    return value.clamp(0.0, 100.0).toDouble();
  }

  int _safeLimit(int limit) {
    if (limit <= 0) return 20;
    if (limit > 1000) return 1000;
    return limit;
  }

  String _defaultReasonForSource(AlertSource source) {
    switch (source) {
      case AlertSource.autoDetection:
        return 'Auto accident detection triggered';
      case AlertSource.manualSos:
        return 'Manual SOS triggered by user';
      case AlertSource.croquis:
        return 'Croquis report submitted';
      case AlertSource.safeArrival:
        return 'Safe arrival emergency alert triggered';
      case AlertSource.unknown:
        return 'Emergency alert triggered';
    }
  }

  String _firstNotEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }

    return '';
  }

  String? _firstNullableNotEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }

    return null;
  }

  String? _trimToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  int _toInt(dynamic value, {required int fallback}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim()) ?? fallback;
    }

    return fallback;
  }

  bool _toBool(dynamic value, {required bool fallback}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (['true', '1', 'yes', 'y'].contains(normalized)) return true;
      if (['false', '0', 'no', 'n'].contains(normalized)) return false;
    }

    return fallback;
  }

  Map<String, dynamic>? _asStringKeyMap(dynamic value) {
    if (value is! Map) return null;
    return value.map(
      (key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
    );
  }

  Map<String, dynamic> _jsonSafeMap(Map<String, dynamic>? input) {
    if (input == null || input.isEmpty) {
      return const <String, dynamic>{};
    }

    final output = <String, dynamic>{};

    input.forEach((key, value) {
      final safeKey = key.trim();
      if (safeKey.isEmpty) return;

      final safeValue = _jsonSafeValue(value);
      if (safeValue != null) {
        output[safeKey] = safeValue;
      }
    });
    return output;
  }

  dynamic _jsonSafeValue(dynamic value) {
    if (value == null) return null;
    if (value is String || value is bool) return value;
    if (value is num) {
      if (value.isNaN || value.isInfinite) return null;
      return value;
    }

    if (value is DateTime) {
      return value.toIso8601String();
    }

    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }

    if (value is GeoPoint) {
      return {'latitude': value.latitude, 'longitude': value.longitude};
    }

    if (value is List) {
      return value
          .map(_jsonSafeValue)
          .where((element) => element != null)
          .toList();
    }

    if (value is Map) {
      return _jsonSafeMap(
        value.map(
          (key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
        ),
      );
    }

    return value.toString();
  }

  Map<String, dynamic> _removeNullValues(Map<String, dynamic> map) {
    final result = Map<String, dynamic>.from(map);
    result.removeWhere((_, value) => value == null);
    return result;
  }

  Map<String, dynamic>? _emptyToNull(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return null;
    return map;
  }

  List<Map<String, dynamic>>? _emptyListToNull(
    List<Map<String, dynamic>>? list,
  ) {
    if (list == null || list.isEmpty) return null;
    return list;
  }
}
