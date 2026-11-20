import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../constants/app_thresholds.dart';
import '../models/trip_model.dart';

class TripService {
  TripService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _tripsCollection = 'trips';

  Future<TripModel?> createTrip({
    required String userId,
    String? destination,
    int? estimatedDurationMinutes,
    double? startLatitude,
    double? startLongitude,
    String sensitivityLevel = 'medium',
  }) async {
    try {
      final safeUserId = userId.trim();
      if (safeUserId.isEmpty) {
        debugPrint('❌ TripService: Cannot create trip with empty userId');
        return null;
      }

      if (!isValidTripDuration(estimatedDurationMinutes)) {
        debugPrint('⚠️ TripService: Invalid trip duration');
        return null;
      }

      final activeTrip = await getActiveTrip(safeUserId);
      if (activeTrip != null) {
        debugPrint(
          '⚠️ TripService: User already has an active trip: ${activeTrip.id}',
        );
        return null;
      }

      final trip = TripModel.create(
        userId: safeUserId,
        destination: destination,
        estimatedDurationMinutes: estimatedDurationMinutes,
        startLatitude: startLatitude,
        startLongitude: startLongitude,
        sensitivityLevel: sensitivityLevel,
      );

      await _firestore
          .collection(_tripsCollection)
          .doc(trip.id)
          .set(trip.toFirestore());

      debugPrint('✅ TripService: Trip created successfully: ${trip.id}');
      return trip;
    } catch (e) {
      debugPrint('❌ TripService: Failed to create trip - $e');
      return null;
    }
  }

  Future<TripModel?> getTripById(String tripId) async {
    try {
      final safeTripId = tripId.trim();
      if (safeTripId.isEmpty) return null;

      final doc = await _firestore
          .collection(_tripsCollection)
          .doc(safeTripId)
          .get();

      if (!doc.exists) {
        debugPrint('⚠️ TripService: Trip not found: $safeTripId');
        return null;
      }

      return TripModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('❌ TripService: Failed to get trip - $e');
      return null;
    }
  }

  Future<TripModel?> getActiveTrip(String userId) async {
    try {
      final safeUserId = userId.trim();
      if (safeUserId.isEmpty) return null;

      final querySnapshot = await _firestore
          .collection(_tripsCollection)
          .where('userId', isEqualTo: safeUserId)
          .where('status', isEqualTo: TripStatus.active.value)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      return TripModel.fromFirestore(querySnapshot.docs.first);
    } catch (e) {
      debugPrint('❌ TripService: Failed to get active trip - $e');
      return null;
    }
  }

  Future<List<TripModel>> getUserTrips(
    String userId, {
    int limit = 50,
    TripStatus? status,
  }) async {
    try {
      final safeUserId = userId.trim();
      if (safeUserId.isEmpty) return [];

      Query<Map<String, dynamic>> query = _firestore
          .collection(_tripsCollection)
          .where('userId', isEqualTo: safeUserId);

      if (status != null) {
        query = query.where('status', isEqualTo: status.value);
      }

      query = query.orderBy('startTime', descending: true).limit(limit);

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => TripModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ TripService: Failed to get user trips - $e');
      return [];
    }
  }

  Future<bool> updateTrip(TripModel trip) async {
    try {
      final data = Map<String, dynamic>.from(trip.toFirestore());
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection(_tripsCollection)
          .doc(trip.id)
          .set(data, SetOptions(merge: true));

      debugPrint('✅ TripService: Trip updated successfully: ${trip.id}');
      return true;
    } catch (e) {
      debugPrint('❌ TripService: Failed to update trip - $e');
      return false;
    }
  }

  Future<bool> endTrip({
    required String tripId,
    double? endLatitude,
    double? endLongitude,
  }) async {
    try {
      final trip = await getTripById(tripId);
      if (trip == null) {
        debugPrint('⚠️ TripService: Trip not found for ending: $tripId');
        return false;
      }

      if (trip.status != TripStatus.active) {
        debugPrint(
          '⚠️ TripService: Only active trips can be completed: ${trip.id}',
        );
        return false;
      }

      final updatedTrip = trip.copyWith(
        status: TripStatus.completed,
        endTime: DateTime.now(),
        endLatitude: endLatitude,
        endLongitude: endLongitude,
      );

      return await updateTrip(updatedTrip);
    } catch (e) {
      debugPrint('❌ TripService: Failed to end trip - $e');
      return false;
    }
  }

  Future<bool> cancelTrip(String tripId) async {
    try {
      final trip = await getTripById(tripId);
      if (trip == null) {
        debugPrint('⚠️ TripService: Trip not found for cancellation: $tripId');
        return false;
      }

      if (trip.status != TripStatus.active) {
        debugPrint(
          '⚠️ TripService: Only active trips can be cancelled: ${trip.id}',
        );
        return false;
      }

      final updatedTrip = trip.copyWith(
        status: TripStatus.cancelled,
        endTime: DateTime.now(),
      );

      return await updateTrip(updatedTrip);
    } catch (e) {
      debugPrint('❌ TripService: Failed to cancel trip - $e');
      return false;
    }
  }

  Future<bool> markTripAsEmergency(String tripId) async {
    try {
      final trip = await getTripById(tripId);
      if (trip == null) {
        debugPrint(
          '⚠️ TripService: Trip not found for emergency marking: $tripId',
        );
        return false;
      }

      if (trip.status == TripStatus.completed ||
          trip.status == TripStatus.cancelled) {
        debugPrint(
          '⚠️ TripService: Closed trip cannot be marked as emergency: ${trip.id}',
        );
        return false;
      }

      final updatedTrip = trip.copyWith(status: TripStatus.emergency);

      return await updateTrip(updatedTrip);
    } catch (e) {
      debugPrint('❌ TripService: Failed to mark trip as emergency - $e');
      return false;
    }
  }

  Future<bool> recordAccidentDetection({
    required String tripId,
    required double gForce,
    required double rotation,
    required bool isFalsePositive,
  }) async {
    try {
      final trip = await getTripById(tripId);
      if (trip == null) {
        debugPrint(
          '⚠️ TripService: Trip not found for accident recording: $tripId',
        );
        return false;
      }

      final updatedTrip = trip.copyWith(
        accidentDetectionCount: trip.accidentDetectionCount + 1,
        falsePositiveCount: isFalsePositive
            ? trip.falsePositiveCount + 1
            : trip.falsePositiveCount,
        maxGForceDetected: trip.maxGForceDetected == null
            ? gForce
            : (gForce > trip.maxGForceDetected!
                  ? gForce
                  : trip.maxGForceDetected),
        maxRotationDetected: trip.maxRotationDetected == null
            ? rotation
            : (rotation > trip.maxRotationDetected!
                  ? rotation
                  : trip.maxRotationDetected),
      );

      return await updateTrip(updatedTrip);
    } catch (e) {
      debugPrint('❌ TripService: Failed to record accident detection - $e');
      return false;
    }
  }

  Future<bool> updateEndLocation({
    required String tripId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final trip = await getTripById(tripId);
      if (trip == null) {
        debugPrint(
          '⚠️ TripService: Trip not found for location update: $tripId',
        );
        return false;
      }

      final updatedTrip = trip.copyWith(
        endLatitude: latitude,
        endLongitude: longitude,
      );

      return await updateTrip(updatedTrip);
    } catch (e) {
      debugPrint('❌ TripService: Failed to update end location - $e');
      return false;
    }
  }

  Future<bool> hasActiveTrip(String userId) async {
    final activeTrip = await getActiveTrip(userId);
    return activeTrip != null;
  }

  Future<bool> hasExceededFalsePositiveLimit(String tripId) async {
    final trip = await getTripById(tripId);
    if (trip == null) return false;

    return trip.falsePositiveCount >=
        AppThresholds.maxFalsePositivesBeforeWarning;
  }

  bool isValidTripDuration(int? durationMinutes) {
    if (durationMinutes == null) return true;

    return durationMinutes >= AppThresholds.minTripDurationMinutes &&
        durationMinutes <= (AppThresholds.maxTripDurationHours * 60);
  }

  Stream<TripModel?> watchActiveTrip(String userId) {
    return _firestore
        .collection(_tripsCollection)
        .where('userId', isEqualTo: userId.trim())
        .where('status', isEqualTo: TripStatus.active.value)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return TripModel.fromFirestore(snapshot.docs.first);
        });
  }

  Stream<TripModel?> watchTrip(String tripId) {
    return _firestore
        .collection(_tripsCollection)
        .doc(tripId.trim())
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return TripModel.fromFirestore(doc);
        });
  }

  Future<bool> deleteTrip(String tripId) async {
    try {
      await _firestore.collection(_tripsCollection).doc(tripId).delete();

      debugPrint('✅ TripService: Trip deleted successfully: $tripId');
      return true;
    } catch (e) {
      debugPrint('❌ TripService: Failed to delete trip - $e');
      return false;
    }
  }

  Future<bool> deleteAllUserTrips(String userId) async {
    try {
      final trips = await getUserTrips(userId, limit: 1000);

      for (final trip in trips) {
        await deleteTrip(trip.id);
      }

      debugPrint('✅ TripService: All user trips deleted successfully: $userId');
      return true;
    } catch (e) {
      debugPrint('❌ TripService: Failed to delete all user trips - $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> getTripStatistics(String userId) async {
    try {
      final trips = await getUserTrips(userId, limit: 1000);

      final totalTrips = trips.length;
      final completedTrips = trips
          .where((t) => t.status == TripStatus.completed)
          .length;
      final cancelledTrips = trips
          .where((t) => t.status == TripStatus.cancelled)
          .length;
      final emergencyTrips = trips
          .where((t) => t.status == TripStatus.emergency)
          .length;

      final totalAccidentDetections = trips.fold(
        0,
        (sum, t) => sum + t.accidentDetectionCount,
      );
      final totalFalsePositives = trips.fold(
        0,
        (sum, t) => sum + t.falsePositiveCount,
      );

      final double? maxGForce = trips
          .where((t) => t.maxGForceDetected != null)
          .fold<double?>(
            null,
            (max, t) => max == null || t.maxGForceDetected! > max
                ? t.maxGForceDetected
                : max,
          );

      final double averageAccidentsPerTrip = totalTrips > 0
          ? totalAccidentDetections / totalTrips
          : 0.0;

      return {
        'totalTrips': totalTrips,
        'completedTrips': completedTrips,
        'cancelledTrips': cancelledTrips,
        'emergencyTrips': emergencyTrips,
        'totalAccidentDetections': totalAccidentDetections,
        'totalFalsePositives': totalFalsePositives,
        'maxGForceRecorded': maxGForce ?? 0.0,
        'averageAccidentsPerTrip': averageAccidentsPerTrip,
      };
    } catch (e) {
      debugPrint('❌ TripService: Failed to get trip statistics - $e');
      return {};
    }
  }
}
