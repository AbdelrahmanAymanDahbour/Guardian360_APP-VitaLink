/// ==========================================
/// 🔐 App Environment
/// ==========================================
/// Central place for compile-time environment values.
///
/// Pass values using:
/// flutter run --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY
///
/// Optional Guardian AI overrides:
/// flutter run --dart-define=GUARDIAN_AI_FUNCTION_REGION=us-central1
/// flutter run --dart-define=GUARDIAN_AI_FUNCTION_NAME=guardianAiChat
class AppEnv {
  const AppEnv._();

  // ==========================================
  // 🗺️ Google Maps
  // ==========================================
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
  );

  static bool get hasGoogleMapsApiKey {
    return googleMapsApiKey.trim().isNotEmpty;
  }

  static String requireGoogleMapsApiKey() {
    final key = googleMapsApiKey.trim();

    if (key.isEmpty) {
      throw StateError(
        'Missing GOOGLE_MAPS_API_KEY. '
        'Run with --dart-define=GOOGLE_MAPS_API_KEY=YOUR_KEY '
        'or configure .vscode/launch.json.',
      );
    }

    return key;
  }

  // ==========================================
  // 🌐 Guardian AI Cloud Function
  // ==========================================
  static const String guardianAiFunctionRegion = String.fromEnvironment(
    'GUARDIAN_AI_FUNCTION_REGION',
    defaultValue: 'us-central1',
  );

  static const String guardianAiFunctionName = String.fromEnvironment(
    'GUARDIAN_AI_FUNCTION_NAME',
    defaultValue: 'guardianAiChat',
  );

  static String get safeGuardianAiFunctionRegion {
    final region = guardianAiFunctionRegion.trim();
    return region.isEmpty ? 'us-central1' : region;
  }

  static String get safeGuardianAiFunctionName {
    final functionName = guardianAiFunctionName.trim();
    return functionName.isEmpty ? 'guardianAiChat' : functionName;
  }
}
