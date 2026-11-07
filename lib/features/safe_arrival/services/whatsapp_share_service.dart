import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/safe_arrival_trip_model.dart';

/// ==========================================
/// 📱 WhatsApp Share Service
/// ==========================================
/// Responsible for opening WhatsApp with a prepared Safe Arrival message.
///
/// Important:
/// - This service does NOT silently send messages.
/// - WhatsApp opens with a prefilled message and the user confirms sending.
/// - This service does NOT write Firestore.
/// - Firestore updates should be handled by SafeArrivalRepository after launch.
class WhatsAppShareService {
  const WhatsAppShareService();

  /// Opens WhatsApp with a prefilled message.
  ///
  /// If [phoneNumber] is valid, it opens a direct chat.
  /// If [phoneNumber] is missing or direct launch fails, it opens a text-only
  /// WhatsApp share URL.
  Future<WhatsAppShareResult<void>> openPreparedMessage({
    required String message,
    String? phoneNumber,
  }) async {
    try {
      final safeMessage = _cleanMessage(message);

      if (safeMessage.isEmpty) {
        return WhatsAppShareResult.failure(
          const WhatsAppShareException(
            message: 'WhatsApp message is required',
            code: 'invalid-message',
          ),
        );
      }

      final normalizedPhone = normalizePhoneForWhatsApp(phoneNumber);

      final primaryUri = buildWhatsAppUri(
        message: safeMessage,
        normalizedPhone: normalizedPhone,
      );

      final primaryLaunched = await _launch(primaryUri);

      if (primaryLaunched) {
        debugPrint('📱 WhatsAppShareService: WhatsApp opened successfully');
        return WhatsAppShareResult.success(null);
      }

      if (normalizedPhone != null) {
        final fallbackUri = buildWhatsAppUri(message: safeMessage);
        final fallbackLaunched = await _launch(fallbackUri);

        if (fallbackLaunched) {
          debugPrint(
            '📱 WhatsAppShareService: WhatsApp opened using text fallback',
          );
          return WhatsAppShareResult.success(null);
        }
      }

      return WhatsAppShareResult.failure(
        const WhatsAppShareException(
          message: 'WhatsApp could not be opened on this device',
          code: 'whatsapp-launch-failed',
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ WhatsAppShareService: Failed to open WhatsApp - $e');
      debugPrintStack(stackTrace: stackTrace);

      return WhatsAppShareResult.failure(
        WhatsAppShareException(
          message: 'Unexpected WhatsApp launch error',
          code: 'whatsapp-launch-exception',
          originalError: e,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// Builds a compact, family-friendly Guardian 360 Safe Arrival message.
  ///
  /// مهم:
  /// - لا نضع تقرير Guardian الطويل داخل WhatsApp.
  /// - الرسالة هدفها الطمأنة السريعة، وليست تقريرًا تحليليًا كاملًا.
  /// - تفاصيل التحليل تبقى داخل التطبيق.
  String buildArrivalMessage({
    required SafeArrivalTripModel trip,
    String? userName,
  }) {
    final destination = trip.destination;

    final safeUserName = _cleanInlineText(userName ?? '');
    final arrivedAt = trip.arrivedAt ?? trip.manualFinishedAt ?? DateTime.now();

    final destinationName = _cleanInlineText(destination?.displayName ?? '');

    final destinationAddress = _cleanInlineText(
      destination?.displayAddress ?? '',
    );

    final elapsedText = _formatElapsedSeconds(trip.elapsedSeconds);
    final distanceText = _formatDistanceMeters(trip.actualDistanceMeters);
    final locationUrl = _resolveBestLocationUrl(trip);

    final buffer = StringBuffer();

    buffer.writeln('✅ وصلت بأمان');
    buffer.writeln();
    buffer.writeln('اطمئنوا، تم تأكيد وصولي بسلام عبر Guardian 360.');

    if (safeUserName.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('👤 الاسم: $safeUserName');
    }

    if (destinationName.isNotEmpty) {
      buffer.writeln('📍 الوجهة: $destinationName');
    }

    if (destinationAddress.isNotEmpty &&
        destinationAddress != destinationName) {
      buffer.writeln('🧭 العنوان: $destinationAddress');
    }

    buffer.writeln('🕒 وقت الوصول: ${_formatDateTime(arrivedAt)}');

    if (elapsedText.isNotEmpty) {
      buffer.writeln('⏱️ مدة الرحلة: $elapsedText');
    }

    if (distanceText.isNotEmpty) {
      buffer.writeln('📏 المسافة: $distanceText');
    }

    if (locationUrl.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('🔗 موقعي:');
      buffer.writeln(locationUrl);
    }

    buffer.writeln();
    buffer.writeln('🛡️ Guardian 360');

    return _cleanMessage(buffer.toString());
  }

  /// Builds a WhatsApp URI using wa.me.
  ///
  /// [normalizedPhone] must be digits only without '+'.
  Uri buildWhatsAppUri({required String message, String? normalizedPhone}) {
    final safeMessage = _cleanMessage(message);
    final safePhone = _cleanInlineText(normalizedPhone ?? '');

    final path = safePhone.isEmpty ? '/' : '/$safePhone';

    return Uri.https('wa.me', path, <String, String>{'text': safeMessage});
  }

  /// Normalizes phone numbers for wa.me.
  ///
  /// Returns digits only, without '+'.
  /// Supports:
  /// - +9627XXXXXXXX
  /// - 009627XXXXXXXX
  /// - 9627XXXXXXXX
  /// - 07XXXXXXXX for Jordanian mobile numbers
  String? normalizePhoneForWhatsApp(String? input) {
    final raw = _cleanInlineText(input ?? '');

    if (raw.isEmpty) return null;

    var phone = _normalizeArabicDigits(raw);

    phone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    phone = phone.replaceAll(RegExp(r'[^0-9+]'), '');

    if (phone.startsWith('00')) {
      phone = phone.substring(2);
    }

    if (phone.startsWith('+')) {
      phone = phone.substring(1);
    }

    if (RegExp(r'^07[789]\d{7}$').hasMatch(phone)) {
      phone = '962${phone.substring(1)}';
    }

    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.length < 8 || digitsOnly.length > 15) {
      return null;
    }

    return digitsOnly;
  }

  Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('⚠️ WhatsAppShareService: launch failed for $uri - $e');
      return false;
    }
  }

  String _resolveBestLocationUrl(SafeArrivalTripModel trip) {
    if (_hasValidCoordinates(trip.endLatitude, trip.endLongitude)) {
      return _googleMapsUrl(trip.endLatitude!, trip.endLongitude!);
    }

    if (_hasValidCoordinates(trip.currentLatitude, trip.currentLongitude)) {
      return _googleMapsUrl(trip.currentLatitude!, trip.currentLongitude!);
    }

    final destinationUrl = trip.destination?.googleMapsUrl ?? '';
    if (destinationUrl.trim().isNotEmpty) {
      return destinationUrl.trim();
    }

    return '';
  }

  String _googleMapsUrl(double latitude, double longitude) {
    final uri = Uri.https('www.google.com', '/maps/search/', <String, String>{
      'api': '1',
      'query': '$latitude,$longitude',
    });

    return uri.toString();
  }

  bool _hasValidCoordinates(double? latitude, double? longitude) {
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

  String _formatDateTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();

    return '$hour:$minute - $day/$month/$year';
  }

  String _formatElapsedSeconds(int? seconds) {
    if (seconds == null || seconds < 0) return '';

    if (seconds < 60) {
      return 'أقل من دقيقة';
    }

    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    if (hours > 0 && minutes > 0) {
      return '$hours ساعة و $minutes دقيقة';
    }

    if (hours > 0) {
      return '$hours ساعة';
    }

    return '$minutes دقيقة';
  }

  String _formatDistanceMeters(double meters) {
    if (meters.isNaN || meters.isInfinite || meters <= 0.0) {
      return '';
    }

    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} م';
    }

    return '${(meters / 1000).toStringAsFixed(2)} كم';
  }

  String _cleanInlineText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _cleanMessage(String value) {
    final normalized = value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (normalized.isEmpty) return '';

    final lines = normalized
        .split('\n')
        .map(_cleanInlineText)
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

  String _normalizeArabicDigits(String value) {
    const arabicIndic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const easternArabicIndic = [
      '۰',
      '۱',
      '۲',
      '۳',
      '۴',
      '۵',
      '۶',
      '۷',
      '۸',
      '۹',
    ];
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    var result = value;

    for (var i = 0; i < englishDigits.length; i++) {
      result = result.replaceAll(arabicIndic[i], englishDigits[i]);
      result = result.replaceAll(easternArabicIndic[i], englishDigits[i]);
    }

    return result;
  }
}

/// ==========================================
/// 📦 WhatsApp Share Result
/// ==========================================
class WhatsAppShareResult<T> {
  final T? data;
  final WhatsAppShareException? error;
  final bool isSuccess;

  const WhatsAppShareResult._({this.data, this.error, required this.isSuccess});

  factory WhatsAppShareResult.success(T? data) {
    return WhatsAppShareResult._(data: data, isSuccess: true);
  }

  factory WhatsAppShareResult.failure(WhatsAppShareException error) {
    return WhatsAppShareResult._(error: error, isSuccess: false);
  }

  bool get isFailure => !isSuccess;
}

/// ==========================================
/// ⚠️ WhatsApp Share Exception
/// ==========================================
class WhatsAppShareException {
  final String message;
  final String code;
  final Object? originalError;
  final StackTrace? stackTrace;

  const WhatsAppShareException({
    required this.message,
    required this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'WhatsAppShareException(code: $code, message: $message)';
  }
}
