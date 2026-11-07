import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/notification_model.dart';
import '../../../core/services/in_app_notification_service.dart';

/// ==========================================
/// 🔔 Notification Center ViewModel - Guardian 360
/// ==========================================
/// مسؤول عن إدارة حالة مركز الإشعارات داخل التطبيق.
///
/// مهم:
/// - لا يحتوي Firestore logic مباشر.
/// - لا ينشئ accidents.
/// - لا ينشئ alerts.
/// - لا يلمس SOS أو accident detection.
/// - يعتمد فقط على InAppNotificationService.
class NotificationCenterViewModel extends ChangeNotifier {
  NotificationCenterViewModel({
    InAppNotificationService? notificationService,
    FirebaseAuth? auth,
    bool autoInitialize = true,
  }) : _notificationService = notificationService ?? InAppNotificationService(),
       _auth = auth ?? FirebaseAuth.instance {
    if (autoInitialize) {
      initialize();
    }
  }

  final InAppNotificationService _notificationService;
  final FirebaseAuth _auth;

  StreamSubscription<List<NotificationModel>>? _notificationsSubscription;
  StreamSubscription<int>? _unreadCountSubscription;

  List<NotificationModel> _notifications = const <NotificationModel>[];

  NotificationCategory _selectedCategory = NotificationCategory.all;

  int _unreadCount = 0;

  bool _isLoading = false;
  bool _isActionLoading = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  String? _activeUid;
  String? _errorMessage;

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  /// التصنيف الحالي المعروض في مركز الإشعارات.
  ///
  /// ملاحظة مهمة:
  /// هذا لا يغير unreadCount الأصلي ولا يغير البيانات القادمة من Firestore.
  /// هو فقط يحدد أي قائمة تعرضها الشاشة.
  NotificationCategory get selectedCategory => _selectedCategory;

  /// قائمة الإشعارات بعد تطبيق الفلتر الحالي.
  ///
  /// - all: كل الإشعارات.
  /// - safeArrival: إشعارات الوصول الآمن فقط.
  /// - emergency: إشعارات الطوارئ/SOS والحوادث فقط.
  /// - kroka: إشعارات تقارير الكروكة فقط.
  /// - system: إشعارات النظام فقط.
  List<NotificationModel> get filteredNotifications => List.unmodifiable(
    _filterNotificationsByCategory(_notifications, _selectedCategory),
  );

  /// التصنيفات المدعومة في واجهة مركز الإشعارات.
  List<NotificationCategory> get availableCategories =>
      const <NotificationCategory>[
        NotificationCategory.all,
        NotificationCategory.safeArrival,
        NotificationCategory.emergency,
        NotificationCategory.kroka,
        NotificationCategory.system,
      ];

  int get unreadCount => _unreadCount;

  /// عدد غير المقروء داخل الفلتر الحالي فقط.
  ///
  /// لا يستبدل unreadCount العام، بل يفيد الشاشة إذا أرادت عرض badge
  /// للتصنيف الحالي.
  int get selectedCategoryUnreadCount =>
      _countUnreadByCategory(_selectedCategory);

  int get allNotificationsCount => _notifications.length;

  int get safeArrivalNotificationsCount =>
      _countByCategory(NotificationCategory.safeArrival);

  int get emergencyNotificationsCount =>
      _countByCategory(NotificationCategory.emergency);

  int get krokaNotificationsCount =>
      _countByCategory(NotificationCategory.kroka);

  int get systemNotificationsCount =>
      _countByCategory(NotificationCategory.system);

  bool get isLoading => _isLoading;
  bool get isActionLoading => _isActionLoading;
  bool get isInitialized => _isInitialized;

  String? get errorMessage => _errorMessage;

  bool get hasError =>
      _errorMessage != null && _errorMessage!.trim().isNotEmpty;

  bool get hasNotifications => _notifications.isNotEmpty;
  bool get hasFilteredNotifications => filteredNotifications.isNotEmpty;
  bool get hasUnreadNotifications => _unreadCount > 0;

  bool get isShowingAllNotifications =>
      _selectedCategory == NotificationCategory.all;

  String? get currentUserId => _auth.currentUser?.uid;

  // ==========================================
  // 🚀 Initialization
  // ==========================================

  void initialize() {
    if (_isDisposed) return;

    final uid = currentUserId?.trim();

    if (uid == null || uid.isEmpty) {
      _setSignedOutState();
      return;
    }

    if (_isInitialized && _activeUid == uid) {
      return;
    }

    _cancelSubscriptions();

    _activeUid = uid;
    _isInitialized = true;
    _isLoading = true;
    _errorMessage = null;

    _safeNotify();

    _listenToNotifications(uid);
    _listenToUnreadCount(uid);
  }

  void retry() {
    if (_isDisposed) return;

    _cancelSubscriptions();

    _isInitialized = false;
    _activeUid = null;
    _notifications = const <NotificationModel>[];
    _unreadCount = 0;
    _errorMessage = null;
    _isLoading = false;
    _isActionLoading = false;

    _safeNotify();

    initialize();
  }

  void _setSignedOutState() {
    _cancelSubscriptions();

    _activeUid = null;
    _isInitialized = false;
    _notifications = const <NotificationModel>[];
    _unreadCount = 0;
    _isLoading = false;
    _isActionLoading = false;
    _errorMessage = 'User is not signed in';

    _safeNotify();
  }

  // ==========================================
  // 🔴 Streams
  // ==========================================

  void _listenToNotifications(String uid) {
    _notificationsSubscription?.cancel();

    _notificationsSubscription = _notificationService
        .streamUserNotifications(uid)
        .listen(
          (items) {
            if (_isDisposed) return;

            _notifications = _sortByNewest(items);
            _isLoading = false;
            _errorMessage = null;

            _safeNotify();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_isDisposed) return;

            debugPrint(
              '❌ NotificationCenterViewModel: Notifications stream error - $error',
            );
            debugPrintStack(stackTrace: stackTrace);

            _isLoading = false;
            _errorMessage = 'Failed to load notifications';

            _safeNotify();
          },
          cancelOnError: false,
        );
  }

  void _listenToUnreadCount(String uid) {
    _unreadCountSubscription?.cancel();

    _unreadCountSubscription = _notificationService
        .streamUnreadCount(uid)
        .listen(
          (count) {
            if (_isDisposed) return;

            final safeCount = count < 0 ? 0 : count;

            if (_unreadCount == safeCount) {
              return;
            }

            _unreadCount = safeCount;
            _safeNotify();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_isDisposed) return;

            debugPrint(
              '❌ NotificationCenterViewModel: Unread count stream error - $error',
            );
            debugPrintStack(stackTrace: stackTrace);

            _unreadCount = 0;
            _safeNotify();
          },
          cancelOnError: false,
        );
  }

  // ==========================================
  // 🧭 Filters
  // ==========================================

  void selectCategory(NotificationCategory category) {
    if (_isDisposed) return;

    if (_selectedCategory == category) {
      return;
    }

    _selectedCategory = category;
    _safeNotify();
  }

  void showAllNotifications() {
    selectCategory(NotificationCategory.all);
  }

  void showSafeArrivalNotifications() {
    selectCategory(NotificationCategory.safeArrival);
  }

  void showEmergencyNotifications() {
    selectCategory(NotificationCategory.emergency);
  }

  void showKrokaNotifications() {
    selectCategory(NotificationCategory.kroka);
  }

  void showSystemNotifications() {
    selectCategory(NotificationCategory.system);
  }

  // ==========================================
  // ✅ Actions
  // ==========================================

  Future<bool> markAsRead(String notificationId) async {
    if (_isDisposed || _isActionLoading) return false;

    final uid = currentUserId?.trim();
    final safeNotificationId = notificationId.trim();

    if (uid == null || uid.isEmpty || safeNotificationId.isEmpty) {
      return false;
    }

    final existing = _findNotification(safeNotificationId);

    if (existing != null && existing.isRead) {
      return true;
    }

    _isActionLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final success = await _notificationService.markAsRead(
        uid: uid,
        notificationId: safeNotificationId,
      );

      if (!success) {
        _errorMessage = 'Failed to mark notification as read';
      }

      return success;
    } catch (e, stackTrace) {
      debugPrint('❌ NotificationCenterViewModel: markAsRead failed - $e');
      debugPrintStack(stackTrace: stackTrace);

      _errorMessage = 'Failed to mark notification as read';
      return false;
    } finally {
      _isActionLoading = false;
      _safeNotify();
    }
  }

  Future<bool> markAllAsRead() async {
    if (_isDisposed || _isActionLoading) return false;

    final uid = currentUserId?.trim();

    if (uid == null || uid.isEmpty) {
      return false;
    }

    if (_unreadCount <= 0) {
      return true;
    }

    _isActionLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final success = await _notificationService.markAllAsRead(uid);

      if (!success) {
        _errorMessage = 'Failed to mark all notifications as read';
      }

      return success;
    } catch (e, stackTrace) {
      debugPrint('❌ NotificationCenterViewModel: markAllAsRead failed - $e');
      debugPrintStack(stackTrace: stackTrace);

      _errorMessage = 'Failed to mark all notifications as read';
      return false;
    } finally {
      _isActionLoading = false;
      _safeNotify();
    }
  }

  Future<bool> deleteNotification(String notificationId) async {
    if (_isDisposed || _isActionLoading) return false;

    final uid = currentUserId?.trim();
    final safeNotificationId = notificationId.trim();

    if (uid == null || uid.isEmpty || safeNotificationId.isEmpty) {
      return false;
    }

    _isActionLoading = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final success = await _notificationService.deleteNotification(
        uid: uid,
        notificationId: safeNotificationId,
      );

      if (!success) {
        _errorMessage = 'Failed to delete notification';
      }

      return success;
    } catch (e, stackTrace) {
      debugPrint(
        '❌ NotificationCenterViewModel: deleteNotification failed - $e',
      );
      debugPrintStack(stackTrace: stackTrace);

      _errorMessage = 'Failed to delete notification';
      return false;
    } finally {
      _isActionLoading = false;
      _safeNotify();
    }
  }

  /// Removes [notificationId] from the local list **immediately** (optimistic
  /// update), then deletes from Firestore asynchronously.
  ///
  /// This is the correct method to call from a [Dismissible.onDismissed]
  /// callback because it guarantees the item is gone from state before Flutter
  /// tries to reconcile the dismissed widget back into the tree.
  ///
  /// If the Firestore deletion fails the item is silently re-inserted at its
  /// original position so the user can try again.
  void optimisticDelete(String notificationId) {
    if (_isDisposed) return;

    final uid = currentUserId?.trim();
    final safeId = notificationId.trim();

    if (uid == null || uid.isEmpty || safeId.isEmpty) return;

    // ── 1. Synchronous optimistic removal ────────────────────────────────
    final originalIndex = _notifications.indexWhere((n) => n.id == safeId);

    if (originalIndex < 0) return; // Already gone — nothing to do.

    final removedItem = _notifications[originalIndex];
    final mutable = List<NotificationModel>.from(_notifications);
    mutable.removeAt(originalIndex);
    _notifications = mutable;
    _safeNotify();

    // ── 2. Async backend deletion — no await here ─────────────────────────
    _notificationService
        .deleteNotification(uid: uid, notificationId: safeId)
        .then((success) {
          if (_isDisposed) return;

          if (!success) {
            debugPrint(
              '⚠️ NotificationCenterViewModel: optimisticDelete backend '
              'failed for $safeId — rolling back.',
            );
            // Rollback: re-insert the item at the original position.
            final rollback = List<NotificationModel>.from(_notifications);
            final clampedIndex = originalIndex.clamp(0, rollback.length);
            rollback.insert(clampedIndex, removedItem);
            _notifications = rollback;
            _errorMessage = 'Failed to delete notification';
            _safeNotify();
          }
        })
        .catchError((Object error, StackTrace stackTrace) {
          if (_isDisposed) return;

          debugPrint(
            '❌ NotificationCenterViewModel: optimisticDelete error '
            'for $safeId — $error',
          );
          debugPrintStack(stackTrace: stackTrace);

          // Rollback on error.
          final rollback = List<NotificationModel>.from(_notifications);
          final clampedIndex = originalIndex.clamp(0, rollback.length);
          rollback.insert(clampedIndex, removedItem);
          _notifications = rollback;
          _errorMessage = 'Failed to delete notification';
          _safeNotify();
        });
  }

  void clearError() {
    if (_isDisposed) return;

    _errorMessage = null;
    _safeNotify();
  }

  // ==========================================
  // Helpers
  // ==========================================

  NotificationModel? _findNotification(String notificationId) {
    for (final notification in _notifications) {
      if (notification.id == notificationId) {
        return notification;
      }
    }

    return null;
  }

  List<NotificationModel> _sortByNewest(List<NotificationModel> items) {
    final sorted = List<NotificationModel>.from(items);

    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return sorted;
  }

  List<NotificationModel> _filterNotificationsByCategory(
    List<NotificationModel> items,
    NotificationCategory category,
  ) {
    if (category == NotificationCategory.all) {
      return List<NotificationModel>.from(items);
    }

    return items
        .where((notification) => notification.category == category)
        .toList(growable: false);
  }

  int _countByCategory(NotificationCategory category) {
    return _filterNotificationsByCategory(_notifications, category).length;
  }

  int _countUnreadByCategory(NotificationCategory category) {
    final scopedNotifications = _filterNotificationsByCategory(
      _notifications,
      category,
    );

    return scopedNotifications
        .where((notification) => !notification.isRead)
        .length;
  }

  void _cancelSubscriptions() {
    _notificationsSubscription?.cancel();
    _notificationsSubscription = null;

    _unreadCountSubscription?.cancel();
    _unreadCountSubscription = null;
  }

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    _cancelSubscriptions();

    super.dispose();
  }
}
