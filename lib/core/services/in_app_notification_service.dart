import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';

/// ==========================================
/// 🔔 In-App Notification Service - Guardian 360
/// ==========================================
/// مسؤول فقط عن إشعارات المستخدم داخل التطبيق.
///
/// Firestore path:
/// users/{uid}/notifications/{notificationId}
///
/// مهم جدًا:
/// - لا ينشئ accidents.
/// - لا ينشئ alerts.
/// - لا يتعامل مع البلاغات الرسمية كمصدر حقيقة.
/// - لا يشغل أصوات طوارئ.
/// - يستخدم فقط لمركز الإشعارات داخل التطبيق.
class InAppNotificationService {
  InAppNotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const String _usersCollection = 'users';
  static const String _notificationsCollection = 'notifications';

  static const Duration _firestoreTimeout = Duration(seconds: 8);

  static const int defaultLimit = 50;
  static const int maxLimit = 100;
  static const int maxUnreadCountLimit = 100;
  static const int maxMarkAllBatchSize = 100;

  static const Set<String> _allowedTypes = <String>{
    // System / operational
    'offline_sync_success',
    'battery_low',
    'system_notice',

    // Emergency / accident
    'accident_pre_alert',
    'emergency_report_sent',
    'status_change',
    'incident_status_change',

    // Safe Arrival
    'safe_arrival_started',
    'safe_arrival_paused',
    'safe_arrival_resumed',
    'safe_arrival_near_destination',
    'safe_arrival_arrived',
    'safe_arrival_cancelled',
    'safe_arrival_danger',
  };

  static const Set<String> _allowedPriorities = <String>{
    'low',
    'normal',
    'high',
    'critical',
  };

  CollectionReference<Map<String, dynamic>> _notificationsRef(String uid) {
    return _firestore
        .collection(_usersCollection)
        .doc(uid)
        .collection(_notificationsCollection);
  }

  /// Stream latest user notifications.
  ///
  /// This reads UI notifications only.
  Stream<List<NotificationModel>> streamUserNotifications(
    String uid, {
    int limit = defaultLimit,
  }) async* {
    final safeUid = _trimToNull(uid);

    if (safeUid == null) {
      debugPrint(
        '⚠️ InAppNotificationService: streamUserNotifications skipped - missing uid',
      );
      yield const <NotificationModel>[];
      return;
    }

    final safeLimit = limit.clamp(1, maxLimit);

    try {
      final snapshots = _notificationsRef(
        safeUid,
      ).orderBy('createdAt', descending: true).limit(safeLimit).snapshots();

      await for (final snapshot in snapshots) {
        final notifications = <NotificationModel>[];

        for (final doc in snapshot.docs) {
          try {
            notifications.add(NotificationModel.fromFirestore(doc));
          } catch (e, stackTrace) {
            debugPrint(
              '⚠️ InAppNotificationService: Failed to parse notification ${doc.id} - $e',
            );
            debugPrintStack(stackTrace: stackTrace);
          }
        }

        yield notifications;
      }
    } catch (e, stackTrace) {
      debugPrint(
        '❌ InAppNotificationService: Failed to stream notifications - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
      yield const <NotificationModel>[];
    }
  }

  /// Stream unread count.
  ///
  /// Limited intentionally to avoid heavy reads.
  /// UI can show 9+ or 99+.
  Stream<int> streamUnreadCount(String uid) async* {
    final safeUid = _trimToNull(uid);

    if (safeUid == null) {
      debugPrint(
        '⚠️ InAppNotificationService: streamUnreadCount skipped - missing uid',
      );
      yield 0;
      return;
    }

    try {
      final snapshots = _notificationsRef(safeUid)
          .where('isRead', isEqualTo: false)
          .limit(maxUnreadCountLimit)
          .snapshots();

      await for (final snapshot in snapshots) {
        yield snapshot.docs.length;
      }
    } catch (e, stackTrace) {
      debugPrint(
        '❌ InAppNotificationService: Failed to stream unread count - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
      yield 0;
    }
  }

  /// Create a user-facing in-app notification.
  ///
  /// This is best-effort and must never be used as an emergency report.
  Future<bool> createNotification({
    required String uid,
    required String type,
    required String titleAr,
    required String titleEn,
    required String bodyAr,
    required String bodyEn,
    String priority = 'normal',
    String source = 'system',
    String? relatedAccidentId,
    Map<String, dynamic>? payload,
  }) async {
    final safeUid = _trimToNull(uid);

    if (safeUid == null) {
      debugPrint(
        '⚠️ InAppNotificationService: createNotification skipped - missing uid',
      );
      return false;
    }

    final safeType = _normalizeType(type);
    final safePriority = _normalizePriority(priority);
    final safeSource = _trimToNull(source) ?? 'system';
    final safeTitleAr = _trimToNull(titleAr) ?? 'إشعار جديد';
    final safeTitleEn = _trimToNull(titleEn) ?? 'New notification';
    final safeBodyAr = _trimToNull(bodyAr) ?? '';
    final safeBodyEn = _trimToNull(bodyEn) ?? '';
    final safeRelatedAccidentId = _trimToNull(relatedAccidentId);

    try {
      final data = _removeNullValues({
        'type': safeType,
        'titleAr': safeTitleAr,
        'titleEn': safeTitleEn,
        'bodyAr': safeBodyAr,
        'bodyEn': safeBodyEn,
        'isRead': false,
        'priority': safePriority,
        'source': safeSource,
        'relatedAccidentId': safeRelatedAccidentId,
        'payload': _jsonSafeMap({
          ...?payload,
          'isUserFacingNotification': true,
          'isOfficialEmergencyReport': false,
        }),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _notificationsRef(safeUid).add(data).timeout(_firestoreTimeout);

      debugPrint(
        '✅ InAppNotificationService: Notification created '
        '(uid=$safeUid, type=$safeType)',
      );

      return true;
    } on TimeoutException {
      debugPrint('⏱️ InAppNotificationService: createNotification timeout');
      return false;
    } catch (e, stackTrace) {
      debugPrint(
        '❌ InAppNotificationService: Failed to create notification - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// Mark one notification as read.
  Future<bool> markAsRead({
    required String uid,
    required String notificationId,
  }) async {
    final safeUid = _trimToNull(uid);
    final safeNotificationId = _trimToNull(notificationId);

    if (safeUid == null || safeNotificationId == null) {
      debugPrint(
        '⚠️ InAppNotificationService: markAsRead skipped - missing uid or notificationId',
      );
      return false;
    }

    try {
      await _notificationsRef(safeUid)
          .doc(safeNotificationId)
          .update({
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(_firestoreTimeout);

      debugPrint(
        '✅ InAppNotificationService: Notification marked as read '
        '(id=$safeNotificationId)',
      );

      return true;
    } on TimeoutException {
      debugPrint('⏱️ InAppNotificationService: markAsRead timeout');
      return false;
    } catch (e, stackTrace) {
      debugPrint(
        '❌ InAppNotificationService: Failed to mark notification as read - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// Mark latest unread notifications as read.
  ///
  /// Batch is limited to keep Firestore writes safe.
  Future<bool> markAllAsRead(String uid) async {
    final safeUid = _trimToNull(uid);

    if (safeUid == null) {
      debugPrint(
        '⚠️ InAppNotificationService: markAllAsRead skipped - missing uid',
      );
      return false;
    }

    try {
      final snapshot = await _notificationsRef(safeUid)
          .where('isRead', isEqualTo: false)
          .limit(maxMarkAllBatchSize)
          .get()
          .timeout(_firestoreTimeout);

      if (snapshot.docs.isEmpty) {
        debugPrint('ℹ️ InAppNotificationService: No unread notifications');
        return true;
      }

      final batch = _firestore.batch();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit().timeout(_firestoreTimeout);

      debugPrint(
        '✅ InAppNotificationService: Marked all as read '
        '(${snapshot.docs.length} notifications)',
      );

      return true;
    } on TimeoutException {
      debugPrint('⏱️ InAppNotificationService: markAllAsRead timeout');
      return false;
    } catch (e, stackTrace) {
      debugPrint('❌ InAppNotificationService: Failed to mark all as read - $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  /// Optional safe delete for one in-app notification.
  ///
  /// This does not affect accidents or alerts.
  Future<bool> deleteNotification({
    required String uid,
    required String notificationId,
  }) async {
    final safeUid = _trimToNull(uid);
    final safeNotificationId = _trimToNull(notificationId);

    if (safeUid == null || safeNotificationId == null) {
      debugPrint(
        '⚠️ InAppNotificationService: deleteNotification skipped - missing uid or notificationId',
      );
      return false;
    }

    try {
      await _notificationsRef(
        safeUid,
      ).doc(safeNotificationId).delete().timeout(_firestoreTimeout);

      debugPrint(
        '✅ InAppNotificationService: Notification deleted '
        '(id=$safeNotificationId)',
      );

      return true;
    } on TimeoutException {
      debugPrint('⏱️ InAppNotificationService: deleteNotification timeout');
      return false;
    } catch (e, stackTrace) {
      debugPrint(
        '❌ InAppNotificationService: Failed to delete notification - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  // ==========================================
  // Helpers
  // ==========================================

  static String? _trimToNull(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  static String _normalizeType(String value) {
    final normalized = value.trim().toLowerCase();

    if (_allowedTypes.contains(normalized)) {
      return normalized;
    }

    debugPrint(
      '⚠️ InAppNotificationService: Unknown notification type "$value", fallback to system_notice',
    );

    return 'system_notice';
  }

  static String _normalizePriority(String value) {
    final normalized = value.trim().toLowerCase();

    if (_allowedPriorities.contains(normalized)) {
      return normalized;
    }

    return 'normal';
  }

  static Map<String, dynamic> _jsonSafeMap(Map<String, dynamic>? input) {
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

  static dynamic _jsonSafeValue(dynamic value) {
    if (value == null) return null;

    if (value is String || value is bool) return value;

    if (value is num) {
      if (value.isNaN || value.isInfinite) return null;
      return value;
    }

    if (value is DateTime) {
      return value.toIso8601String();
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

  static Map<String, dynamic> _removeNullValues(Map<String, dynamic> map) {
    final result = Map<String, dynamic>.from(map);
    result.removeWhere((_, value) => value == null);
    return result;
  }
}
