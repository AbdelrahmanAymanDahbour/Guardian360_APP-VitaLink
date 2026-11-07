import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_thresholds.dart';
import '../models/medical_profile_model.dart';

class FirebaseService {
  FirebaseService({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static const String usersCollection = 'users';
  static const String accidentsCollection = 'accidents';
  static const String tripsCollection = 'trips';
  static const String alertsCollection = 'alerts';
  static const String medicalProfilesCollection = 'medical_profiles';
  static const String emergencyContactsCollection = 'emergency_contacts';

  static const String accidentImagesPath = 'accidents';
  static const String krokaImagesPath = 'kroka';
  static const String profileImagesPath = 'profiles';

  static const int _accidentSchemaVersion = 2;

  CollectionReference<Map<String, dynamic>> collection(String collectionName) {
    return _firestore.collection(collectionName);
  }

  DocumentReference<Map<String, dynamic>> document(
    String collectionName,
    String documentId,
  ) {
    return _firestore.collection(collectionName).doc(documentId);
  }

  // ==========================================
  // 👤 USER OPERATIONS
  // ==========================================

  Future<FirebaseResult<void>> createUser({
    required String uid,
    required String fullName,
    required String email,
    required String phone,
  }) async {
    try {
      final safeUid = uid.trim();

      if (safeUid.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'User ID is required',
            code: 'invalid-user-id',
          ),
        );
      }

      final userData = <String, dynamic>{
        'uid': safeUid,
        'fullName': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'phone': phone.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'isProfileComplete': false,
        'isMedicalProfileComplete': false,
        'hasEmergencyContacts': false,

        // Medical core defaults.
        'bloodType': '',
        'chronicDiseases': '',
        'allergies': '',
        'medications': '',
        'notes': '',
        'nationalId': '',
        'address': '',
        'weight': '',
        'height': '',
        'age': null,
        'dateOfBirth': null,
        'isOrganDonor': false,
        'completionPercentage': 0.0,
        'medicalProfileCompletion': 0.0,

        // Emergency contacts defaults.
        'primaryEmergencyContact': <String, dynamic>{},
        'extraEmergencyContacts': <Map<String, dynamic>>[],
      };

      await _firestore
          .collection(usersCollection)
          .doc(safeUid)
          .set(userData)
          .timeout(const Duration(seconds: 10));

      debugPrint('✅ FirebaseService: User created successfully - $safeUid');
      return FirebaseResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseService: User creation timeout - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'User creation timed out',
          code: 'user-creation-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ FirebaseService: Failed to create user - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to create user profile',
          code: 'user-creation-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<FirebaseResult<Map<String, dynamic>>> getUser(String uid) async {
    try {
      final safeUid = uid.trim();

      if (safeUid.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'User ID is required',
            code: 'invalid-user-id',
          ),
        );
      }

      final doc = await _firestore
          .collection(usersCollection)
          .doc(safeUid)
          .get()
          .timeout(const Duration(seconds: 8));

      if (!doc.exists) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'User not found',
            code: 'user-not-found',
          ),
        );
      }

      final data = doc.data();

      if (data == null) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'User data is null',
            code: 'user-data-null',
          ),
        );
      }

      return FirebaseResult.success(data);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseService: Failed to get user - timeout');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'User fetch timed out',
          code: 'user-fetch-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ FirebaseService: Failed to get user - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to fetch user data',
          code: 'user-fetch-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<FirebaseResult<void>> updateUser(
    String uid,
    Map<String, dynamic> data,
  ) async {
    try {
      final safeUid = uid.trim();

      if (safeUid.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'User ID is required',
            code: 'invalid-user-id',
          ),
        );
      }

      final updateData = _sanitizeFirestoreMap(data);
      updateData['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(usersCollection)
          .doc(safeUid)
          .set(updateData, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

      debugPrint('✅ FirebaseService: User updated successfully - $safeUid');
      return FirebaseResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseService: User update timeout - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'User update timed out',
          code: 'user-update-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ FirebaseService: Failed to update user - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to update user data',
          code: 'user-update-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ==========================================
  // 🏥 MEDICAL PROFILE OPERATIONS
  // ==========================================

  Future<FirebaseResult<void>> updateMedicalDetails({
    required String userId,
    required String fullName,
    required String nationalId,
    required String bloodType,
    required String allergies,
    required String medications,
    required String chronicDiseases,
    String? address,
    String? weight,
    String? height,
    String? notes,
    String? gender,
    DateTime? dateOfBirth,
    int? age,
    required bool isOrganDonor,
  }) async {
    try {
      final safeUserId = userId.trim();

      if (safeUserId.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'User ID is required',
            code: 'invalid-user-id',
          ),
        );
      }

      final profile = MedicalProfileModel(
        userId: safeUserId,
        fullName: fullName,
        nationalId: nationalId,
        address: address,
        dateOfBirth: dateOfBirth,
        age: age,
        bloodType: bloodType,
        weight: weight,
        height: height,
        allergies: allergies,
        medications: medications,
        chronicDiseases: chronicDiseases,
        notes: notes,
        gender: gender,
        isOrganDonor: isOrganDonor,
      );

      final validationErrors = profile.validateForEmergencySave();

      if (validationErrors.isNotEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: validationErrors.first,
            code: 'medical-validation-failed',
          ),
        );
      }

      final normalizedProfile = profile.copyWith(
        fullName: profile.normalizedFullName,
        nationalId: profile.normalizedNationalId,
        address: profile.normalizedAddress,
        dateOfBirth: profile.validDateOfBirth,
        age: profile.effectiveAge,
        bloodType: profile.normalizedBloodType,
        weight: profile.normalizedWeight,
        height: profile.normalizedHeight,
        allergies: profile.normalizedAllergies,
        medications: profile.normalizedMedications,
        chronicDiseases: profile.normalizedChronicDiseases,
        notes: profile.normalizedNotes,
        completionPercentage: profile.calculateCompletion(),
      );

      final isComplete = normalizedProfile.hasRequiredEmergencyData;
      final completionPercentage = normalizedProfile.calculateCompletion();

      // مهم:
      // لا نستخدم _removeNullValues هنا لأننا نريد السماح بمسح dateOfBirth/age
      // إذا المستخدم حذف تاريخ الميلاد أو العمر من السجل الطبي.
      final payload = <String, dynamic>{
        'fullName': normalizedProfile.normalizedFullName ?? '',
        'nationalId': normalizedProfile.normalizedNationalId ?? '',
        'bloodType': normalizedProfile.normalizedBloodType ?? '',
        'allergies': normalizedProfile.normalizedAllergies ?? '',
        'medications': normalizedProfile.normalizedMedications ?? '',
        'chronicDiseases': normalizedProfile.normalizedChronicDiseases ?? '',
        'address': normalizedProfile.normalizedAddress ?? '',
        'weight': normalizedProfile.normalizedWeight ?? '',
        'height': normalizedProfile.normalizedHeight ?? '',
        'notes': normalizedProfile.normalizedNotes ?? '',
        'gender': normalizedProfile.normalizedGender ?? '',
        'dateOfBirth': normalizedProfile.validDateOfBirth != null
            ? Timestamp.fromDate(normalizedProfile.validDateOfBirth!)
            : null,
        'age': normalizedProfile.effectiveAge,
        'isOrganDonor': normalizedProfile.isOrganDonor,
        'isMedicalProfileComplete': isComplete,
        'completionPercentage': completionPercentage,
        'medicalProfileCompletion': completionPercentage,
        if (isComplete) 'isProfileComplete': true,
        'medicalProfileUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection(usersCollection)
          .doc(safeUserId)
          .set(payload, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

      debugPrint('✅ FirebaseService: Medical details updated - $safeUserId');
      return FirebaseResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseService: Medical update timeout - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Medical update timed out',
          code: 'medical-update-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ FirebaseService: Failed to update medical details - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to update medical details',
          code: 'medical-update-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ==========================================
  // 🚨 ACCIDENT OPERATIONS
  // ==========================================

  Future<FirebaseResult<String>> reportAccident({
    required String userId,
    required double gForce,
    required double rotation,
    required double severityScore,
    required String severityLevel,
    String? severityDisplay,
    required double latitude,
    required double longitude,
    String? locationName,
    String? reason,
    bool autoDetected = true,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final safeUserId = userId.trim();

      if (safeUserId.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'User ID is required to report an accident',
            code: 'invalid-user-id',
          ),
        );
      }

      if (!_isFiniteNumber(gForce) || gForce < 0.0) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Invalid gForce value',
            code: 'invalid-gforce',
          ),
        );
      }

      if (!_isFiniteNumber(rotation) || rotation < 0.0) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Invalid rotation value',
            code: 'invalid-rotation',
          ),
        );
      }

      if (!_isFiniteNumber(severityScore)) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Invalid severityScore value',
            code: 'invalid-severity-score',
          ),
        );
      }

      if (!_hasValidCoordinates(latitude, longitude)) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Invalid coordinates',
            code: 'invalid-coordinates',
          ),
        );
      }

      final legacySource =
          _stringOrNull(additionalData?['source']) ?? 'mobile_app';

      final emergencySource = _resolveEmergencySource(
        explicitEmergencySource:
            _stringOrNull(additionalData?['emergencySource']) ??
            _stringOrNull(additionalData?['alertSource']) ??
            _stringOrNull(additionalData?['reportType']),
        source: legacySource,
        reason: reason,
        autoDetected: autoDetected,
      );

      final normalizedSeverity = _normalizeAccidentSeverity(
        severityLevel: severityLevel,
        emergencySource: emergencySource,
      );

      final resolvedSeverityScore = _resolveSeverityScore(
        severityScore: severityScore,
        severityLevel: normalizedSeverity,
        emergencySource: emergencySource,
      );

      final resolvedSeverityDisplay = _resolveSeverityDisplay(
        explicitDisplay: severityDisplay,
        severityLevel: normalizedSeverity,
        emergencySource: emergencySource,
      );

      final sanitizedAdditionalData = _sanitizeAdditionalData(additionalData);

      Map<String, dynamic>? userData;

      try {
        final userResult = await getUser(
          safeUserId,
        ).timeout(const Duration(seconds: 8));

        if (userResult.isSuccess && userResult.data != null) {
          userData = userResult.data;
        } else {
          debugPrint(
            '⚠️ FirebaseService: User snapshot unavailable for accident - ${userResult.error}',
          );
        }
      } on TimeoutException {
        debugPrint(
          '⏱️ FirebaseService: User fetch timed out; reporting accident without full snapshot',
        );
      } catch (e) {
        debugPrint(
          '⚠️ FirebaseService: User fetch failed; reporting accident without full snapshot - $e',
        );
      }

      final userSnapshot = _buildUserSnapshot(
        userId: safeUserId,
        userData: userData,
      );

      final medicalSnapshot = _buildMedicalSnapshot(userData);
      final emergencyContactsSnapshot = _buildEmergencyContactsSnapshot(
        userData,
      );

      final docRef = _firestore.collection(accidentsCollection).doc();

      final accidentData = _removeNullValues({
        ...sanitizedAdditionalData,

        // Identity
        'id': docRef.id,
        'accidentId': docRef.id,
        'userId': safeUserId,
        'schemaVersion': _accidentSchemaVersion,

        // Sensor / emergency data
        'gForce': gForce,
        'rotation': rotation,
        'severityScore': resolvedSeverityScore,
        'severity': normalizedSeverity,
        'severityLevel': normalizedSeverity,
        'severityDisplay': resolvedSeverityDisplay,

        // Location
        'location': GeoPoint(latitude, longitude),
        'latitude': latitude,
        'longitude': longitude,
        'locationName': _stringOrNull(locationName),
        'reason':
            _stringOrNull(reason) ?? _defaultAccidentReason(emergencySource),

        // Source compatibility + clean source
        'autoDetected': emergencySource == 'auto_detection',
        'source': legacySource,
        'emergencySource': emergencySource,
        'alertSource': emergencySource,
        'reportType': emergencySource,
        'isManualSOS': emergencySource == 'manual_sos',

        // Status
        'status': 'active',

        // Snapshots for dashboard / responders
        'userSnapshot': userSnapshot,
        'medicalSnapshot': medicalSnapshot,
        'emergencyContactsSnapshot': emergencyContactsSnapshot,

        // Backward-friendly flat fields for existing dashboard cards
        'userName': userSnapshot['fullName'] ?? '',
        'userPhone': userSnapshot['phone'] ?? '',
        'userEmail': userSnapshot['email'] ?? '',
        'bloodType': medicalSnapshot['bloodType'] ?? '',
        'chronicDiseases': medicalSnapshot['chronicDiseases'] ?? '',
        'allergies': medicalSnapshot['allergies'] ?? '',
        'medications': medicalSnapshot['medications'] ?? '',
        'emergencyContacts': emergencyContactsSnapshot,

        // Additional metadata preserved safely
        if (sanitizedAdditionalData.isNotEmpty)
          'additionalData': sanitizedAdditionalData,

        // Timestamps
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),

        // Device
        'deviceInfo': {
          'platform': defaultTargetPlatform.toString(),
          'reportedFrom': 'mobile_app',
        },
      });

      await docRef.set(accidentData).timeout(const Duration(seconds: 15));

      debugPrint(
        '🚨 FirebaseService: Accident reported successfully - ${docRef.id}',
      );

      return FirebaseResult.success(docRef.id);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseService: Accident report timeout - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Accident report timed out',
          code: 'accident-report-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ FirebaseService: Failed to report accident - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to report accident',
          code: 'accident-report-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<FirebaseResult<List<Map<String, dynamic>>>> getUserAccidents(
    String userId, {
    int limit = 20,
  }) async {
    try {
      final safeUserId = userId.trim();

      if (safeUserId.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'User ID is required',
            code: 'invalid-user-id',
          ),
        );
      }

      final querySnapshot = await _firestore
          .collection(accidentsCollection)
          .where('userId', isEqualTo: safeUserId)
          .orderBy('timestamp', descending: true)
          .limit(_safeLimit(limit))
          .get()
          .timeout(const Duration(seconds: 10));

      final accidents = querySnapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data()})
          .toList();

      return FirebaseResult.success(accidents);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseService: Failed to get user accidents - timeout');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Accidents fetch timed out',
          code: 'accidents-fetch-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ FirebaseService: Failed to get user accidents - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to fetch accidents',
          code: 'accidents-fetch-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Stream<List<Map<String, dynamic>>> streamUserAccidents(
    String userId, {
    int limit = 20,
  }) {
    final safeUserId = userId.trim();

    if (safeUserId.isEmpty) {
      return Stream.value(const []);
    }

    return _firestore
        .collection(accidentsCollection)
        .where('userId', isEqualTo: safeUserId)
        .orderBy('timestamp', descending: true)
        .limit(_safeLimit(limit))
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList();
        })
        .handleError((Object error, StackTrace stackTrace) {
          debugPrint(
            '❌ FirebaseService: streamUserAccidents stream error - $error',
          );
          debugPrintStack(stackTrace: stackTrace);
        });
  }

  Future<FirebaseResult<void>> updateAccidentStatus(
    String accidentId,
    String status,
  ) async {
    try {
      final safeAccidentId = accidentId.trim();
      final safeStatus = status.trim();

      if (safeAccidentId.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Accident ID is required',
            code: 'invalid-accident-id',
          ),
        );
      }

      if (safeStatus.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Status is required',
            code: 'invalid-status',
          ),
        );
      }

      await _firestore
          .collection(accidentsCollection)
          .doc(safeAccidentId)
          .set({
            'status': safeStatus,
            'statusUpdatedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(const Duration(seconds: 10));

      debugPrint(
        '✅ FirebaseService: Accident status updated - $safeAccidentId: $safeStatus',
      );

      return FirebaseResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseService: Accident status update timeout - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Accident status update timed out',
          code: 'accident-update-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ FirebaseService: Failed to update accident status - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to update accident status',
          code: 'accident-update-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ==========================================
  // 🚗 TRIP OPERATIONS
  // ==========================================

  Future<FirebaseResult<String>> startTrip({
    required String userId,
    required String destination,
    required double startLatitude,
    required double startLongitude,
    String? startLocationName,
    DateTime? estimatedArrival,
  }) async {
    try {
      final safeUserId = userId.trim();
      final safeDestination = destination.trim();

      if (safeUserId.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'User ID is required',
            code: 'invalid-user-id',
          ),
        );
      }

      if (safeDestination.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Destination is required',
            code: 'invalid-destination',
          ),
        );
      }

      if (!_hasValidCoordinates(startLatitude, startLongitude)) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Invalid start coordinates',
            code: 'invalid-coordinates',
          ),
        );
      }

      final tripData = <String, dynamic>{
        'userId': safeUserId,
        'destination': safeDestination,
        'startLocation': GeoPoint(startLatitude, startLongitude),
        'startLatitude': startLatitude,
        'startLongitude': startLongitude,
        'startLocationName': _stringOrNull(startLocationName),
        'estimatedArrival': estimatedArrival != null
            ? Timestamp.fromDate(estimatedArrival)
            : null,
        'status': 'active',
        'startTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore
          .collection(tripsCollection)
          .add(_removeNullValues(tripData))
          .timeout(const Duration(seconds: 10));

      debugPrint('🚗 FirebaseService: Trip started - ${docRef.id}');
      return FirebaseResult.success(docRef.id);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseService: Trip start timeout - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Trip start timed out',
          code: 'trip-start-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ FirebaseService: Failed to start trip - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to start trip',
          code: 'trip-start-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<FirebaseResult<void>> updateTripLocation({
    required String tripId,
    required double latitude,
    required double longitude,
    String? currentLocationName,
    required double totalDistance,
  }) async {
    try {
      final safeTripId = tripId.trim();

      if (safeTripId.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Trip ID is required',
            code: 'invalid-trip-id',
          ),
        );
      }

      if (!_hasValidCoordinates(latitude, longitude)) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Invalid current coordinates',
            code: 'invalid-coordinates',
          ),
        );
      }

      if (!_isFiniteNumber(totalDistance) || totalDistance < 0.0) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Invalid trip distance',
            code: 'invalid-trip-distance',
          ),
        );
      }

      await _firestore
          .collection(tripsCollection)
          .doc(safeTripId)
          .set(
            _removeNullValues({
              'currentLocation': GeoPoint(latitude, longitude),
              'currentLatitude': latitude,
              'currentLongitude': longitude,
              'currentLocationName': _stringOrNull(currentLocationName),
              'totalDistance': totalDistance,
              'lastLocationUpdateAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }),
            SetOptions(merge: true),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('📍 FirebaseService: Trip location updated - $safeTripId');
      return FirebaseResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseService: Trip location update timeout - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Trip location update timed out',
          code: 'trip-location-update-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ FirebaseService: Failed to update trip location - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to update trip location',
          code: 'trip-location-update-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<FirebaseResult<void>> endTrip(
    String tripId, {
    required double endLatitude,
    required double endLongitude,
    String? endLocationName,
  }) async {
    try {
      final safeTripId = tripId.trim();

      if (safeTripId.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Trip ID is required',
            code: 'invalid-trip-id',
          ),
        );
      }

      if (!_hasValidCoordinates(endLatitude, endLongitude)) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Invalid end coordinates',
            code: 'invalid-coordinates',
          ),
        );
      }

      await _firestore
          .collection(tripsCollection)
          .doc(safeTripId)
          .set(
            _removeNullValues({
              'endLocation': GeoPoint(endLatitude, endLongitude),
              'endLatitude': endLatitude,
              'endLongitude': endLongitude,
              'endLocationName': _stringOrNull(endLocationName),
              'status': 'completed',
              'endTime': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }),
            SetOptions(merge: true),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('✅ FirebaseService: Trip ended - $safeTripId');
      return FirebaseResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseService: Trip end timeout - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Trip end timed out',
          code: 'trip-end-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ FirebaseService: Failed to end trip - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to end trip',
          code: 'trip-end-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ==========================================
  // 📦 STORAGE OPERATIONS
  // ==========================================

  Future<FirebaseResult<String>> uploadImage({
    required File imageFile,
    required String path,
    required String fileName,
    Map<String, String>? metadata,
  }) async {
    try {
      final safePath = path.trim();
      final safeFileName = fileName.trim();

      if (!imageFile.existsSync()) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Image file does not exist',
            code: 'image-file-not-found',
          ),
        );
      }

      if (safePath.isEmpty || safeFileName.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Storage path and file name are required',
            code: 'invalid-storage-path',
          ),
        );
      }

      final ref = _storage.ref().child(safePath).child(safeFileName);

      SettableMetadata? uploadMetadata;

      if (metadata != null) {
        uploadMetadata = SettableMetadata(
          customMetadata: metadata,
          contentType: 'image/jpeg',
        );
      }

      final uploadTask = uploadMetadata != null
          ? ref.putFile(imageFile, uploadMetadata)
          : ref.putFile(imageFile);

      final snapshot = await uploadTask.timeout(const Duration(seconds: 30));
      final downloadUrl = await snapshot.ref.getDownloadURL().timeout(
        const Duration(seconds: 10),
      );

      debugPrint('📤 FirebaseService: Image uploaded - $safeFileName');
      return FirebaseResult.success(downloadUrl);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseService: Image upload timeout - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Image upload timed out',
          code: 'image-upload-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ FirebaseService: Failed to upload image - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to upload image',
          code: 'image-upload-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<FirebaseResult<String>> uploadAccidentImage({
    required File imageFile,
    required String accidentId,
    required String userId,
  }) async {
    final safeAccidentId = accidentId.trim();
    final safeUserId = userId.trim();

    if (safeAccidentId.isEmpty || safeUserId.isEmpty) {
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Accident ID and user ID are required',
          code: 'invalid-upload-identifiers',
        ),
      );
    }

    final fileName =
        '${safeAccidentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = '$accidentImagesPath/$safeUserId';

    return uploadImage(
      imageFile: imageFile,
      path: path,
      fileName: fileName,
      metadata: {
        'accidentId': safeAccidentId,
        'userId': safeUserId,
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<FirebaseResult<String>> uploadKrokaImage({
    required File imageFile,
    required String userId,
  }) async {
    final safeUserId = userId.trim();

    if (safeUserId.isEmpty) {
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'User ID is required',
          code: 'invalid-user-id',
        ),
      );
    }

    final fileName = 'kroka_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = '$krokaImagesPath/$safeUserId';

    return uploadImage(
      imageFile: imageFile,
      path: path,
      fileName: fileName,
      metadata: {
        'userId': safeUserId,
        'type': 'kroka',
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<FirebaseResult<void>> deleteImage(String imageUrl) async {
    try {
      final safeImageUrl = imageUrl.trim();

      if (safeImageUrl.isEmpty) {
        return FirebaseResult.failure(
          FirebaseServiceException(
            message: 'Image URL is required',
            code: 'invalid-image-url',
          ),
        );
      }

      final ref = _storage.refFromURL(safeImageUrl);
      await ref.delete().timeout(const Duration(seconds: 10));

      debugPrint('🗑️ FirebaseService: Image deleted');
      return FirebaseResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ FirebaseService: Image delete timeout - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Image delete timed out',
          code: 'image-delete-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ FirebaseService: Failed to delete image - $e');
      return FirebaseResult.failure(
        FirebaseServiceException(
          message: 'Failed to delete image',
          code: 'image-delete-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ==========================================
  // 🧩 SNAPSHOT BUILDERS
  // ==========================================

  Map<String, dynamic> _buildUserSnapshot({
    required String userId,
    required Map<String, dynamic>? userData,
  }) {
    return _removeNullValues({
      'uid': userId,
      'userId': userId,
      'fullName':
          _stringOrNull(userData?['fullName']) ??
          _stringOrNull(userData?['name']) ??
          _stringOrNull(userData?['userName']) ??
          '',
      'phone':
          _stringOrNull(userData?['phone']) ??
          _stringOrNull(userData?['userPhone']) ??
          '',
      'email':
          _stringOrNull(userData?['email']) ??
          _stringOrNull(userData?['userEmail']) ??
          '',
      'isProfileComplete': _toBoolOrNull(userData?['isProfileComplete']),
      'isMedicalProfileComplete': _toBoolOrNull(
        userData?['isMedicalProfileComplete'],
      ),
      'hasEmergencyContacts': _toBoolOrNull(userData?['hasEmergencyContacts']),
    });
  }

  Map<String, dynamic> _buildMedicalSnapshot(Map<String, dynamic>? userData) {
    if (userData == null) {
      return MedicalProfileModel.empty('').toEmergencySnapshot();
    }

    final profile = MedicalProfileModel.fromMap({
      ...userData,
      'userId':
          _stringOrNull(userData['uid']) ??
          _stringOrNull(userData['userId']) ??
          '',
    });

    final snapshot = profile.toEmergencySnapshot();

    return _removeNullValues({
      ...snapshot,
      'isMedicalProfileComplete': profile.hasRequiredEmergencyData,
      'completionPercentage': profile.calculateCompletion(),
      'medicalProfileUpdatedAt': userData['medicalProfileUpdatedAt'],
    });
  }

  List<Map<String, dynamic>> _buildEmergencyContactsSnapshot(
    Map<String, dynamic>? userData,
  ) {
    if (userData == null) return const [];

    final contacts = <Map<String, dynamic>>[];

    final primaryContact = _asStringKeyMap(userData['primaryEmergencyContact']);

    if (primaryContact != null) {
      final primaryName = _stringOrNull(primaryContact['name']) ?? '';
      final primaryPhone = _stringOrNull(primaryContact['phone']) ?? '';

      if (primaryName.isNotEmpty || primaryPhone.isNotEmpty) {
        contacts.add(
          _removeNullValues({
            'name': primaryName,
            'phone': primaryPhone,
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

        final name = _stringOrNull(contactMap['name']) ?? '';
        final phone = _stringOrNull(contactMap['phone']) ?? '';

        if (name.isEmpty && phone.isEmpty) continue;

        contacts.add(
          _removeNullValues({
            'name': name,
            'phone': phone,
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

    return contacts;
  }

  Map<String, dynamic> _sanitizeAdditionalData(
    Map<String, dynamic>? additionalData,
  ) {
    if (additionalData == null || additionalData.isEmpty) {
      return const {};
    }

    const reservedKeys = {
      'id',
      'accidentId',
      'userId',
      'schemaVersion',
      'gForce',
      'rotation',
      'severityScore',
      'severity',
      'severityLevel',
      'severityDisplay',
      'location',
      'latitude',
      'longitude',
      'locationName',
      'reason',
      'autoDetected',
      'status',
      'timestamp',
      'createdAt',
      'updatedAt',
      'source',
      'emergencySource',
      'alertSource',
      'reportType',
      'isManualSOS',
      'userSnapshot',
      'medicalSnapshot',
      'emergencyContactsSnapshot',
      'emergencyContacts',
      'userName',
      'userPhone',
      'userEmail',
      'bloodType',
      'chronicDiseases',
      'allergies',
      'medications',
      'completionPercentage',
      'medicalProfileCompletion',
      'deviceInfo',
    };

    final sanitized = <String, dynamic>{};

    additionalData.forEach((key, value) {
      final safeKey = key.trim();

      if (safeKey.isEmpty || reservedKeys.contains(safeKey)) return;

      final safeValue = _firestoreSafeValue(value);

      if (safeValue != null) {
        sanitized[safeKey] = safeValue;
      }
    });

    return sanitized;
  }

  // ==========================================
  // 🔧 UTILITY METHODS
  // ==========================================

  Future<bool> checkConnection() async {
    try {
      await _firestore
          .collection(usersCollection)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));

      return true;
    } catch (e) {
      debugPrint('❌ FirebaseService: Connection check failed - $e');
      return false;
    }
  }

  FieldValue get serverTimestamp => FieldValue.serverTimestamp();

  DateTime? timestampToDateTime(dynamic timestamp) {
    if (timestamp == null) return null;

    if (timestamp is Timestamp) {
      return timestamp.toDate();
    }

    if (timestamp is DateTime) {
      return timestamp;
    }

    if (timestamp is String) {
      return DateTime.tryParse(timestamp);
    }

    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }

    if (timestamp is num) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
    }

    return null;
  }

  bool _isFiniteNumber(double value) {
    return !value.isNaN && !value.isInfinite;
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

  int _safeLimit(int limit) {
    if (limit <= 0) return 20;
    if (limit > 1000) return 1000;
    return limit;
  }

  String? _stringOrNull(dynamic value) {
    if (value == null) return null;

    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  int _toInt(dynamic value, {required int fallback}) {
    return _toIntOrNull(value) ?? fallback;
  }

  int? _toIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();

    if (value is String) {
      return int.tryParse(value.trim());
    }

    return null;
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

  bool? _toBoolOrNull(dynamic value) {
    if (value == null) return null;
    return _toBool(value, fallback: false);
  }

  Map<String, dynamic>? _asStringKeyMap(dynamic value) {
    if (value is! Map) return null;

    return value.map(
      (key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
    );
  }

  Map<String, dynamic> _removeNullValues(Map<String, dynamic> map) {
    final result = Map<String, dynamic>.from(map);
    result.removeWhere((_, value) => value == null);
    return result;
  }

  Map<String, dynamic> _sanitizeFirestoreMap(Map<String, dynamic> input) {
    final output = <String, dynamic>{};

    input.forEach((key, value) {
      final safeKey = key.trim();

      if (safeKey.isEmpty) return;

      final safeValue = _firestoreSafeValue(value);

      if (safeValue != null || value == null) {
        output[safeKey] = safeValue;
      }
    });

    return output;
  }

  dynamic _firestoreSafeValue(dynamic value) {
    if (value == null) return null;

    if (value is String ||
        value is bool ||
        value is Timestamp ||
        value is FieldValue) {
      return value;
    }

    if (value is num) {
      if (value.isNaN || value.isInfinite) return null;
      return value;
    }

    if (value is DateTime) {
      return Timestamp.fromDate(value);
    }

    if (value is GeoPoint) {
      return value;
    }

    if (value is List) {
      return value
          .map(_firestoreSafeValue)
          .where((element) => element != null)
          .toList();
    }

    if (value is Map) {
      return _sanitizeFirestoreMap(
        value.map(
          (key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
        ),
      );
    }

    return value.toString();
  }

  String _resolveEmergencySource({
    String? explicitEmergencySource,
    String? source,
    String? reason,
    required bool autoDetected,
  }) {
    final explicit = explicitEmergencySource?.trim().toLowerCase();

    if (explicit == 'manual_sos' || explicit == 'auto_detection') {
      return explicit!;
    }

    if (_containsManualSignal(source) || _containsManualSignal(reason)) {
      return 'manual_sos';
    }

    if (_containsAutoSignal(source) || _containsAutoSignal(reason)) {
      return 'auto_detection';
    }

    return autoDetected ? 'auto_detection' : 'manual_sos';
  }

  bool _containsManualSignal(String? value) {
    final normalized = value?.trim().toLowerCase();

    if (normalized == null || normalized.isEmpty) return false;

    return normalized.contains('manual') ||
        normalized.contains('sos') ||
        normalized.contains('استغاثة');
  }

  bool _containsAutoSignal(String? value) {
    final normalized = value?.trim().toLowerCase();

    if (normalized == null || normalized.isEmpty) return false;

    return normalized.contains('auto') ||
        normalized.contains('detection') ||
        normalized.contains('sensor') ||
        normalized.contains('automatic');
  }

  String _normalizeAccidentSeverity({
    required String severityLevel,
    required String emergencySource,
  }) {
    final raw = severityLevel.trim().toLowerCase();

    if (emergencySource == 'manual_sos') {
      return AppThresholds.severityCritical;
    }

    if (raw == 'manual_sos') {
      return AppThresholds.severityCritical;
    }

    return AppThresholds.normalizeSeverityLevel(raw);
  }

  double _resolveSeverityScore({
    required double severityScore,
    required String severityLevel,
    required String emergencySource,
  }) {
    if (emergencySource == 'manual_sos') {
      return 100.0;
    }

    if (severityScore.isNaN || severityScore.isInfinite) return 0.0;

    final clamped = severityScore.clamp(0.0, 100.0).toDouble();

    if (clamped > 0.0) return clamped;

    switch (AppThresholds.normalizeSeverityLevel(severityLevel)) {
      case AppThresholds.severityCritical:
        return 100.0;
      case AppThresholds.severityHigh:
        return 60.0;
      case AppThresholds.severityMedium:
        return 40.0;
      case AppThresholds.severityLow:
        return 20.0;
      case AppThresholds.severityIgnored:
      default:
        return 0.0;
    }
  }

  String _resolveSeverityDisplay({
    String? explicitDisplay,
    required String severityLevel,
    required String emergencySource,
  }) {
    final safeDisplay = _stringOrNull(explicitDisplay);

    if (safeDisplay != null) {
      return safeDisplay;
    }

    if (emergencySource == 'manual_sos') {
      return 'استغاثة يدوية حرجة';
    }

    return AppThresholds.severityDisplayArabic(severityLevel);
  }

  String _defaultAccidentReason(String emergencySource) {
    if (emergencySource == 'manual_sos') {
      return 'Manual SOS triggered by user';
    }

    return 'Auto accident detection triggered';
  }
}

class FirebaseResult<T> {
  final T? data;
  final FirebaseServiceException? error;
  final bool isSuccess;

  FirebaseResult._({this.data, this.error, required this.isSuccess});

  factory FirebaseResult.success(T? data) {
    return FirebaseResult._(data: data, isSuccess: true);
  }

  factory FirebaseResult.failure(FirebaseServiceException error) {
    return FirebaseResult._(error: error, isSuccess: false);
  }

  bool get isFailure => !isSuccess;
}

class FirebaseServiceException {
  final String message;
  final String code;
  final Object? originalError;
  final StackTrace? stackTrace;

  FirebaseServiceException({
    required this.message,
    required this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'FirebaseServiceException(code: $code, message: $message)';
  }
}
