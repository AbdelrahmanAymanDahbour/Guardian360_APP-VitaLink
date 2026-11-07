import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firebase_messaging_service.dart';
import 'firebase_service.dart';

/// ==========================================
/// 📊 Dashboard Sync Service - Guardian 360
/// ==========================================
/// خدمة مزامنة حالة المستخدم مع لوحة التحكم.
///
/// المسؤوليات:
/// - تتبع حالة المستخدم: isOnline.
/// - تحديث آخر ظهور: lastSeen.
/// - حفظ FCM token للإشعارات.
/// - تجهيز بيانات presence التي قد يحتاجها dashboard.
///
/// غير مسؤول عن:
/// - إنشاء accidents.
/// - إنشاء alerts.
/// - تشغيل SOS.
/// - منطق الحساسات.
/// - منطق واجهات المستخدم.
///
/// ملاحظة:
/// FirebaseService.updateUser() يضيف updatedAt تلقائياً.
class DashboardSyncService {
  DashboardSyncService({
    FirebaseService? firebaseService,
    FirebaseMessagingService? messagingService,
  }) : _ownsMessagingService = messagingService == null,
       _firebaseService = firebaseService ?? FirebaseService(),
       _messagingService = messagingService ?? FirebaseMessagingService();

  final FirebaseService _firebaseService;
  final FirebaseMessagingService _messagingService;
  final bool _ownsMessagingService;

  static const Duration _syncTimeout = Duration(seconds: 8);
  static const Duration _tokenTimeout = Duration(seconds: 8);

  bool _isDisposed = false;

  // ==========================================
  // 👤 USER PRESENCE MANAGEMENT
  // ==========================================

  Future<DashboardSyncResult<void>> setUserOnline(String userId) async {
    final safeUserId = _normalizeUserId(userId);

    if (safeUserId == null) {
      return _invalidUserIdResult();
    }

    if (_isDisposed) {
      return _disposedResult();
    }

    try {
      final result = await _firebaseService
          .updateUser(safeUserId, {
            'isOnline': true,
            'lastSeen': FieldValue.serverTimestamp(),
            'presenceUpdatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(_syncTimeout);

      if (result.isFailure) {
        return DashboardSyncResult.failure(
          DashboardSyncException(
            message: 'Failed to set user online',
            code: 'set-online-failed',
            originalError: result.error,
          ),
        );
      }

      debugPrint('✅ DashboardSyncService: User set online - $safeUserId');
      return DashboardSyncResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ DashboardSyncService: setUserOnline timeout');
      return DashboardSyncResult.failure(
        DashboardSyncException(
          message: 'Set user online timed out',
          code: 'set-online-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ DashboardSyncService: Failed to set user online - $e');
      return DashboardSyncResult.failure(
        DashboardSyncException(
          message: 'Failed to set user online',
          code: 'set-online-error',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<DashboardSyncResult<void>> setUserOffline(String userId) async {
    final safeUserId = _normalizeUserId(userId);

    if (safeUserId == null) {
      return _invalidUserIdResult();
    }

    if (_isDisposed) {
      return _disposedResult();
    }

    try {
      final result = await _firebaseService
          .updateUser(safeUserId, {
            'isOnline': false,
            'lastSeen': FieldValue.serverTimestamp(),
            'presenceUpdatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(_syncTimeout);

      if (result.isFailure) {
        return DashboardSyncResult.failure(
          DashboardSyncException(
            message: 'Failed to set user offline',
            code: 'set-offline-failed',
            originalError: result.error,
          ),
        );
      }

      debugPrint('✅ DashboardSyncService: User set offline - $safeUserId');
      return DashboardSyncResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ DashboardSyncService: setUserOffline timeout');
      return DashboardSyncResult.failure(
        DashboardSyncException(
          message: 'Set user offline timed out',
          code: 'set-offline-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ DashboardSyncService: Failed to set user offline - $e');
      return DashboardSyncResult.failure(
        DashboardSyncException(
          message: 'Failed to set user offline',
          code: 'set-offline-error',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<DashboardSyncResult<void>> updateLastSeen(String userId) async {
    final safeUserId = _normalizeUserId(userId);

    if (safeUserId == null) {
      return _invalidUserIdResult();
    }

    if (_isDisposed) {
      return _disposedResult();
    }

    try {
      final result = await _firebaseService
          .updateUser(safeUserId, {
            'lastSeen': FieldValue.serverTimestamp(),
            'presenceUpdatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(_syncTimeout);

      if (result.isFailure) {
        return DashboardSyncResult.failure(
          DashboardSyncException(
            message: 'Failed to update last seen',
            code: 'update-last-seen-failed',
            originalError: result.error,
          ),
        );
      }

      debugPrint('✅ DashboardSyncService: Last seen updated - $safeUserId');
      return DashboardSyncResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ DashboardSyncService: updateLastSeen timeout');
      return DashboardSyncResult.failure(
        DashboardSyncException(
          message: 'Update last seen timed out',
          code: 'update-last-seen-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ DashboardSyncService: Failed to update last seen - $e');
      return DashboardSyncResult.failure(
        DashboardSyncException(
          message: 'Failed to update last seen',
          code: 'update-last-seen-error',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ==========================================
  // 🔔 FCM TOKEN MANAGEMENT
  // ==========================================

  Future<DashboardSyncResult<void>> saveFCMToken(
    String userId,
    String token,
  ) async {
    final safeUserId = _normalizeUserId(userId);

    if (safeUserId == null) {
      return _invalidUserIdResult();
    }

    if (_isDisposed) {
      return _disposedResult();
    }

    final safeToken = token.trim();

    if (safeToken.isEmpty) {
      return DashboardSyncResult.failure(
        DashboardSyncException(
          message: 'FCM token cannot be empty',
          code: 'invalid-fcm-token',
        ),
      );
    }

    try {
      final result = await _firebaseService
          .updateUser(safeUserId, {
            'fcmToken': safeToken,
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
            'lastSeen': FieldValue.serverTimestamp(),
          })
          .timeout(_syncTimeout);

      if (result.isFailure) {
        return DashboardSyncResult.failure(
          DashboardSyncException(
            message: 'Failed to save FCM token',
            code: 'save-fcm-token-failed',
            originalError: result.error,
          ),
        );
      }

      debugPrint(
        '✅ DashboardSyncService: FCM token saved - '
        '$safeUserId (${_shortToken(safeToken)})',
      );

      return DashboardSyncResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ DashboardSyncService: saveFCMToken timeout');
      return DashboardSyncResult.failure(
        DashboardSyncException(
          message: 'Save FCM token timed out',
          code: 'save-fcm-token-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ DashboardSyncService: Failed to save FCM token - $e');
      return DashboardSyncResult.failure(
        DashboardSyncException(
          message: 'Failed to save FCM token',
          code: 'save-fcm-token-error',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  Future<DashboardSyncResult<void>> initializeFCMToken(String userId) async {
    final safeUserId = _normalizeUserId(userId);

    if (safeUserId == null) {
      return _invalidUserIdResult();
    }

    if (_isDisposed) {
      return _disposedResult();
    }

    try {
      final tokenResult = await _messagingService.getToken().timeout(
        _tokenTimeout,
      );

      if (tokenResult.isFailure || tokenResult.data == null) {
        debugPrint(
          '⚠️ DashboardSyncService: Failed to get FCM token - ${tokenResult.error}',
        );

        return DashboardSyncResult.failure(
          DashboardSyncException(
            message: 'Failed to get FCM token',
            code: 'fcm-token-fetch-failed',
            originalError: tokenResult.error,
          ),
        );
      }

      final token = tokenResult.data!.trim();

      if (token.isEmpty) {
        return DashboardSyncResult.failure(
          DashboardSyncException(
            message: 'FCM token is null or empty',
            code: 'fcm-token-null',
          ),
        );
      }

      final saveResult = await saveFCMToken(safeUserId, token);

      if (saveResult.isFailure) {
        return saveResult;
      }

      debugPrint('✅ DashboardSyncService: FCM token initialized - $safeUserId');
      return DashboardSyncResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ DashboardSyncService: initializeFCMToken timeout');
      return DashboardSyncResult.failure(
        DashboardSyncException(
          message: 'Initialize FCM token timed out',
          code: 'initialize-fcm-token-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ DashboardSyncService: Failed to initialize FCM token - $e');
      return DashboardSyncResult.failure(
        DashboardSyncException(
          message: 'Failed to initialize FCM token',
          code: 'initialize-fcm-token-error',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Optional helper for logout/delete flows.
  ///
  /// لا نستدعيه إجبارياً في signOut حالياً لأن إبقاء آخر token قد يفيد
  /// في بعض سيناريوهات إعادة الدخول، لكن الدالة جاهزة إذا احتجناها لاحقاً.
  Future<DashboardSyncResult<void>> clearFCMToken(String userId) async {
    final safeUserId = _normalizeUserId(userId);

    if (safeUserId == null) {
      return _invalidUserIdResult();
    }

    if (_isDisposed) {
      return _disposedResult();
    }

    try {
      final result = await _firebaseService
          .updateUser(safeUserId, {
            'fcmToken': '',
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
            'lastSeen': FieldValue.serverTimestamp(),
          })
          .timeout(_syncTimeout);

      if (result.isFailure) {
        return DashboardSyncResult.failure(
          DashboardSyncException(
            message: 'Failed to clear FCM token',
            code: 'clear-fcm-token-failed',
            originalError: result.error,
          ),
        );
      }

      debugPrint('✅ DashboardSyncService: FCM token cleared - $safeUserId');
      return DashboardSyncResult.success(null);
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('⏱️ DashboardSyncService: clearFCMToken timeout');
      return DashboardSyncResult.failure(
        DashboardSyncException(
          message: 'Clear FCM token timed out',
          code: 'clear-fcm-token-timeout',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ DashboardSyncService: Failed to clear FCM token - $e');
      return DashboardSyncResult.failure(
        DashboardSyncException(
          message: 'Failed to clear FCM token',
          code: 'clear-fcm-token-error',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  // ==========================================
  // 🧩 Combined Helpers
  // ==========================================

  /// مناسب بعد login مباشرة:
  /// - يضع المستخدم online.
  /// - يحاول حفظ FCM token.
  ///
  /// فشل FCM token لا يلغي online state.
  Future<DashboardSyncResult<void>> syncUserOnlineSession(String userId) async {
    final onlineResult = await setUserOnline(userId);

    if (onlineResult.isFailure) {
      return onlineResult;
    }

    final tokenResult = await initializeFCMToken(userId);

    if (tokenResult.isFailure) {
      debugPrint(
        '⚠️ DashboardSyncService: User is online but FCM token sync failed - ${tokenResult.error}',
      );
    }

    return DashboardSyncResult.success(null);
  }

  // ==========================================
  // Helpers
  // ==========================================

  String? _normalizeUserId(String userId) {
    final safeUserId = userId.trim();
    return safeUserId.isEmpty ? null : safeUserId;
  }

  DashboardSyncResult<void> _invalidUserIdResult() {
    return DashboardSyncResult.failure(
      DashboardSyncException(
        message: 'User ID cannot be empty',
        code: 'invalid-user-id',
      ),
    );
  }

  DashboardSyncResult<void> _disposedResult() {
    return DashboardSyncResult.failure(
      DashboardSyncException(
        message: 'DashboardSyncService is disposed',
        code: 'service-disposed',
      ),
    );
  }

  String _shortToken(String token) {
    if (token.length <= 12) return 'token hidden';
    return '${token.substring(0, 6)}...${token.substring(token.length - 4)}';
  }

  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    if (_ownsMessagingService) {
      await _messagingService.dispose();
    }

    debugPrint('🧹 DashboardSyncService: Disposed');
  }
}

// ==========================================
// 📦 DATA MODELS
// ==========================================

class DashboardSyncResult<T> {
  final T? data;
  final DashboardSyncException? error;
  final bool isSuccess;

  DashboardSyncResult._({this.data, this.error, required this.isSuccess});

  factory DashboardSyncResult.success(T? data) {
    return DashboardSyncResult._(data: data, isSuccess: true);
  }

  factory DashboardSyncResult.failure(DashboardSyncException error) {
    return DashboardSyncResult._(error: error, isSuccess: false);
  }

  bool get isFailure => !isSuccess;
}

class DashboardSyncException {
  final String message;
  final String code;
  final Object? originalError;
  final StackTrace? stackTrace;

  DashboardSyncException({
    required this.message,
    required this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'DashboardSyncException(code: $code, message: $message)';
  }
}
