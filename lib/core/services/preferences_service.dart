import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  PreferencesService();

  SharedPreferences? _preferences;

  bool get isInitialized => _preferences != null;

  Future<void> init() async {
    _preferences ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _prefs {
    final instance = _preferences;
    if (instance == null) {
      throw StateError(
        'PreferencesService is not initialized. Call init() before use.',
      );
    }
    return instance;
  }

  bool getBool(String key, {required bool defaultValue}) {
    return _prefs.getBool(key) ?? defaultValue;
  }

  Future<bool> setBool(String key, bool value) {
    return _prefs.setBool(key, value);
  }

  double getDouble(String key, {required double defaultValue}) {
    return _prefs.getDouble(key) ?? defaultValue;
  }

  Future<bool> setDouble(String key, double value) {
    return _prefs.setDouble(key, value);
  }

  String getString(String key, {required String defaultValue}) {
    return _prefs.getString(key) ?? defaultValue;
  }

  Future<bool> setString(String key, String value) {
    return _prefs.setString(key, value);
  }

  Future<bool> remove(String key) {
    return _prefs.remove(key);
  }
}
