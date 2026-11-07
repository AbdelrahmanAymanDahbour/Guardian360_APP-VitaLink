import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/app_env.dart';
import '../../../core/constants/app_strings.dart';

class AIServiceException implements Exception {
  const AIServiceException(this.messageKey);

  final String messageKey;
}

/// Service layer for Guardian AI.
///
/// Security decision:
/// - The mobile app never calls Gemini / Vertex AI directly.
/// - The app calls a Firebase Callable Cloud Function.
/// - The Cloud Function owns Google Cloud / Vertex AI access and policy rules.
class AIService {
  static const int _requestTimeoutSeconds = 55;
  static const int _maxHistoryMessages = 8;
  static const int _maxHistoryMessageLength = 700;

  /// Keep this aligned with the Cloud Function validation limit.
  static const int _maxUserMessageLength = 1400;

  static String get _region => AppEnv.safeGuardianAiFunctionRegion;
  static String get _functionName => AppEnv.safeGuardianAiFunctionName;

  final FirebaseFunctions _functions;

  AIService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instanceFor(region: _region);

  Future<String> sendMessage(
    String message, {
    List<Map<String, String>> history = const [],
    required String locale,
  }) async {
    final safeMessage = _sanitizeUserMessage(message);

    if (safeMessage.isEmpty) {
      throw const AIServiceException(AppStrings.aiWriteQuestion);
    }

    if (safeMessage.length > _maxUserMessageLength) {
      throw const AIServiceException(AppStrings.aiInvalidQuestion);
    }

    try {
      final callable = _functions.httpsCallable(
        _functionName,
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: _requestTimeoutSeconds),
        ),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'message': safeMessage,
        'locale': _sanitizeLocale(locale),
        'history': _sanitizeHistory(history),
      });

      final reply = _extractReply(result.data);

      if (reply.isEmpty) {
        throw const AIServiceException(AppStrings.aiNoSuitableReply);
      }

      return reply;
    } on FirebaseFunctionsException catch (error, stackTrace) {
      _logFirebaseFunctionError(error, stackTrace);
      throw AIServiceException(_messageForFunctionError(error.code));
    } on AIServiceException {
      rethrow;
    } catch (error, stackTrace) {
      _logUnexpectedError(error, stackTrace);
      throw const AIServiceException(AppStrings.aiUnexpectedError);
    }
  }

  String _sanitizeUserMessage(String value) {
    return _normalizeText(value);
  }

  String _sanitizeLocale(String value) {
    final locale = value.trim().toLowerCase();

    if (locale.startsWith('en')) return 'en';
    if (locale.startsWith('ar')) return 'ar';

    return 'en';
  }

  String _extractReply(Map<String, dynamic> data) {
    final reply = data['reply'];

    if (reply is! String) return '';

    return _cleanAiReply(reply);
  }

  /// Flutter should not aggressively rewrite the AI response.
  ///
  /// The Cloud Function already applies the main safety and formatting policy.
  /// This method only performs a final defensive cleanup for UI display:
  /// - normalize line endings
  /// - remove leftover markdown/code artifacts
  /// - preserve useful bullets
  /// - remove possible prompt leakage
  /// - replace unverified emergency numbers
  String _cleanAiReply(String value) {
    var text = _normalizeLineEndings(value);

    text = _removePromptLeakage(text);
    text = _removeCodeBlocks(text);
    text = _stripSimpleMarkdown(text);
    text = _normalizeBullets(text);
    text = _normalizeDisplaySpacing(text);
    return text.trim();
  }

  String _normalizeText(String value) {
    return _normalizeLineEndings(value)
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _normalizeLineEndings(String value) {
    return value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  String _removeCodeBlocks(String value) {
    return value.replaceAll(RegExp(r'```[\s\S]*?```'), '').trim();
  }

  String _stripSimpleMarkdown(String value) {
    var text = value;

    text = text.replaceAll(RegExp(r'^\s*#{1,6}\s*', multiLine: true), '');

    text = text.replaceAllMapped(
      RegExp(r'\*\*([^*\n]+)\*\*'),
      (match) => match.group(1) ?? '',
    );

    text = text.replaceAllMapped(
      RegExp(r'\*([^*\n]+)\*'),
      (match) => match.group(1) ?? '',
    );

    text = text.replaceAllMapped(
      RegExp(r'`([^`\n]+)`'),
      (match) => match.group(1) ?? '',
    );

    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (match) => match.group(1) ?? '',
    );

    return text.replaceAll(RegExp(r'[_~]'), '').trim();
  }

  String _normalizeBullets(String value) {
    return value
        .replaceAll(RegExp(r'^\s*[-]\s+', multiLine: true), '• ')
        .replaceAll(RegExp(r'^\s*[•]\s*', multiLine: true), '• ')
        .trim();
  }

  String _normalizeDisplaySpacing(String value) {
    return value
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .replaceAll(RegExp(r'\n[ \t]+'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _removePromptLeakage(String value) {
    var text = value;

    final blockedPatterns = <RegExp>[
      RegExp(r'سياق تشغيلي من Guardian360\.?', caseSensitive: false),
      RegExp(r'تقدير الخطورة:.*$', multiLine: true),
      RegExp(r'الموضوع المتوقع:.*$', multiLine: true),
      RegExp(r'نمط الرد الموصى به:.*$', multiLine: true),
      RegExp(r'طلب SOS صريح:.*$', multiLine: true),
      RegExp(r'اسأل سؤالاً توضيحياً واحداً فقط:.*$', multiLine: true),
      RegExp(r'رسالة المستخدم:', caseSensitive: false),
      RegExp(r'Operational context from Guardian360\.?', caseSensitive: false),
      RegExp(r'Estimated urgency:.*$', multiLine: true),
      RegExp(r'Estimated topic:.*$', multiLine: true),
      RegExp(r'Recommended response mode:.*$', multiLine: true),
      RegExp(r'Explicit SOS request:.*$', multiLine: true),
      RegExp(r'Ask one clarifying question only:.*$', multiLine: true),
      RegExp(r'User message:', caseSensitive: false),
    ];

    for (final pattern in blockedPatterns) {
      text = text.replaceAll(pattern, '');
    }

    return text.trim();
  }

  List<Map<String, String>> _sanitizeHistory(
    List<Map<String, String>> history,
  ) {
    final cleaned = <Map<String, String>>[];

    for (final item in history) {
      final role = _sanitizeHistoryRole(item['role']);
      final text = _sanitizeHistoryText(item['text']);

      if (role == null || text.isEmpty) continue;

      cleaned.add({'role': role, 'text': text});
    }

    if (cleaned.length <= _maxHistoryMessages) return cleaned;

    return cleaned.sublist(cleaned.length - _maxHistoryMessages);
  }

  String? _sanitizeHistoryRole(String? value) {
    final role = value?.trim();

    if (role == 'user') return 'user';
    if (role == 'ai') return 'ai';

    return null;
  }

  String _sanitizeHistoryText(String? value) {
    final normalized = _normalizeText(value ?? '');

    if (normalized.length <= _maxHistoryMessageLength) {
      return normalized;
    }

    return normalized.substring(0, _maxHistoryMessageLength).trim();
  }

  String _messageForFunctionError(String code) {
    switch (code) {
      case 'unauthenticated':
        return AppStrings.aiLoginRequired;

      case 'invalid-argument':
        return AppStrings.aiInvalidQuestion;

      case 'resource-exhausted':
        return AppStrings.aiTooManyRequests;

      case 'failed-precondition':
      case 'not-found':
      case 'unavailable':
        return AppStrings.aiServerNotReady;

      case 'deadline-exceeded':
      case 'cancelled':
      case 'internal':
      case 'permission-denied':
      default:
        return AppStrings.aiSecureServerError;
    }
  }

  void _logFirebaseFunctionError(
    FirebaseFunctionsException error,
    StackTrace stackTrace,
  ) {
    if (!kDebugMode) return;

    debugPrint('Guardian AI Function Error: [${error.code}] ${error.message}');
    debugPrintStack(stackTrace: stackTrace);
  }

  void _logUnexpectedError(Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;

    debugPrint('Guardian AI Unexpected Error: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
