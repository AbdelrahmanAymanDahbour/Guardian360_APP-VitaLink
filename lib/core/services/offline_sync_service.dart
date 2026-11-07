import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_thresholds.dart';
import 'alert_service.dart';
import 'firebase_service.dart';
import 'notification_service.dart';

/// ==========================================
/// 📡 Offline Sync Service - Guardian 360
/// ==========================================
/// Handles emergency reports that could not be sent online.
///
/// Responsibilities:
/// - Save failed emergency reports locally.
/// - Preserve emergency source: manual_sos / auto_detection.
/// - Preserve severity and score.
/// - Sync pending reports when internet returns.
/// - Send synced reports through FirebaseService.reportAccident().
/// - Best-effort create alerts projection for dashboard compatibility.
/// - Send ONE quiet sync-success confirmation after successful sync batch.
///
/// Important notification rule:
/// - This service does NOT trigger emergency/accident notifications during sync.
/// - It may send ONE quiet sync-success confirmation after successful synced reports.
/// - Sync confirmation must never be treated as a new accident.
/// - NotificationService handles local notification + in-app notification storage.
///
/// Not responsible for:
/// - Sensor detection.
/// - SOS countdown.
/// - GPS resolution.
/// - UI state.
/// - Local emergency accident/pre-alert notifications.
class OfflineSyncService {
  OfflineSyncService({
    FirebaseService? firebaseService,
    AlertService? alertService,
    NotificationService? notificationService,
    Connectivity? connectivity,
    bool autoStartListener = true,
    bool notifyOnSyncSuccess = true,
  }) : _firebaseService = firebaseService ?? FirebaseService(),
       _alertService = alertService ?? AlertService(),
       _notificationService = notificationService ?? NotificationService(),
       _ownsNotificationService = notificationService == null,
       _connectivity = connectivity ?? Connectivity(),
       _notifyOnSyncSuccess = notifyOnSyncSuccess {
    if (autoStartListener) {
      _initConnectivityListener();
      unawaited(_syncIfAlreadyOnline());
    }
  }

  final FirebaseService _firebaseService;
  final AlertService _alertService;
  final NotificationService _notificationService;
  final Connectivity _connectivity;

  final bool _ownsNotificationService;
  final bool _notifyOnSyncSuccess;

  static const String _keyPendingReports = 'offline_pending_reports';
  static const String _keyCorruptedReportsBackup =
      'offline_pending_reports_corrupted_backup';

  static const int _localSchemaVersion = 2;

  static const Duration _prefsTimeout = Duration(seconds: 5);
  static const Duration _syncReportTimeout = Duration(seconds: 18);
  static const Duration _projectionTimeout = Duration(seconds: 8);
  static const Duration _notificationConfirmationTimeout = Duration(seconds: 8);

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _isSyncing = false;
  bool _isDisposed = false;

  // ==========================================
  // 🎧 Listen to connectivity changes
  // ==========================================

  void _initConnectivityListener() {
    _connectivitySubscription?.cancel();

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        if (_isDisposed) return;

        if (_hasConnection(results)) {
          debugPrint('🌐 OfflineSyncService: Internet connection restored');
          unawaited(syncPendingReports());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint(
          '❌ OfflineSyncService: Connectivity listener error - $error',
        );
        debugPrintStack(stackTrace: stackTrace);
      },
      cancelOnError: false,
    );
  }

  Future<void> _syncIfAlreadyOnline() async {
    try {
      final results = await _connectivity.checkConnectivity().timeout(
        const Duration(seconds: 4),
      );

      if (_hasConnection(results)) {
        unawaited(syncPendingReports());
      }
    } catch (e, stackTrace) {
      debugPrint(
        '⚠️ OfflineSyncService: Initial connectivity check failed - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // 💾 Save accident report locally
  // ==========================================

  Future<bool> saveReportLocally({
    required String uid,
    required double gForce,
    required String severity,
    required double lat,
    required double lng,
    double? rotation,
    double? severityScore,
    String? reason,
    String? source,
    bool? autoDetected,
    String? emergencySource,
    String? severityDisplay,
    String? locationName,
    String? eventId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final safeUserId = _trimToNull(uid);

      if (safeUserId == null) {
        debugPrint('❌ OfflineSyncService: Cannot save report without user id');
        return false;
      }

      if (!_isFiniteNumber(gForce) ||
          !_isFiniteNumber(rotation ?? 0.0) ||
          !_hasValidCoordinates(lat, lng)) {
        debugPrint(
          '❌ OfflineSyncService: Invalid report values; local save skipped',
        );
        return false;
      }

      final normalizedSeverity = AppThresholds.normalizeSeverityLevel(severity);

      final safeSource = _trimToNull(source) ?? 'mobile_offline';
      final resolvedEmergencySource = _deriveEmergencySource(
        explicitEmergencySource: emergencySource,
        source: safeSource,
        reason: reason,
        autoDetected: autoDetected,
      );

      final resolvedAutoDetected =
          autoDetected ?? resolvedEmergencySource != 'manual_sos';

      final safeSeverityScore = _safeScore(
        severityScore ?? _scoreFromSeverity(normalizedSeverity),
      );

      final now = DateTime.now();

      final report = <String, dynamic>{
        'localSchemaVersion': _localSchemaVersion,
        'offlineReportId':
            'offline_${now.microsecondsSinceEpoch}_${safeUserId.hashCode & 0x7fffffff}',
        'uid': safeUserId,
        'gForce': gForce,
        'rotation': rotation ?? 0.0,
        'severity': normalizedSeverity,
        'severityDisplay':
            _trimToNull(severityDisplay) ??
            AppThresholds.severityDisplayArabic(normalizedSeverity),
        'severityScore': safeSeverityScore,
        'lat': lat,
        'lng': lng,
        'locationName': _trimToNull(locationName),
        'reason': _trimToNull(reason) ?? 'offline_report',
        'source': safeSource,
        'emergencySource': resolvedEmergencySource,
        'alertSource': resolvedEmergencySource,
        'reportType': resolvedEmergencySource,
        'autoDetected': resolvedAutoDetected,
        'eventId': _trimToNull(eventId),
        'timestamp': now.toIso8601String(),
        'offlineSavedAt': now.toIso8601String(),
        'syncAttemptCount': 0,
        'additionalData': _jsonSafeMap(additionalData),
      };

      final prefs = await SharedPreferences.getInstance().timeout(
        _prefsTimeout,
      );

      final reports = await _readPendingReports(prefs);
      reports.add(_removeNullValues(report));

      final maxReports = AppThresholds.maxLocalAlertsCache;
      final trimmedReports = reports.length > maxReports
          ? reports.sublist(reports.length - maxReports)
          : reports;

      final success = await _writePendingReports(
        prefs,
        trimmedReports,
      ).timeout(_prefsTimeout);

      if (success) {
        debugPrint(
          '💾 OfflineSyncService: Report saved locally '
          '(${trimmedReports.length} pending, source=$resolvedEmergencySource)',
        );
      }

      return success;
    } on TimeoutException {
      debugPrint('⏱️ OfflineSyncService: Local save timeout');
      return false;
    } catch (e, stackTrace) {
      debugPrint('❌ OfflineSyncService: Failed to save report locally - $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  // ==========================================
  // 🔄 Sync pending reports to Firestore
  // ==========================================

  Future<void> syncPendingReports() async {
    if (_isDisposed) return;

    if (_isSyncing) {
      debugPrint('ℹ️ OfflineSyncService: Sync already in progress');
      return;
    }

    try {
      _isSyncing = true;

      final connectivityResults = await _connectivity
          .checkConnectivity()
          .timeout(const Duration(seconds: 4));

      if (!_hasConnection(connectivityResults)) {
        debugPrint('📴 OfflineSyncService: No internet, sync skipped');
        return;
      }

      final prefs = await SharedPreferences.getInstance().timeout(
        _prefsTimeout,
      );

      final reports = await _readPendingReports(prefs);

      if (reports.isEmpty) {
        debugPrint('✅ OfflineSyncService: No pending reports to sync');
        await prefs.remove(_keyPendingReports);
        return;
      }

      debugPrint(
        '🔄 OfflineSyncService: Starting sync of ${reports.length} pending reports',
      );

      var successCount = 0;
      var failCount = 0;
      var droppedInvalidCount = 0;

      final failedReports = <Map<String, dynamic>>[];

      for (final report in reports) {
        if (_isDisposed) return;

        final normalizedReport = _normalizeStoredReport(report);

        if (normalizedReport == null) {
          droppedInvalidCount++;
          debugPrint(
            '⚠️ OfflineSyncService: Dropping invalid local report after validation failure',
          );
          continue;
        }

        try {
          final synced = await _syncSingleReport(normalizedReport);

          if (synced) {
            successCount++;
          } else {
            failCount++;
            failedReports.add(_markSyncFailed(normalizedReport, 'sync_failed'));
          }
        } on TimeoutException {
          failCount++;
          failedReports.add(_markSyncFailed(normalizedReport, 'sync_timeout'));
          debugPrint('⏱️ OfflineSyncService: Report sync timeout');
        } catch (e, stackTrace) {
          failCount++;
          failedReports.add(_markSyncFailed(normalizedReport, e.toString()));
          debugPrint('❌ OfflineSyncService: Error syncing report - $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      final remainingReportsCount = failedReports.length;

      if (failedReports.isEmpty) {
        await prefs.remove(_keyPendingReports);

        debugPrint(
          '🎉 OfflineSyncService: No remaining pending reports '
          '(Synced: $successCount, Dropped invalid: $droppedInvalidCount, Total: ${reports.length})',
        );
      } else {
        await _writePendingReports(prefs, failedReports).timeout(_prefsTimeout);

        debugPrint(
          '⚠️ OfflineSyncService: Sync completed with remaining pending reports '
          '(Synced: $successCount, Failed: $failCount, Dropped invalid: $droppedInvalidCount, Remaining: $remainingReportsCount)',
        );
      }

      if (successCount > 0) {
        await _sendSyncSuccessConfirmation(
          syncedReportsCount: successCount,
          remainingReportsCount: remainingReportsCount,
        );
      }
    } on TimeoutException {
      debugPrint('⏱️ OfflineSyncService: Sync process timeout');
    } catch (e, stackTrace) {
      debugPrint('❌ OfflineSyncService: Sync process failed - $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _sendSyncSuccessConfirmation({
    required int syncedReportsCount,
    required int remainingReportsCount,
  }) async {
    if (_isDisposed) return;
    if (!_notifyOnSyncSuccess) return;
    if (syncedReportsCount <= 0) return;

    try {
      await _notificationService.initialize().timeout(
        _notificationConfirmationTimeout,
      );

      await _notificationService
          .sendOfflineSyncSuccessNotification(
            syncedReportsCount: syncedReportsCount,
            remainingReportsCount: remainingReportsCount,
          )
          .timeout(_notificationConfirmationTimeout);

      debugPrint(
        '✅ OfflineSyncService: Sync success confirmation notification requested '
        '(synced: $syncedReportsCount, remaining: $remainingReportsCount)',
      );
    } on TimeoutException {
      debugPrint(
        '⏱️ OfflineSyncService: Sync success confirmation notification timeout',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '⚠️ OfflineSyncService: Failed to request sync success notification - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<bool> _syncSingleReport(Map<String, dynamic> report) async {
    final userId = report['uid'] as String;
    final gForce = report['gForce'] as double;
    final rotation = report['rotation'] as double;
    final severityScore = report['severityScore'] as double;
    final severityLevel = report['severity'] as String;
    final severityDisplay = report['severityDisplay'] as String?;
    final latitude = report['lat'] as double;
    final longitude = report['lng'] as double;
    final reason = report['reason'] as String?;
    final locationName = report['locationName'] as String?;
    final source = report['source'] as String?;
    final emergencySource = report['emergencySource'] as String;
    final autoDetected = report['autoDetected'] as bool;
    final eventId = report['eventId'] as String?;
    final offlineReportId = report['offlineReportId'] as String?;
    final syncAttemptCount = report['syncAttemptCount'] as int? ?? 0;

    final additionalData = _jsonSafeMap(
      report['additionalData'] is Map
          ? Map<String, dynamic>.from(report['additionalData'] as Map)
          : const <String, dynamic>{},
    );

    final result = await _firebaseService
        .reportAccident(
          userId: userId,
          gForce: gForce,
          rotation: rotation,
          severityScore: severityScore,
          severityLevel: severityLevel,
          severityDisplay: severityDisplay,
          latitude: latitude,
          longitude: longitude,
          locationName: locationName,
          reason: reason,
          autoDetected: autoDetected,
          additionalData: {
            ...additionalData,
            'source': source ?? 'offline_sync',
            'emergencySource': emergencySource,
            'alertSource': emergencySource,
            'reportType': emergencySource,
            'wasOffline': true,
            'offlineReportId': offlineReportId,
            'offlineSavedAt': report['offlineSavedAt'],
            'offlineSyncedAt': DateTime.now().toIso8601String(),
            'syncAttemptCount': syncAttemptCount + 1,
            if (eventId != null) 'eventId': eventId,
          },
        )
        .timeout(_syncReportTimeout);

    if (!result.isSuccess || result.data == null) {
      debugPrint(
        '⚠️ OfflineSyncService: Firebase report failed - ${result.error}',
      );
      return false;
    }

    final accidentId = result.data!;

    await _createAlertProjectionBestEffort(
      accidentId: accidentId,
      userId: userId,
      gForce: gForce,
      rotation: rotation,
      severityScore: severityScore,
      rawSeverity: severityLevel,
      displaySeverity:
          severityDisplay ?? AppThresholds.severityDisplayArabic(severityLevel),
      detectionReason: reason ?? 'offline_sync',
      latitude: latitude,
      longitude: longitude,
      autoDetected: autoDetected,
      emergencySource: emergencySource,
      locationName: locationName,
      eventId: eventId,
    );

    debugPrint(
      '✅ OfflineSyncService: Report synced '
      '(accidentId=$accidentId, source=$emergencySource)',
    );

    return true;
  }

  Future<void> _createAlertProjectionBestEffort({
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
    required String emergencySource,
    String? locationName,
    String? eventId,
  }) async {
    try {
      final created = await _alertService
          .createAlertProjectionFromAccident(
            accidentId: accidentId,
            userId: userId,
            gForce: gForce,
            rotation: rotation,
            severityScore: severityScore,
            rawSeverity: rawSeverity,
            displaySeverity: displaySeverity,
            detectionReason: detectionReason,
            latitude: latitude,
            longitude: longitude,
            autoDetected: autoDetected,
            emergencySource: emergencySource,
            locationName: locationName,
            eventId: eventId,
          )
          .timeout(_projectionTimeout);

      if (created) {
        debugPrint(
          '✅ OfflineSyncService: Alert projection created for $accidentId',
        );
      } else {
        debugPrint(
          '⚠️ OfflineSyncService: Alert projection skipped/failed for $accidentId',
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        '⚠️ OfflineSyncService: Alert projection best-effort failed - $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  // ==========================================
  // 📊 Get pending reports count
  // ==========================================

  Future<int> getPendingReportsCount() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        _prefsTimeout,
      );

      final reports = await _readPendingReports(prefs);
      return reports.length;
    } catch (e, stackTrace) {
      debugPrint('❌ OfflineSyncService: Failed to get pending count - $e');
      debugPrintStack(stackTrace: stackTrace);
      return 0;
    }
  }

  // ==========================================
  // 🗑️ Clear all pending reports
  // ==========================================

  Future<bool> clearPendingReports() async {
    try {
      final prefs = await SharedPreferences.getInstance().timeout(
        _prefsTimeout,
      );

      return await prefs.remove(_keyPendingReports).timeout(_prefsTimeout);
    } catch (e, stackTrace) {
      debugPrint('❌ OfflineSyncService: Failed to clear pending reports - $e');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  // ==========================================
  // Internal storage helpers
  // ==========================================

  Future<List<Map<String, dynamic>>> _readPendingReports(
    SharedPreferences prefs,
  ) async {
    final reportsJson = prefs.getString(_keyPendingReports);

    if (reportsJson == null || reportsJson.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final decoded = jsonDecode(reportsJson);

      if (decoded is! List) {
        await prefs.setString(_keyCorruptedReportsBackup, reportsJson);
        await prefs.remove(_keyPendingReports);
        return <Map<String, dynamic>>[];
      }

      final reports = <Map<String, dynamic>>[];

      for (final item in decoded) {
        if (item is Map) {
          reports.add(
            item.map((key, dynamic value) => MapEntry(key.toString(), value)),
          );
        }
      }

      return reports;
    } catch (e, stackTrace) {
      debugPrint('❌ OfflineSyncService: Failed to parse reports - $e');
      debugPrintStack(stackTrace: stackTrace);

      await prefs.setString(_keyCorruptedReportsBackup, reportsJson);
      await prefs.remove(_keyPendingReports);

      return <Map<String, dynamic>>[];
    }
  }

  Future<bool> _writePendingReports(
    SharedPreferences prefs,
    List<Map<String, dynamic>> reports,
  ) {
    return prefs.setString(_keyPendingReports, jsonEncode(reports));
  }

  Map<String, dynamic>? _normalizeStoredReport(Map<String, dynamic> raw) {
    try {
      final userId = _trimToNull(raw['uid'] ?? raw['userId']);

      final gForce = _doubleValue(raw['gForce']);
      final rotation = _doubleValue(raw['rotation']) ?? 0.0;
      final severity = _trimToNull(raw['severity'] ?? raw['severityLevel']);
      final severityScore = _doubleValue(raw['severityScore']);
      final latitude = _doubleValue(raw['lat'] ?? raw['latitude']);
      final longitude = _doubleValue(raw['lng'] ?? raw['longitude']);

      if (userId == null ||
          gForce == null ||
          severity == null ||
          latitude == null ||
          longitude == null ||
          !_hasValidCoordinates(latitude, longitude)) {
        return null;
      }

      final normalizedSeverity = AppThresholds.normalizeSeverityLevel(severity);

      final source = _trimToNull(raw['source']) ?? 'offline_sync';

      final emergencySource = _deriveEmergencySource(
        explicitEmergencySource: _trimToNull(raw['emergencySource']),
        source: source,
        reason: _trimToNull(raw['reason']),
        autoDetected: _boolValue(raw['autoDetected']),
      );

      final autoDetected =
          _boolValue(raw['autoDetected']) ?? emergencySource != 'manual_sos';

      return _removeNullValues({
        'localSchemaVersion':
            _intValue(raw['localSchemaVersion']) ?? _localSchemaVersion,
        'offlineReportId':
            _trimToNull(raw['offlineReportId']) ??
            'offline_legacy_${DateTime.now().microsecondsSinceEpoch}',
        'uid': userId,
        'gForce': gForce,
        'rotation': rotation,
        'severity': normalizedSeverity,
        'severityDisplay':
            _trimToNull(raw['severityDisplay']) ??
            AppThresholds.severityDisplayArabic(normalizedSeverity),
        'severityScore': _safeScore(
          severityScore ?? _scoreFromSeverity(normalizedSeverity),
        ),
        'lat': latitude,
        'lng': longitude,
        'locationName': _trimToNull(raw['locationName']),
        'reason': _trimToNull(raw['reason']) ?? 'offline_sync',
        'source': source,
        'emergencySource': emergencySource,
        'alertSource': emergencySource,
        'reportType': emergencySource,
        'autoDetected': autoDetected,
        'eventId': _trimToNull(raw['eventId']),
        'timestamp':
            _trimToNull(raw['timestamp']) ?? DateTime.now().toIso8601String(),
        'offlineSavedAt':
            _trimToNull(raw['offlineSavedAt']) ??
            _trimToNull(raw['timestamp']) ??
            DateTime.now().toIso8601String(),
        'syncAttemptCount': _intValue(raw['syncAttemptCount']) ?? 0,
        'additionalData': _jsonSafeMap(
          raw['additionalData'] is Map
              ? Map<String, dynamic>.from(raw['additionalData'] as Map)
              : const <String, dynamic>{},
        ),
      });
    } catch (e, stackTrace) {
      debugPrint('⚠️ OfflineSyncService: Failed to normalize report - $e');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  Map<String, dynamic> _markSyncFailed(
    Map<String, dynamic> report,
    String error,
  ) {
    final attempts = _intValue(report['syncAttemptCount']) ?? 0;

    return {
      ...report,
      'syncAttemptCount': attempts + 1,
      'lastSyncError': error,
      'lastSyncFailedAt': DateTime.now().toIso8601String(),
    };
  }

  // ==========================================
  // Value helpers
  // ==========================================

  static bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  static String _deriveEmergencySource({
    String? explicitEmergencySource,
    String? source,
    String? reason,
    bool? autoDetected,
  }) {
    final explicit = _trimToNull(explicitEmergencySource)?.toLowerCase();

    if (explicit == 'manual_sos' || explicit == 'auto_detection') {
      return explicit!;
    }

    if (_containsManualSignal(source) || _containsManualSignal(reason)) {
      return 'manual_sos';
    }

    if (_containsAutoSignal(source) || _containsAutoSignal(reason)) {
      return 'auto_detection';
    }

    if (autoDetected != null) {
      return autoDetected ? 'auto_detection' : 'manual_sos';
    }

    return 'auto_detection';
  }

  static bool _containsManualSignal(String? value) {
    final normalized = value?.trim().toLowerCase();

    if (normalized == null || normalized.isEmpty) return false;

    return normalized.contains('manual') ||
        normalized.contains('sos') ||
        normalized.contains('استغاثة');
  }

  static bool _containsAutoSignal(String? value) {
    final normalized = value?.trim().toLowerCase();

    if (normalized == null || normalized.isEmpty) return false;

    return normalized.contains('auto') ||
        normalized.contains('detection') ||
        normalized.contains('sensor') ||
        normalized.contains('automatic');
  }

  static double _scoreFromSeverity(String severityLevel) {
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

  static double _safeScore(double value) {
    if (value.isNaN || value.isInfinite) return 0.0;
    return value.clamp(0.0, 100.0).toDouble();
  }

  static bool _isFiniteNumber(double value) {
    return !value.isNaN && !value.isInfinite;
  }

  static bool _hasValidCoordinates(double latitude, double longitude) {
    return _isFiniteNumber(latitude) &&
        _isFiniteNumber(longitude) &&
        latitude >= -90.0 &&
        latitude <= 90.0 &&
        longitude >= -180.0 &&
        longitude <= 180.0 &&
        !(latitude == 0.0 && longitude == 0.0);
  }

  static String? _trimToNull(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  static double? _doubleValue(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();

    if (value is String) {
      return double.tryParse(value.trim());
    }

    return null;
  }

  static int? _intValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();

    if (value is String) {
      return int.tryParse(value.trim());
    }

    return null;
  }

  static bool? _boolValue(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;

    if (value is num) return value != 0;

    if (value is String) {
      final normalized = value.trim().toLowerCase();

      if (['true', '1', 'yes', 'y'].contains(normalized)) return true;
      if (['false', '0', 'no', 'n'].contains(normalized)) return false;
    }

    return null;
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
      final safeList = value
          .map(_jsonSafeValue)
          .where((element) => element != null)
          .toList();

      return safeList;
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

  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    if (_ownsNotificationService) {
      await _notificationService.dispose();
    }

    debugPrint('🧹 OfflineSyncService: Disposed');
  }
}
