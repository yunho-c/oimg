import 'package:shared_preferences/shared_preferences.dart';

import 'app_settings.dart';

const _appSettingsStorageKey = 'app_settings';

abstract class AppSettingsStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SharedPreferencesAppSettingsStore implements AppSettingsStore {
  SharedPreferencesAppSettingsStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read() {
    return _preferences.getString(_appSettingsStorageKey);
  }

  @override
  Future<void> write(String value) async {
    await _preferences.setString(_appSettingsStorageKey, value);
  }
}

class AppSettingsRepository {
  AppSettingsRepository({required AppSettingsStore store}) : _store = store;

  final AppSettingsStore _store;

  Future<AppSettings> load() async {
    final rawValue = await _store.read();
    if (rawValue == null || rawValue.isEmpty) {
      return AppSettings.defaults;
    }

    try {
      return AppSettings.fromJsonString(rawValue);
    } catch (_) {
      return AppSettings.defaults;
    }
  }

  Future<void> save(AppSettings settings) {
    return _store.write(settings.toJsonString());
  }
}
