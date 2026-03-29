import 'package:flutter_test/flutter_test.dart';
import 'package:oimg/src/settings/app_settings.dart';
import 'package:oimg/src/settings/app_settings_repository.dart';

void main() {
  group('AppSettingsRepository', () {
    test('returns defaults when storage is empty', () async {
      final repository = AppSettingsRepository(store: _FakeAppSettingsStore());

      final settings = await repository.load();

      expect(settings, AppSettings.defaults);
    });

    test('persists and reloads settings', () async {
      final store = _FakeAppSettingsStore();
      final repository = AppSettingsRepository(store: store);
      const settings = AppSettings(
        compressionMethod: CompressionMethod.lossless,
        compressionPriority: CompressionPriority.efficiency,
        advancedMode: true,
        preferredCodec: PreferredCodec.webp,
        quality: 90,
        developerModeEnabled: true,
        timingLogsEnabled: true,
      );

      await repository.save(settings);

      expect(await repository.load(), settings);
    });

    test('falls back to defaults when stored JSON is invalid', () async {
      final repository = AppSettingsRepository(
        store: _FakeAppSettingsStore(initialValue: '{bad json'),
      );

      final settings = await repository.load();

      expect(settings, AppSettings.defaults);
    });
  });
}

class _FakeAppSettingsStore implements AppSettingsStore {
  _FakeAppSettingsStore({this.initialValue});

  String? initialValue;

  @override
  Future<String?> read() async => initialValue;

  @override
  Future<void> write(String value) async {
    initialValue = value;
  }
}
