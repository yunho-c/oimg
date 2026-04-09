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
      await notifier.setStorageDestinationMode(
        StorageDestinationMode.differentLocation,
      );
      await notifier.setSameFolderAction(SameFolderAction.keepSource);
      await notifier.setDifferentLocationPath('/tmp/export');
      await notifier.setPreserveFolderStructure(false);
      await notifier.setPreserveOriginalDate(true);
      await notifier.setPreserveExif(true);
      await notifier.setPreserveColorProfile(true);
      await notifier.setQualityMetricColorsEnabled(true);
      await notifier.setSimilarityMetricColorsEnabled(true);
      await notifier.setSavingsColorsEnabled(true);
      await notifier.setBitsPerPixelColorsEnabled(true);
      await notifier.setFileSizeColorsEnabled(true);
      await notifier.setThemePreference(AppThemePreference.dark);
      await notifier.setDeveloperModeEnabled(true);
      await notifier.setTimingLogsEnabled(true);

      final settings = container.read(appSettingsProvider).requireValue;
      expect(
        settings,
        const AppSettings(
          compressionMethod: CompressionMethod.lossless,
          compressionPriority: CompressionPriority.efficiency,
          advancedMode: true,
          preferredCodec: PreferredCodec.webp,
          quality: 92,
          storageDestinationMode: StorageDestinationMode.differentLocation,
          sameFolderAction: SameFolderAction.keepSource,
          differentLocationPath: '/tmp/export',
          preserveFolderStructure: false,
          preserveOriginalDate: true,
          preserveExif: true,
          preserveColorProfile: true,
          qualityMetricColorsEnabled: true,
          similarityMetricColorsEnabled: true,
          savingsColorsEnabled: true,
          bitsPerPixelColorsEnabled: true,
          fileSizeColorsEnabled: true,
          themePreference: AppThemePreference.dark,
          developerModeEnabled: true,
          timingLogsEnabled: true,
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
