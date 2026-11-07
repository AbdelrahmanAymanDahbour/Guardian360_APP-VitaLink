import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_thresholds.dart';
import '../../../core/models/emergency_contact_model.dart';
import '../models/safe_arrival_report_model.dart';
import '../models/safe_arrival_trip_model.dart';

/// ==========================================
/// 🛡️ Safe Arrival Repository
/// ==========================================
/// Data access layer for the Safe Arrival feature.
///
/// Responsibilities:
/// - Create and update Safe Arrival trip documents.
/// - Read active/current Safe Arrival trips.
/// - Load emergency contacts from users/{uid}.
/// - Keep Firestore logic outside UI/ViewModel.
///
/// Not responsible for:
/// - GPS stream handling.
/// - Google Places search.
/// - WhatsApp launching.
/// - UI state.
/// - Accident detection.
class SafeArrivalRepository {
  SafeArrivalRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _usersCollection = 'users';
  static const Duration _operationTimeout = Duration(
    seconds: AppThresholds.firebaseTimeoutSeconds,
  );

  static final List<String> _openTripStatuses = <String>[
    SafeArrivalTripStatus.ready.value,
    SafeArrivalTripStatus.tracking.value,
    SafeArrivalTripStatus.paused.value,
    SafeArrivalTripStatus.danger.value,
  ];

  CollectionReference<Map<String, dynamic>> get _tripsRef {
    return _firestore.collection(AppThresholds.safeArrivalTripsCollection);
  }

  CollectionReference<Map<String, dynamic>> get _usersRef {
    return _firestore.collection(_usersCollection);
  }

  // ==========================================
  // 📞 Emergency Contacts
  // ==========================================

  Future<SafeArrivalRepositoryResult<List<EmergencyContactModel>>>
  loadEmergencyContacts(String userId) async {
    try {
      final safeUserId = _cleanText(userId);

      if (safeUserId.isEmpty) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'User ID is required',
            code: 'invalid-user-id',
          ),
        );
      }

      final doc = await _usersRef
          .doc(safeUserId)
          .get()
          .timeout(_operationTimeout);

      if (!doc.exists) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'User document not found',
            code: 'user-not-found',
          ),
        );
      }

      final data = doc.data();

      if (data == null) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'User data is empty',
            code: 'user-data-empty',
          ),
        );
      }

      final contacts = _parseEmergencyContacts(data);

      return SafeArrivalRepositoryResult.success(contacts);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ SafeArrivalRepository: contacts load timeout');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Emergency contacts load timed out',
          code: 'contacts-load-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalRepository: failed to load contacts - $e');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Failed to load emergency contacts',
          code: 'contacts-load-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<SafeArrivalRepositoryResult<EmergencyContactModel?>>
  loadPrimaryEmergencyContact(String userId) async {
    final result = await loadEmergencyContacts(userId);

    if (result.isFailure) {
      return SafeArrivalRepositoryResult.failure(result.error!);
    }

    final contacts = result.data ?? const <EmergencyContactModel>[];

    if (contacts.isEmpty) {
      return SafeArrivalRepositoryResult.success(null);
    }

    return SafeArrivalRepositoryResult.success(contacts.first);
  }

  // ==========================================
  // 🧾 Trip Reads
  // ==========================================

  Future<SafeArrivalRepositoryResult<SafeArrivalTripModel?>> getTripById(
    String tripId,
  ) async {
    try {
      final safeTripId = _cleanText(tripId);

      if (safeTripId.isEmpty) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Trip ID is required',
            code: 'invalid-trip-id',
          ),
        );
      }

      final doc = await _tripsRef
          .doc(safeTripId)
          .get()
          .timeout(_operationTimeout);

      if (!doc.exists) {
        return SafeArrivalRepositoryResult.success(null);
      }

      return SafeArrivalRepositoryResult.success(
        SafeArrivalTripModel.fromFirestore(doc),
      );
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ SafeArrivalRepository: getTripById timeout');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Safe Arrival trip fetch timed out',
          code: 'trip-fetch-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalRepository: failed to get trip - $e');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Failed to fetch Safe Arrival trip',
          code: 'trip-fetch-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<SafeArrivalRepositoryResult<SafeArrivalTripModel?>> getActiveTrip(
    String userId,
  ) async {
    try {
      final safeUserId = _cleanText(userId);

      if (safeUserId.isEmpty) {
        return SafeArrivalRepositoryResult.failure(
          const SafeArrivalRepositoryException(
            message: 'User ID is required',
            code: 'invalid-user-id',
          ),
        );
      }

      final query = await _tripsRef
          .where('userId', isEqualTo: safeUserId)
          .where('status', whereIn: _openTripStatuses)
          .limit(10)
          .get()
          .timeout(_operationTimeout);

      if (query.docs.isEmpty) {
        return SafeArrivalRepositoryResult.success(null);
      }

      return SafeArrivalRepositoryResult.success(
        _selectBestOpenTrip(query.docs),
      );
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ SafeArrivalRepository: active trip lookup timeout');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Active Safe Arrival trip lookup timed out',
          code: 'active-trip-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalRepository: failed to load active trip - $e');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Failed to load active Safe Arrival trip',
          code: 'active-trip-load-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Stream<SafeArrivalTripModel?> watchTrip(String tripId) {
    final safeTripId = _cleanText(tripId);

    if (safeTripId.isEmpty) {
      return Stream.value(null);
    }

    return _tripsRef
        .doc(safeTripId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return SafeArrivalTripModel.fromFirestore(doc);
        })
        .handleError((Object error, StackTrace stackTrace) {
          debugPrint('❌ SafeArrivalRepository.watchTrip error - $error');
          debugPrintStack(stackTrace: stackTrace);
        });
  }

  Stream<SafeArrivalTripModel?> watchActiveTrip(String userId) {
    final safeUserId = _cleanText(userId);

    if (safeUserId.isEmpty) {
      return Stream.value(null);
    }

    return _tripsRef
        .where('userId', isEqualTo: safeUserId)
        .where('status', whereIn: _openTripStatuses)
        .limit(10)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return _selectBestOpenTrip(snapshot.docs);
        })
        .handleError((Object error, StackTrace stackTrace) {
          debugPrint('❌ SafeArrivalRepository.watchActiveTrip error - $error');
          debugPrintStack(stackTrace: stackTrace);
        });
  }

  // ==========================================
  // 🛡️ Trip Lifecycle
  // ==========================================

  Future<SafeArrivalRepositoryResult<SafeArrivalTripModel>> createTrip(
    SafeArrivalTripModel trip, {
    bool preventMultipleActiveTrips = true,
  }) async {
    try {
      final validationError = _validateCreatableTrip(trip);

      if (validationError != null) {
        return SafeArrivalRepositoryResult.failure(validationError);
      }

      if (preventMultipleActiveTrips) {
        final activeResult = await getActiveTrip(trip.userId);

        if (activeResult.isFailure) {
          return SafeArrivalRepositoryResult.failure(activeResult.error!);
        }

        if (activeResult.data != null) {
          return SafeArrivalRepositoryResult.failure(
            SafeArrivalRepositoryException(
              message: 'User already has an active Safe Arrival trip',
              code: 'active-trip-already-exists',
            ),
          );
        }
      }

      final payload = trip.toFirestore();
      payload['createdAt'] = FieldValue.serverTimestamp();
      payload['updatedAt'] = FieldValue.serverTimestamp();

      await _tripsRef.doc(trip.id).set(payload).timeout(_operationTimeout);

      debugPrint('✅ SafeArrivalRepository: trip created - ${trip.id}');
      return SafeArrivalRepositoryResult.success(trip);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ SafeArrivalRepository: create trip timeout');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Safe Arrival trip creation timed out',
          code: 'trip-create-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalRepository: failed to create trip - $e');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Failed to create Safe Arrival trip',
          code: 'trip-create-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<SafeArrivalRepositoryResult<SafeArrivalTripModel>> startTrip({
    required SafeArrivalTripModel trip,
    required double startLatitude,
    required double startLongitude,
    String? startLocationName,
    String? selectedContactName,
    String? selectedContactPhone,
    String? whatsappMessage,
    DateTime? estimatedArrivalAt,
    double? estimatedDistanceMeters,
    int? estimatedDurationSeconds,
  }) async {
    try {
      if (!trip.hasValidUser) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'User ID is required',
            code: 'invalid-user-id',
          ),
        );
      }

      if (!trip.hasTrustedDestination) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Trusted destination is required',
            code: 'invalid-destination',
          ),
        );
      }

      if (!_hasValidCoordinates(startLatitude, startLongitude)) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Start coordinates are invalid',
            code: 'invalid-start-coordinates',
          ),
        );
      }

      final activeResult = await getActiveTrip(trip.userId);

      if (activeResult.isFailure) {
        return SafeArrivalRepositoryResult.failure(activeResult.error!);
      }

      final existingActiveTrip = activeResult.data;

      if (existingActiveTrip != null && existingActiveTrip.id != trip.id) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'User already has an active Safe Arrival trip',
            code: 'active-trip-already-exists',
          ),
        );
      }

      final now = DateTime.now();

      final startedTrip = trip.copyWith(
        status: SafeArrivalTripStatus.tracking,
        startLatitude: startLatitude,
        startLongitude: startLongitude,
        startLocationName: _stringOrNull(startLocationName),
        currentLatitude: startLatitude,
        currentLongitude: startLongitude,
        currentLocationName: _stringOrNull(startLocationName),
        estimatedArrivalAt: estimatedArrivalAt,
        estimatedDistanceMeters: estimatedDistanceMeters,
        estimatedDurationSeconds: estimatedDurationSeconds,
        actualDistanceMeters: 0.0,
        distanceToDestinationMeters: estimatedDistanceMeters,
        selectedContactName: _stringOrNull(selectedContactName),
        selectedContactPhone: _stringOrNull(selectedContactPhone),
        whatsappMessage: _stringOrNull(whatsappMessage),
        startedAt: now,
        updatedAt: now,
      );

      final payload = startedTrip.toFirestore();
      payload['startedAt'] = FieldValue.serverTimestamp();
      payload['updatedAt'] = FieldValue.serverTimestamp();

      await _tripsRef
          .doc(startedTrip.id)
          .set(payload, SetOptions(merge: true))
          .timeout(_operationTimeout);

      debugPrint('🚗 SafeArrivalRepository: trip started - ${startedTrip.id}');
      return SafeArrivalRepositoryResult.success(startedTrip);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ SafeArrivalRepository: start trip timeout');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Safe Arrival trip start timed out',
          code: 'trip-start-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalRepository: failed to start trip - $e');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Failed to start Safe Arrival trip',
          code: 'trip-start-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<SafeArrivalRepositoryResult<void>> updateTripLocation({
    required String tripId,
    required double latitude,
    required double longitude,
    String? currentLocationName,
    required double actualDistanceMeters,
    double? distanceToDestinationMeters,
  }) async {
    try {
      final safeTripId = _cleanText(tripId);

      if (safeTripId.isEmpty) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Trip ID is required',
            code: 'invalid-trip-id',
          ),
        );
      }

      if (!_hasValidCoordinates(latitude, longitude)) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Current coordinates are invalid',
            code: 'invalid-current-coordinates',
          ),
        );
      }

      if (!_isValidDistance(actualDistanceMeters)) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Actual distance is invalid',
            code: 'invalid-actual-distance',
          ),
        );
      }

      if (distanceToDestinationMeters != null &&
          !_isValidDistance(distanceToDestinationMeters)) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Distance to destination is invalid',
            code: 'invalid-distance-to-destination',
          ),
        );
      }

      await _tripsRef
          .doc(safeTripId)
          .set(
            _removeNullValues({
              'currentLatitude': latitude,
              'currentLongitude': longitude,
              'currentLocation': GeoPoint(latitude, longitude),
              'currentLocationName': _stringOrNull(currentLocationName),
              'actualDistanceMeters': actualDistanceMeters,
              'distanceToDestinationMeters': distanceToDestinationMeters,
              'lastLocationUpdatedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }),
            SetOptions(merge: true),
          )
          .timeout(_operationTimeout);

      return SafeArrivalRepositoryResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ SafeArrivalRepository: update location timeout');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Safe Arrival location update timed out',
          code: 'location-update-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalRepository: failed to update location - $e');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Failed to update Safe Arrival location',
          code: 'location-update-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<SafeArrivalRepositoryResult<void>> markArrived({
    required String tripId,
    required double endLatitude,
    required double endLongitude,
    String? endLocationName,
    double? actualDistanceMeters,
    SafeArrivalReportModel? report,
  }) async {
    try {
      final safeTripId = _cleanText(tripId);

      if (safeTripId.isEmpty) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Trip ID is required',
            code: 'invalid-trip-id',
          ),
        );
      }

      if (!_hasValidCoordinates(endLatitude, endLongitude)) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'End coordinates are invalid',
            code: 'invalid-end-coordinates',
          ),
        );
      }

      if (actualDistanceMeters != null &&
          !_isValidDistance(actualDistanceMeters)) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Actual distance is invalid',
            code: 'invalid-actual-distance',
          ),
        );
      }

      await _tripsRef
          .doc(safeTripId)
          .set(
            _removeNullValues({
              'status': SafeArrivalTripStatus.arrived.value,
              'endLatitude': endLatitude,
              'endLongitude': endLongitude,
              'endLocation': GeoPoint(endLatitude, endLongitude),
              'endLocationName': _stringOrNull(endLocationName),
              'currentLatitude': endLatitude,
              'currentLongitude': endLongitude,
              'currentLocation': GeoPoint(endLatitude, endLongitude),
              'currentLocationName': _stringOrNull(endLocationName),
              'actualDistanceMeters': actualDistanceMeters,
              'distanceToDestinationMeters': 0.0,
              'report': report?.toMap(),
              'safetyLevel': report?.safetyLevel,
              'safetyScore': report?.safetyScore,
              'safetyRating': report?.ratingLabel,
              'guardianReport': report?.guardianReport,
              'arrivedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }),
            SetOptions(merge: true),
          )
          .timeout(_operationTimeout);

      debugPrint('✅ SafeArrivalRepository: trip arrived - $safeTripId');
      return SafeArrivalRepositoryResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ SafeArrivalRepository: mark arrived timeout');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Safe Arrival completion timed out',
          code: 'mark-arrived-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalRepository: failed to mark arrived - $e');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Failed to mark Safe Arrival trip as arrived',
          code: 'mark-arrived-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<SafeArrivalRepositoryResult<void>> markDanger({
    required String tripId,
    required String reason,
    double? latitude,
    double? longitude,
    String? currentLocationName,
    double? actualDistanceMeters,
    double? distanceToDestinationMeters,
    SafeArrivalReportModel? report,
  }) async {
    try {
      final safeTripId = _cleanText(tripId);
      final safeReason = _cleanText(reason);

      if (safeTripId.isEmpty) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Trip ID is required',
            code: 'invalid-trip-id',
          ),
        );
      }

      if (safeReason.isEmpty) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Danger reason is required',
            code: 'invalid-danger-reason',
          ),
        );
      }

      if ((latitude != null || longitude != null) &&
          !_hasValidCoordinates(latitude, longitude)) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Danger coordinates are invalid',
            code: 'invalid-danger-coordinates',
          ),
        );
      }

      if (actualDistanceMeters != null &&
          !_isValidDistance(actualDistanceMeters)) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Actual distance is invalid',
            code: 'invalid-actual-distance',
          ),
        );
      }

      if (distanceToDestinationMeters != null &&
          !_isValidDistance(distanceToDestinationMeters)) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Distance to destination is invalid',
            code: 'invalid-distance-to-destination',
          ),
        );
      }

      await _tripsRef
          .doc(safeTripId)
          .set(
            _removeNullValues({
              'status': SafeArrivalTripStatus.danger.value,
              'dangerReason': safeReason,
              'currentLatitude': latitude,
              'currentLongitude': longitude,
              'currentLocation': _geoPointOrNull(latitude, longitude),
              'currentLocationName': _stringOrNull(currentLocationName),
              'actualDistanceMeters': actualDistanceMeters,
              'distanceToDestinationMeters': distanceToDestinationMeters,
              'report': report?.toMap(),
              'safetyLevel': report?.safetyLevel,
              'safetyScore': report?.safetyScore,
              'safetyRating': report?.ratingLabel,
              'guardianReport': report?.guardianReport,
              'dangerTriggeredAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }),
            SetOptions(merge: true),
          )
          .timeout(_operationTimeout);

      debugPrint('🚨 SafeArrivalRepository: trip danger - $safeTripId');
      return SafeArrivalRepositoryResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ SafeArrivalRepository: mark danger timeout');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Safe Arrival danger update timed out',
          code: 'mark-danger-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalRepository: failed to mark danger - $e');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Failed to mark Safe Arrival trip as danger',
          code: 'mark-danger-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<SafeArrivalRepositoryResult<void>> cancelTrip({
    required String tripId,
    String? reason,
  }) async {
    try {
      final safeTripId = _cleanText(tripId);

      if (safeTripId.isEmpty) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Trip ID is required',
            code: 'invalid-trip-id',
          ),
        );
      }

      await _tripsRef
          .doc(safeTripId)
          .set(
            _removeNullValues({
              'status': SafeArrivalTripStatus.cancelled.value,
              'cancelReason': _stringOrNull(reason),
              'cancelledAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }),
            SetOptions(merge: true),
          )
          .timeout(_operationTimeout);

      debugPrint('🛑 SafeArrivalRepository: trip cancelled - $safeTripId');
      return SafeArrivalRepositoryResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ SafeArrivalRepository: cancel trip timeout');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Safe Arrival cancellation timed out',
          code: 'trip-cancel-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalRepository: failed to cancel trip - $e');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Failed to cancel Safe Arrival trip',
          code: 'trip-cancel-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<SafeArrivalRepositoryResult<void>> pauseTrip({
    required String tripId,
    String reason = 'user_paused',
  }) async {
    try {
      final safeTripId = _cleanText(tripId);
      final safeReason = _cleanText(reason);

      if (safeTripId.isEmpty) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Trip ID is required',
            code: 'invalid-trip-id',
          ),
        );
      }

      await _tripsRef
          .doc(safeTripId)
          .set(
            _removeNullValues({
              'status': SafeArrivalTripStatus.paused.value,
              'pauseReason': safeReason.isEmpty ? 'user_paused' : safeReason,
              'pausedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }),
            SetOptions(merge: true),
          )
          .timeout(_operationTimeout);

      debugPrint('⏸️ SafeArrivalRepository: trip paused - $safeTripId');
      return SafeArrivalRepositoryResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ SafeArrivalRepository: pause trip timeout');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Safe Arrival pause timed out',
          code: 'trip-pause-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalRepository: failed to pause trip - $e');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Failed to pause Safe Arrival trip',
          code: 'trip-pause-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<SafeArrivalRepositoryResult<void>> resumeTrip({
    required String tripId,
  }) async {
    try {
      final safeTripId = _cleanText(tripId);

      if (safeTripId.isEmpty) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Trip ID is required',
            code: 'invalid-trip-id',
          ),
        );
      }

      await _tripsRef
          .doc(safeTripId)
          .set({
            'status': SafeArrivalTripStatus.tracking.value,
            'resumedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .timeout(_operationTimeout);

      debugPrint('▶️ SafeArrivalRepository: trip resumed - $safeTripId');
      return SafeArrivalRepositoryResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ SafeArrivalRepository: resume trip timeout');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Safe Arrival resume timed out',
          code: 'trip-resume-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalRepository: failed to resume trip - $e');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Failed to resume Safe Arrival trip',
          code: 'trip-resume-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<SafeArrivalRepositoryResult<void>> finishTripManually({
    required String tripId,
    required double endLatitude,
    required double endLongitude,
    String? endLocationName,
    double? actualDistanceMeters,
    double? distanceToDestinationMeters,
    SafeArrivalReportModel? report,
    String reason = 'manual_finish_near_destination',
  }) async {
    try {
      final safeTripId = _cleanText(tripId);
      final safeReason = _cleanText(reason);

      if (safeTripId.isEmpty) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Trip ID is required',
            code: 'invalid-trip-id',
          ),
        );
      }

      if (!_hasValidCoordinates(endLatitude, endLongitude)) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'End coordinates are invalid',
            code: 'invalid-end-coordinates',
          ),
        );
      }

      if (actualDistanceMeters != null &&
          !_isValidDistance(actualDistanceMeters)) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Actual distance is invalid',
            code: 'invalid-actual-distance',
          ),
        );
      }

      if (distanceToDestinationMeters != null &&
          !_isValidDistance(distanceToDestinationMeters)) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Distance to destination is invalid',
            code: 'invalid-distance-to-destination',
          ),
        );
      }

      await _tripsRef
          .doc(safeTripId)
          .set(
            _removeNullValues({
              'status': SafeArrivalTripStatus.arrived.value,
              'finishReason': safeReason.isEmpty
                  ? 'manual_finish_near_destination'
                  : safeReason,
              'endLatitude': endLatitude,
              'endLongitude': endLongitude,
              'endLocation': GeoPoint(endLatitude, endLongitude),
              'endLocationName': _stringOrNull(endLocationName),
              'currentLatitude': endLatitude,
              'currentLongitude': endLongitude,
              'currentLocation': GeoPoint(endLatitude, endLongitude),
              'currentLocationName': _stringOrNull(endLocationName),
              'actualDistanceMeters': actualDistanceMeters,
              'distanceToDestinationMeters': distanceToDestinationMeters ?? 0.0,
              'report': report?.toMap(),
              'safetyLevel': report?.safetyLevel,
              'safetyScore': report?.safetyScore,
              'safetyRating': report?.ratingLabel,
              'guardianReport': report?.guardianReport,
              'manualFinishedAt': FieldValue.serverTimestamp(),
              'arrivedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }),
            SetOptions(merge: true),
          )
          .timeout(_operationTimeout);

      debugPrint(
        '✅ SafeArrivalRepository: trip manually finished - $safeTripId',
      );
      return SafeArrivalRepositoryResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ SafeArrivalRepository: manual finish timeout');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Safe Arrival manual finish timed out',
          code: 'manual-finish-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint(
        '❌ SafeArrivalRepository: failed to manually finish trip - $e',
      );
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Failed to manually finish Safe Arrival trip',
          code: 'manual-finish-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<SafeArrivalRepositoryResult<int>> cancelOpenTripsForUser({
    required String userId,
    String reason = 'user_cancelled_open_trip',
  }) async {
    try {
      final safeUserId = _cleanText(userId);
      final safeReason = _cleanText(reason);

      if (safeUserId.isEmpty) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'User ID is required',
            code: 'invalid-user-id',
          ),
        );
      }

      final query = await _tripsRef
          .where('userId', isEqualTo: safeUserId)
          .where('status', whereIn: _openTripStatuses)
          .limit(10)
          .get()
          .timeout(_operationTimeout);

      if (query.docs.isEmpty) {
        return SafeArrivalRepositoryResult.success(0);
      }

      final batch = _firestore.batch();

      for (final doc in query.docs) {
        batch.set(
          doc.reference,
          _removeNullValues({
            'status': SafeArrivalTripStatus.cancelled.value,
            'cancelReason': safeReason.isEmpty
                ? 'user_cancelled_open_trip'
                : safeReason,
            'cancelledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }),
          SetOptions(merge: true),
        );
      }

      await batch.commit().timeout(_operationTimeout);

      debugPrint(
        '🧹 SafeArrivalRepository: cancelled ${query.docs.length} open trip(s) for $safeUserId',
      );

      return SafeArrivalRepositoryResult.success(query.docs.length);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ SafeArrivalRepository: cancel open trips timeout');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Open Safe Arrival trips cancellation timed out',
          code: 'open-trips-cancel-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ SafeArrivalRepository: failed to cancel open trips - $e');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Failed to cancel open Safe Arrival trips',
          code: 'open-trips-cancel-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<SafeArrivalRepositoryResult<void>> markFamilyNotified({
    required String tripId,
    required String whatsappMessage,
    String? selectedContactName,
    String? selectedContactPhone,
  }) async {
    try {
      final safeTripId = _cleanText(tripId);
      final safeMessage = _cleanMultilineText(whatsappMessage);

      if (safeTripId.isEmpty) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'Trip ID is required',
            code: 'invalid-trip-id',
          ),
        );
      }

      if (safeMessage.isEmpty) {
        return SafeArrivalRepositoryResult.failure(
          SafeArrivalRepositoryException(
            message: 'WhatsApp message is required',
            code: 'invalid-whatsapp-message',
          ),
        );
      }

      await _tripsRef
          .doc(safeTripId)
          .set(
            _removeNullValues({
              'whatsappMessage': safeMessage,
              'selectedContactName': _stringOrNull(selectedContactName),
              'selectedContactPhone': _stringOrNull(selectedContactPhone),
              'familyNotifiedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }),
            SetOptions(merge: true),
          )
          .timeout(_operationTimeout);

      debugPrint('📱 SafeArrivalRepository: family notified - $safeTripId');
      return SafeArrivalRepositoryResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ SafeArrivalRepository: mark family notified timeout');
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Family notification update timed out',
          code: 'family-notified-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint(
        '❌ SafeArrivalRepository: failed to mark family notified - $e',
      );
      return SafeArrivalRepositoryResult.failure(
        SafeArrivalRepositoryException(
          message: 'Failed to mark family as notified',
          code: 'family-notified-failed',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ==========================================
  // Helpers
  // ==========================================

  SafeArrivalRepositoryException? _validateCreatableTrip(
    SafeArrivalTripModel trip,
  ) {
    if (!trip.hasValidId) {
      return const SafeArrivalRepositoryException(
        message: 'Trip ID is required',
        code: 'invalid-trip-id',
      );
    }

    if (!trip.hasValidUser) {
      return const SafeArrivalRepositoryException(
        message: 'User ID is required',
        code: 'invalid-user-id',
      );
    }

    if (!trip.hasTrustedDestination) {
      return const SafeArrivalRepositoryException(
        message: 'Trusted destination is required',
        code: 'invalid-destination',
      );
    }

    if (trip.status != SafeArrivalTripStatus.draft &&
        trip.status != SafeArrivalTripStatus.ready) {
      return const SafeArrivalRepositoryException(
        message: 'Trip initial status is invalid',
        code: 'invalid-initial-status',
      );
    }

    if (trip.arrivalRadiusMeters <= 0.0 ||
        trip.arrivalRadiusMeters.isNaN ||
        trip.arrivalRadiusMeters.isInfinite) {
      return const SafeArrivalRepositoryException(
        message: 'Arrival radius is invalid',
        code: 'invalid-arrival-radius',
      );
    }

    return null;
  }

  SafeArrivalTripModel? _selectBestOpenTrip(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final trips = docs
        .map(SafeArrivalTripModel.fromFirestore)
        .where((trip) => trip.isOperational)
        .toList(growable: false);

    if (trips.isEmpty) return null;

    final sorted = List<SafeArrivalTripModel>.from(trips);

    sorted.sort((a, b) {
      final bTime = _latestLifecycleTime(b);
      final aTime = _latestLifecycleTime(a);

      final timeComparison = bTime.compareTo(aTime);
      if (timeComparison != 0) return timeComparison;

      return _openStatusPriority(
        a.status,
      ).compareTo(_openStatusPriority(b.status));
    });

    return sorted.first;
  }

  DateTime _latestLifecycleTime(SafeArrivalTripModel trip) {
    return trip.updatedAt ??
        trip.dangerTriggeredAt ??
        trip.resumedAt ??
        trip.pausedAt ??
        trip.startedAt ??
        trip.createdAt;
  }

  int _openStatusPriority(SafeArrivalTripStatus status) {
    switch (status) {
      case SafeArrivalTripStatus.danger:
        return 0;
      case SafeArrivalTripStatus.tracking:
        return 1;
      case SafeArrivalTripStatus.paused:
        return 2;
      case SafeArrivalTripStatus.ready:
        return 3;
      case SafeArrivalTripStatus.draft:
      case SafeArrivalTripStatus.arrived:
      case SafeArrivalTripStatus.cancelled:
      case SafeArrivalTripStatus.failed:
        return 9;
    }
  }

  static String _cleanMultilineText(String value) {
    final normalized = value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (normalized.isEmpty) return '';

    final lines = normalized
        .split('\n')
        .map(_cleanText)
        .toList(growable: false);

    final compactLines = <String>[];
    var previousWasEmpty = false;

    for (final line in lines) {
      final isEmpty = line.isEmpty;

      if (isEmpty && previousWasEmpty) continue;

      compactLines.add(line);
      previousWasEmpty = isEmpty;
    }

    while (compactLines.isNotEmpty && compactLines.first.isEmpty) {
      compactLines.removeAt(0);
    }

    while (compactLines.isNotEmpty && compactLines.last.isEmpty) {
      compactLines.removeLast();
    }

    return compactLines.join('\n').trim();
  }

  List<EmergencyContactModel> _parseEmergencyContacts(
    Map<String, dynamic> userData,
  ) {
    final contacts = <EmergencyContactModel>[];

    final primary = _asStringKeyMap(userData['primaryEmergencyContact']);

    if (primary != null) {
      final contact = EmergencyContactModel.fromMap({
        ...primary,
        'priority': 1,
      });

      if (contact.hasValidPhone) {
        contacts.add(contact.copyWith(priority: 1));
      }
    }

    final extra = userData['extraEmergencyContacts'];

    if (extra is List) {
      for (final item in extra) {
        final map = _asStringKeyMap(item);
        if (map == null) continue;

        final contact = EmergencyContactModel.fromMap(map);

        if (contact.hasValidPhone) {
          contacts.add(contact);
        }
      }
    }

    final unique = <EmergencyContactModel>[];
    final seenPhones = <String>{};

    for (final contact in contacts) {
      final phone = contact.phone.trim();

      if (phone.isEmpty || seenPhones.contains(phone)) continue;

      seenPhones.add(phone);
      unique.add(contact);
    }

    unique.sort((a, b) => a.priority.compareTo(b.priority));

    return unique.take(AppThresholds.maxEmergencyContacts).toList();
  }

  static Map<String, dynamic>? _asStringKeyMap(dynamic value) {
    if (value is! Map) return null;

    return value.map(
      (key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
    );
  }

  static String _cleanText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? _stringOrNull(dynamic value) {
    if (value == null) return null;

    final text = value.toString().trim();
    return text.isEmpty ? null : text;
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

  static bool _isValidDistance(double value) {
    return !value.isNaN && !value.isInfinite && value >= 0.0;
  }

  static GeoPoint? _geoPointOrNull(double? latitude, double? longitude) {
    if (!_hasValidCoordinates(latitude, longitude)) return null;
    return GeoPoint(latitude!, longitude!);
  }

  static Map<String, dynamic> _removeNullValues(Map<String, dynamic> map) {
    final result = Map<String, dynamic>.from(map);
    result.removeWhere((_, value) => value == null);
    return result;
  }
}

/// ==========================================
/// 📦 Repository Result
/// ==========================================
class SafeArrivalRepositoryResult<T> {
  final T? data;
  final SafeArrivalRepositoryException? error;
  final bool isSuccess;

  const SafeArrivalRepositoryResult._({
    this.data,
    this.error,
    required this.isSuccess,
  });

  factory SafeArrivalRepositoryResult.success(T? data) {
    return SafeArrivalRepositoryResult._(data: data, isSuccess: true);
  }

  factory SafeArrivalRepositoryResult.failure(
    SafeArrivalRepositoryException error,
  ) {
    return SafeArrivalRepositoryResult._(error: error, isSuccess: false);
  }

  bool get isFailure => !isSuccess;
}

/// ==========================================
/// ⚠️ Repository Exception
/// ==========================================
class SafeArrivalRepositoryException {
  final String message;
  final String code;
  final Object? originalError;
  final StackTrace? stackTrace;

  const SafeArrivalRepositoryException({
    required this.message,
    required this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'SafeArrivalRepositoryException(code: $code, message: $message)';
  }
}
