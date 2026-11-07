enum AiChatRole { user, ai }

class AiChatMessage {
  AiChatMessage({
    required this.role,
    required this.text,
    this.isLocalizationKey = false,
    DateTime? createdAt,
  })
    : assert(text.isNotEmpty),
      createdAt = createdAt ?? DateTime.now();

  static const String _warningPrefix = '⚠️';

  final AiChatRole role;
  final String text;
  final bool isLocalizationKey;
  final DateTime createdAt;

  bool get isUser => role == AiChatRole.user;
  bool get isAi => role == AiChatRole.ai;

  bool get isWarning {
    return text.trimLeft().startsWith(_warningPrefix);
  }

  Map<String, String> toHistoryMap() {
    return {'role': isUser ? 'user' : 'ai', 'text': text.trim()};
  }
}
