import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// ==========================================
/// 🔐 Permission Manager Service
/// ==========================================
/// إدارة صلاحيات التطبيق بطريقة احترافية
class PermissionManager {
  /// ==========================================
  /// 📍 Request Location Permission
  /// ==========================================
  static Future<bool> requestLocationPermission() async {
    try {
      final status = await Permission.location.request();

      if (status.isGranted) {
        debugPrint('✅ PermissionManager: Location permission granted');
        return true;
      } else if (status.isPermanentlyDenied) {
        debugPrint(
          '⚠️ PermissionManager: Location permission permanently denied',
        );
        await openAppSettings();
        return false;
      } else {
        debugPrint('❌ PermissionManager: Location permission denied');
        return false;
      }
    } catch (e) {
      debugPrint('❌ PermissionManager: Location permission error - $e');
      return false;
    }
  }

  /// ==========================================
  /// 📍 Request Background Location Permission
  /// ==========================================
  static Future<bool> requestBackgroundLocationPermission() async {
    try {
      // First ensure foreground location is granted
      final foregroundStatus = await Permission.location.status;
      if (!foregroundStatus.isGranted) {
        final granted = await requestLocationPermission();
        if (!granted) return false;
      }

      // Then request background location
      final status = await Permission.locationAlways.request();

      if (status.isGranted) {
        debugPrint(
          '✅ PermissionManager: Background location permission granted',
        );
        return true;
      } else if (status.isPermanentlyDenied) {
        debugPrint(
          '⚠️ PermissionManager: Background location permanently denied',
        );
        await openAppSettings();
        return false;
      } else {
        debugPrint('❌ PermissionManager: Background location denied');
        return false;
      }
    } catch (e) {
      debugPrint('❌ PermissionManager: Background location error - $e');
      return false;
    }
  }

  /// ==========================================
  /// 🔔 Request Notification Permission
  /// ==========================================
  static Future<bool> requestNotificationPermission() async {
    try {
      final status = await Permission.notification.request();

      if (status.isGranted) {
        debugPrint('✅ PermissionManager: Notification permission granted');
        return true;
      } else if (status.isPermanentlyDenied) {
        debugPrint(
          '⚠️ PermissionManager: Notification permission permanently denied',
        );
        await openAppSettings();
        return false;
      } else {
        debugPrint('❌ PermissionManager: Notification permission denied');
        return false;
      }
    } catch (e) {
      debugPrint('❌ PermissionManager: Notification permission error - $e');
      return false;
    }
  }

  /// ==========================================
  /// 🚨 Request Critical Alert Permission (iOS)
  /// ==========================================
  static Future<bool> requestCriticalAlertPermission() async {
    try {
      final status = await Permission.criticalAlerts.request();

      if (status.isGranted) {
        debugPrint('✅ PermissionManager: Critical alerts permission granted');
        return true;
      } else {
        debugPrint('⚠️ PermissionManager: Critical alerts permission denied');
        return false;
      }
    } catch (e) {
      debugPrint('❌ PermissionManager: Critical alerts permission error - $e');
      return false;
    }
  }

  /// ==========================================
  /// 🔋 Request Ignore Battery Optimization
  /// ==========================================
  static Future<bool> requestIgnoreBatteryOptimization() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.request();

      if (status.isGranted) {
        debugPrint('✅ PermissionManager: Battery optimization ignored');
        return true;
      } else {
        debugPrint('⚠️ PermissionManager: Battery optimization not ignored');
        return false;
      }
    } catch (e) {
      debugPrint('❌ PermissionManager: Battery optimization error - $e');
      return false;
    }
  }

  /// ==========================================
  /// 📞 Request Phone Permission
  /// ==========================================
  static Future<bool> requestPhonePermission() async {
    try {
      final status = await Permission.phone.request();

      if (status.isGranted) {
        debugPrint('✅ PermissionManager: Phone permission granted');
        return true;
      } else {
        debugPrint('⚠️ PermissionManager: Phone permission denied');
        return false;
      }
    } catch (e) {
      debugPrint('❌ PermissionManager: Phone permission error - $e');
      return false;
    }
  }

  /// ==========================================
  /// 📱 Request SMS Permission
  /// ==========================================
  static Future<bool> requestSmsPermission() async {
    try {
      final status = await Permission.sms.request();

      if (status.isGranted) {
        debugPrint('✅ PermissionManager: SMS permission granted');
        return true;
      } else {
        debugPrint('⚠️ PermissionManager: SMS permission denied');
        return false;
      }
    } catch (e) {
      debugPrint('❌ PermissionManager: SMS permission error - $e');
      return false;
    }
  }

  /// ==========================================
  /// ✅ Check if all critical permissions are granted
  /// ==========================================
  static Future<bool> areAllCriticalPermissionsGranted() async {
    try {
      final location = await Permission.location.isGranted;
      final notification = await Permission.notification.isGranted;

      return location && notification;
    } catch (e) {
      debugPrint('❌ PermissionManager: Check permissions error - $e');
      return false;
    }
  }

  /// ==========================================
  /// 🎯 Request all essential permissions
  /// ==========================================
  static Future<Map<String, bool>> requestAllEssentialPermissions() async {
    final results = <String, bool>{};

    results['location'] = await requestLocationPermission();
    results['backgroundLocation'] = await requestBackgroundLocationPermission();
    results['notification'] = await requestNotificationPermission();
    results['criticalAlerts'] = await requestCriticalAlertPermission();
    results['batteryOptimization'] = await requestIgnoreBatteryOptimization();

    debugPrint('📊 PermissionManager: All permissions requested - $results');
    return results;
  }

  /// ==========================================
  /// 📋 Get permission status summary
  /// ==========================================
  static Future<Map<String, PermissionStatus>>
  getPermissionStatusSummary() async {
    return {
      'location': await Permission.location.status,
      'backgroundLocation': await Permission.locationAlways.status,
      'notification': await Permission.notification.status,
      'criticalAlerts': await Permission.criticalAlerts.status,
      'batteryOptimization': await Permission.ignoreBatteryOptimizations.status,
      'phone': await Permission.phone.status,
      'sms': await Permission.sms.status,
    };
  }
}
