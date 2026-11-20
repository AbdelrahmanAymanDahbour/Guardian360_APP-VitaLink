import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/constants/app_strings.dart';
import '../models/ai_chat_message.dart';
import '../services/ai_service.dart';

enum VoiceToneSignal { idle, low, clear, elevated }

class AIChatViewModel extends ChangeNotifier {
  AIChatViewModel({
    AIService? aiService,
    FlutterTts? flutterTts,
    stt.SpeechToText? speechToText,
  }) : _aiService = aiService ?? AIService(),
       _tts = flutterTts ?? FlutterTts(),
       _speechToText = speechToText ?? stt.SpeechToText();

  final AIService _aiService;
  final FlutterTts _tts;
  final stt.SpeechToText _speechToText;

  final List<AiChatMessage> messages = [];

  static const int _maxHistoryMessages = 8;
  static const int _voiceSafetyTimeoutSeconds = 18;
  static const int _voiceListenSeconds = 15;
  static const int _voicePauseSeconds = 3;

  static const double _elevatedVoiceLevel = 13;
  static const double _clearVoiceLevel = 6;
  static const double _lowVoiceLevel = 0.1;
  static const double _soundLevelNotifyThreshold = 1.5;

  // Explicit imperative emergency commands.
  // REMOVED: bare 'انقذني', 'انقذوني', bare 'sos' — too short and appear in
  // casual or informational sentences (see negation/disqualifier lists below).
  static const List<String> _explicitEmergencyPhrases = [
    // Arabic explicit imperatives
    'شغل الطوارئ',
    'افتح الطوارئ',
    'ابدأ الطوارئ',
    'فعل الطوارئ',
    'فعّل الطوارئ',
    'استدعاء الاسعاف',
    'استدعاء الإسعاف',
    'استدعي الاسعاف',
    'استدعي الإسعاف',
    'اتصل بالاسعاف',
    'اتصل بالإسعاف',
    'اتصل بالطوارئ',
    'ساعدوني فوراً',
    'ساعدني فوراً',
    'ابدأ sos',
    'شغّل sos',
    'افتح sos',
    // English explicit imperatives
    'start emergency',
    'open emergency',
    'activate emergency',
    'trigger emergency',
    'call emergency',
    'start sos',
    'activate sos',
    'open sos',
    'call sos',
  ];

  // If any of these tokens appear in the user's message the emergency check
  // is rejected immediately — the user is negating, not commanding.
  static const List<String> _emergencyNegationTokens = [
    // Arabic compound negations (more specific — checked first)
    'لا تفتح',
    'لا تشغل',
    'لا تبدأ',
    'لا تستدعي',
    'لا تتصل',
    'لست في خطر',
    'لست بخطر',
    'ليس طارئ',
    'لا أحتاج',
    // Arabic standalone negation words
    'لست',
    'ليس',
    // English negations
    "don't",
    'do not',
    "i'm not",
    'im not',
    'not in danger',
    'not an emergency',
  ];

  // If any of these tokens appear in the user's message the emergency check
  // is rejected — the user is asking an informational question, not commanding.
  static const List<String> _emergencyContextDisqualifiers = [
    // Arabic informational question markers
    'ما هو',
    'ما هي',
    'ما معنى',
    'كيف يعمل',
    'كيف تعمل',
    'من الملل',
    'بسبب الملل',
    // English informational question markers
    'what is',
    'what does',
    'what are',
    'what mean',
    'how does',
    'how do',
    'how to',
    'tell me about',
  ];

  bool isLoading = false;
  bool isListening = false;
  bool isSpeaking = false;

  bool _ttsConfigured = false;
  String? _configuredTtsLanguage;
  bool _sosNavigationRequested = false;
  bool _disposed = false;

  bool _speechInitialized = false;
  bool _speechAvailable = false;
  bool _voiceNoSpeechMessageShown = false;

  String _currentVoiceText = '';
  String? _pendingVoiceText;
  String? _voiceStatusMessage;
  String? _speakingText;

  double _currentSoundLevel = 0;
  double _peakSoundLevel = 0;

  Completer<String?>? _voiceCompleter;
  Timer? _voiceSafetyTimer;

  bool get hasMessages => messages.isNotEmpty;
  bool get canSendMessage => !isLoading && !isListening;
  bool get canUseVoiceInput => !isLoading;

  String get currentVoiceText => _currentVoiceText;
  double get currentSoundLevel => _currentSoundLevel;
  double get peakSoundLevel => _peakSoundLevel;
  String? get voiceStatusMessage => _voiceStatusMessage;

  bool get hasPendingVoiceText {
    final text = _pendingVoiceText?.trim();
    return text != null && text.isNotEmpty;
  }

  VoiceToneSignal get voiceToneSignal {
    if (!isListening) return VoiceToneSignal.idle;

    final level = _currentSoundLevel.abs();

    if (level >= _elevatedVoiceLevel) return VoiceToneSignal.elevated;
    if (level >= _clearVoiceLevel) return VoiceToneSignal.clear;
    if (level > _lowVoiceLevel) return VoiceToneSignal.low;

    return VoiceToneSignal.idle;
  }

  String get voiceToneLabelKey {
    switch (voiceToneSignal) {
      case VoiceToneSignal.elevated:
        return AppStrings.aiVoiceToneElevated;
      case VoiceToneSignal.clear:
        return AppStrings.aiVoiceToneClear;
      case VoiceToneSignal.low:
        return AppStrings.aiVoiceToneLow;
      case VoiceToneSignal.idle:
        return AppStrings.aiVoiceToneIdle;
    }
  }

  bool get isVoiceSignalElevated {
    return voiceToneSignal == VoiceToneSignal.elevated;
  }

  bool isSpeakingText(String text) {
    final safeText = text.trim();
    if (safeText.isEmpty) return false;

    return isSpeaking && _speakingText == safeText;
  }

  String? consumePendingVoiceText() {
    final text = _pendingVoiceText?.trim();
    _pendingVoiceText = null;

    if (text == null || text.isEmpty) return null;
    return text;
  }

  Future<void> sendMessage(String text, {required String locale}) async {
    final userText = text.trim();
    if (userText.isEmpty || isLoading) return;

    await stopSpeaking();

    final history = _historyForRequest();

    messages.add(AiChatMessage(role: AiChatRole.user, text: userText));
    isLoading = true;
    _safeNotifyListeners();

    if (_isExplicitEmergencyCommand(userText)) {
      _requestEmergencySOS();
      return;
    }

    try {
      final response = await _aiService.sendMessage(
        userText,
        history: history,
        locale: locale,
      );

      messages.add(AiChatMessage(role: AiChatRole.ai, text: response));
    } on AIServiceException catch (error) {
      messages.add(
        AiChatMessage(
          role: AiChatRole.ai,
          text: error.messageKey,
          isLocalizationKey: true,
        ),
      );
    } catch (_) {
      messages.add(
        AiChatMessage(
          role: AiChatRole.ai,
          text: AppStrings.aiError,
          isLocalizationKey: true,
        ),
      );
    } finally {
      isLoading = false;
      _safeNotifyListeners();
    }
  }

  // ── Emergency intent classifier helpers ──────────────────────────────────

  /// Normalises user text for emergency-intent comparison:
  /// lowercased, punctuation stripped, whitespace collapsed.
  String _normalizeEmergencyText(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[!؟?،,.؛;:()\[\]{}"\x27]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Returns true when the message contains a negation phrase or an
  /// informational-question marker — meaning it is NOT an emergency command
  /// even if it contains emergency-related words.
  bool _hasEmergencyNegationOrDisqualifier(String normalized) {
    for (final token in _emergencyNegationTokens) {
      if (normalized.contains(token)) return true;
    }
    for (final token in _emergencyContextDisqualifiers) {
      if (normalized.contains(token)) return true;
    }
    return false;
  }

  /// Returns true when [phrase] appears in [normalized] at a phrase boundary.
  /// Padding both sides with a space and then searching for ` phrase ` means
  /// the phrase must be a complete token sequence — not a partial substring
  /// inside a longer word or sentence segment.
  bool _matchesEmergencyPhrase(String normalized, String phrase) {
    return (' $normalized ').contains(' $phrase ');
  }

  /// Entry point used by [sendMessage].
  /// Returns true only when the message is an unambiguous, non-negated
  /// explicit emergency command phrase.
  bool _isExplicitEmergencyCommand(String text) {
    final normalized = _normalizeEmergencyText(text);

    // Step 1 — reject if negation or informational context is detected.
    if (_hasEmergencyNegationOrDisqualifier(normalized)) return false;

    // Step 2 — require a complete explicit command phrase (phrase-boundary).
    return _explicitEmergencyPhrases.any(
      (phrase) => _matchesEmergencyPhrase(normalized, phrase),
    );
  }

  void _requestEmergencySOS() {
    messages.add(
      AiChatMessage(
        role: AiChatRole.ai,
        text: AppStrings.aiEmergencyExplicitDetected,
        isLocalizationKey: true,
      ),
    );

    isLoading = false;
    _sosNavigationRequested = true;
    _safeNotifyListeners();
  }

  bool consumeSosNavigationRequest() {
    if (!_sosNavigationRequested) return false;

    _sosNavigationRequested = false;
    return true;
  }

  Future<String?> startVoiceInput({required String locale}) async {
    if (isLoading) return null;

    if (isListening) {
      return stopVoiceInput();
    }

    await stopSpeaking();

    final microphoneAllowed = await _ensureMicrophonePermission();
    if (!microphoneAllowed) {
      _showVoiceUnavailableMessage(
        AppStrings.aiVoiceMicrophonePermissionDenied,
        isLocalizationKey: true,
      );
      return null;
    }

    final speechReady = await _ensureSpeechReady();
    if (!speechReady) {
      _showVoiceUnavailableMessage(
        AppStrings.aiVoiceUnavailable,
        isLocalizationKey: true,
      );
      return null;
    }

    _resetVoiceSession();

    final localeId = await _resolveBestLocale(_speechLocaleFor(locale));

    isListening = true;
    _voiceStatusMessage = AppStrings.aiListening;
    _safeNotifyListeners();

    final completer = Completer<String?>();
    _voiceCompleter = completer;

    _voiceSafetyTimer = Timer(
      const Duration(seconds: _voiceSafetyTimeoutSeconds),
      () {
        _completeVoiceInput(_currentVoiceText, showNoSpeechMessage: true);
      },
    );

    try {
      await _speechToText.listen(
        localeId: localeId,
        listenFor: const Duration(seconds: _voiceListenSeconds),
        pauseFor: const Duration(seconds: _voicePauseSeconds),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: true,
        ),
        onSoundLevelChange: _handleSoundLevelChange,
        onResult: (result) {
          final recognized = result.recognizedWords.trim();

          if (recognized.isNotEmpty) {
            _currentVoiceText = recognized;
            _voiceStatusMessage = recognized;
            _safeNotifyListeners();
          }

          if (result.finalResult) {
            _completeVoiceInput(_currentVoiceText, showNoSpeechMessage: true);
          }
        },
      );

      return completer.future;
    } catch (_) {
      _completeVoiceInput(null, showNoSpeechMessage: false);
      _showVoiceUnavailableMessage(
        AppStrings.aiVoiceStartFailed,
        isLocalizationKey: true,
      );
      return null;
    }
  }

  Future<String?> handleVoiceInputUnavailable({required String locale}) {
    return startVoiceInput(locale: locale);
  }

  Future<String?> stopVoiceInput() async {
    if (!isListening) {
      return consumePendingVoiceText();
    }

    final text = _currentVoiceText.trim();

    try {
      await _speechToText.stop();
    } catch (_) {
      // Native speech service may already be stopped.
    }

    _completeVoiceInput(text, showNoSpeechMessage: true);
    return consumePendingVoiceText();
  }

  Future<bool> _ensureMicrophonePermission() async {
    final status = await Permission.microphone.status;

    if (status.isGranted) return true;

    if (status.isPermanentlyDenied || status.isRestricted) {
      return false;
    }

    final requested = await Permission.microphone.request();
    return requested.isGranted;
  }

  Future<bool> _ensureSpeechReady() async {
    if (_speechInitialized) return _speechAvailable;

    try {
      _speechAvailable = await _speechToText.initialize(
        onStatus: _handleSpeechStatus,
        onError: (_) {
          _completeVoiceInput(null, showNoSpeechMessage: false);
          _showVoiceUnavailableMessage(
            AppStrings.aiVoiceListeningError,
            isLocalizationKey: true,
          );
        },
        debugLogging: false,
      );

      _speechInitialized = true;
      return _speechAvailable;
    } catch (_) {
      _speechInitialized = true;
      _speechAvailable = false;
      return false;
    }
  }

  Future<String> _resolveBestLocale(String preferredLocaleId) async {
    try {
      final locales = await _speechToText.locales();
      final normalizedPreferred = preferredLocaleId.replaceAll('_', '-').toLowerCase();

      final preferred = locales.where((locale) {
        return locale.localeId.replaceAll('_', '-').toLowerCase() == normalizedPreferred;
      }).toList();

      if (preferred.isNotEmpty) {
        return preferred.first.localeId;
      }

      final preferredLanguage = preferredLocaleId
          .split(RegExp(r'[_-]'))
          .first
          .toLowerCase();

      final languageLocales = locales.where((locale) {
        return locale.localeId.toLowerCase().startsWith(preferredLanguage);
      }).toList();

      if (languageLocales.isNotEmpty) {
        return languageLocales.first.localeId;
      }
    } catch (_) {
      // Keep preferred locale if locale discovery fails.
    }

    return preferredLocaleId;
  }

  void _handleSpeechStatus(String status) {
    final normalized = status.toLowerCase();

    if (normalized == 'done' ||
        normalized == 'notlistening' ||
        normalized == 'not_listening') {
      final activeCompleter = _voiceCompleter;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (isListening &&
            _voiceCompleter != null &&
            _voiceCompleter == activeCompleter) {
          _completeVoiceInput(_currentVoiceText, showNoSpeechMessage: true);
        }
      });
    }
  }

  void _handleSoundLevelChange(double level) {
    if (!isListening) return;

    final safeLevel = level.abs();

    if (safeLevel > _peakSoundLevel) {
      _peakSoundLevel = safeLevel;
    }

    if ((safeLevel - _currentSoundLevel).abs() < _soundLevelNotifyThreshold) {
      return;
    }

    _currentSoundLevel = safeLevel;
    _safeNotifyListeners();
  }

  void _completeVoiceInput(String? text, {required bool showNoSpeechMessage}) {
    final completer = _voiceCompleter;
    if (completer == null || completer.isCompleted) return;

    _voiceSafetyTimer?.cancel();
    _voiceSafetyTimer = null;

    final safeText = text?.trim() ?? '';

    if (safeText.isNotEmpty) {
      _pendingVoiceText = safeText;
      _voiceStatusMessage = safeText;
    } else {
      _pendingVoiceText = null;
      _voiceStatusMessage = null;

      if (showNoSpeechMessage && !_voiceNoSpeechMessageShown) {
        _voiceNoSpeechMessageShown = true;
        messages.add(
          AiChatMessage(
            role: AiChatRole.ai,
            text: AppStrings.aiVoiceNoClearSpeech,
            isLocalizationKey: true,
          ),
        );
      }
    }

    isListening = false;
    _currentSoundLevel = 0;
    _safeNotifyListeners();

    completer.complete(_pendingVoiceText);
    _voiceCompleter = null;
  }

  void _resetVoiceSession() {
    _voiceSafetyTimer?.cancel();
    _voiceSafetyTimer = null;

    _currentVoiceText = '';
    _pendingVoiceText = null;
    _voiceStatusMessage = null;
    _currentSoundLevel = 0;
    _peakSoundLevel = 0;
    _voiceNoSpeechMessageShown = false;

    _voiceCompleter = null;
  }

  void _showVoiceUnavailableMessage(
    String text, {
    bool isLocalizationKey = false,
  }) {
    final safeText = text.trim();
    if (safeText.isEmpty) return;

    messages.add(
      AiChatMessage(
        role: AiChatRole.ai,
        text: safeText,
        isLocalizationKey: isLocalizationKey,
      ),
    );

    isListening = false;
    _voiceStatusMessage = null;
    _currentSoundLevel = 0;
    _safeNotifyListeners();
  }

  Future<void> toggleSpeakResponse(
    String text, {
    required String locale,
  }) async {
    final safeText = text.trim();
    if (safeText.isEmpty) return;

    if (isSpeakingText(safeText)) {
      await stopSpeaking();
      return;
    }

    await speakResponse(safeText, locale: locale);
  }

  Future<void> speakResponse(String text, {required String locale}) async {
    final safeText = text.trim();
    if (safeText.isEmpty) return;

    if (isListening) {
      await stopVoiceInput();
    }

    await _configureTts(locale);
    await _tts.stop();

    _speakingText = safeText;
    isSpeaking = true;
    _safeNotifyListeners();

    await _tts.speak(safeText);
  }

  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Ignore native TTS stop failures.
    }

    _clearSpeakingState();
  }

  Future<void> _configureTts(String locale) async {
    final language = _ttsLanguageFor(locale);
    if (_ttsConfigured && _configuredTtsLanguage == language) return;

    if (!_ttsConfigured) {
      _tts.setStartHandler(() {
        isSpeaking = true;
        _safeNotifyListeners();
      });

      _tts.setCompletionHandler(_clearSpeakingState);
      _tts.setCancelHandler(_clearSpeakingState);
      _tts.setErrorHandler((_) => _clearSpeakingState());
    }

    await _tts.setLanguage(language);
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _ttsConfigured = true;
    _configuredTtsLanguage = language;
  }

  String _speechLocaleFor(String locale) {
    final language = _sanitizeLanguageCode(locale);
    return language == 'ar' ? 'ar_JO' : 'en_US';
  }

  String _ttsLanguageFor(String locale) {
    final language = _sanitizeLanguageCode(locale);
    return language == 'ar' ? 'ar-JO' : 'en-US';
  }

  String _sanitizeLanguageCode(String locale) {
    final language = locale.trim().toLowerCase();
    if (language.startsWith('ar')) return 'ar';
    return 'en';
  }

  void _clearSpeakingState() {
    _speakingText = null;
    isSpeaking = false;
    _safeNotifyListeners();
  }

  List<Map<String, String>> _historyForRequest() {
    final history = messages.map((message) => message.toHistoryMap()).toList();

    if (history.length <= _maxHistoryMessages) return history;
    return history.sublist(history.length - _maxHistoryMessages);
  }

  void _safeNotifyListeners() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;

    _voiceSafetyTimer?.cancel();
    _voiceSafetyTimer = null;

    unawaited(_speechToText.cancel());
    unawaited(_tts.stop());

    super.dispose();
  }
}
