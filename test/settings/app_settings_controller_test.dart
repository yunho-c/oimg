import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oimg/src/settings/app_settings.dart';
import 'package:oimg/src/settings/app_settings_controller.dart';
import 'package:oimg/src/settings/app_settings_repository.dart';

void main() {
  group('AppSettingsController', () {
    test('loads defaults from the repository', () async {
      final container = ProviderContainer(
        overrides: [
          appSettingsRepositoryProvider.overrideWithValue(
            AppSettingsRepository(store: _FakeAppSettingsStore()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final settings = await container.read(appSettingsProvider.future);

      expect(settings, AppSettings.defaults);
    });

    test('updates and persists settings changes', () async {
      final store = _FakeAppSettingsStore();
      final container = ProviderContainer(
        overrides: [
          appSettingsRepositoryProvider.overrideWithValue(
            AppSettingsRepository(store: store),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appSettingsProvider.future);
      final notifier = container.read(appSettingsProvider.notifier);

      await notifier.setCompressionMethod(CompressionMethod.lossless);
      await notifier.setCompressionPriority(CompressionPriority.efficiency);
      await notifier.setAdvancedMode(true);
      await notifier.setPreferredCodec(PreferredCodec.webp);
      await notifier.setQuality(92);

      final settings = container.read(appSettingsProvider).requireValue;
      expect(
        settings,
        const AppSettings(
          compressionMethod: CompressionMethod.lossless,
          compressionPriority: CompressionPriority.efficiency,
          advancedMode: true,
          preferredCodec: PreferredCodec.webp,
          quality: 92,
        ),
      );
      expect(await store.read(), settings.toJsonString());
    });
  });
}

class _FakeAppSettingsStore implements AppSettingsStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
  }
}
