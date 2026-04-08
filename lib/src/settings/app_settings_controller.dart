import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';
import 'app_settings_repository.dart';
import 'developer_diagnostics.dart';

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository(store: SharedPreferencesAppSettingsStore());
});

final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

class AppSettingsController extends AsyncNotifier<AppSettings> {
  AppSettingsRepository get _repository =>
      ref.read(appSettingsRepositoryProvider);

  @override
  Future<AppSettings> build() async {
    final settings = await _repository.load();
    _applyDiagnostics(settings);
    return settings;
  }

  Future<void> setCompressionMethod(CompressionMethod compressionMethod) async {
    await _update(
      (settings) => settings.copyWith(compressionMethod: compressionMethod),
    );
  }

  Future<void> setCompressionPriority(
    CompressionPriority compressionPriority,
  ) async {
    await _update(
      (settings) => settings.copyWith(compressionPriority: compressionPriority),
    );
  }

  Future<void> setAdvancedMode(bool advancedMode) async {
    await _update((settings) => settings.copyWith(advancedMode: advancedMode));
  }

  Future<void> setPreferredCodec(PreferredCodec preferredCodec) async {
    await _update(
      (settings) => settings.copyWith(preferredCodec: preferredCodec),
    );
  }

  Future<void> setQuality(int quality) async {
    await _update((settings) => settings.copyWith(quality: quality));
  }

  Future<void> setStorageDestinationMode(
    StorageDestinationMode storageDestinationMode,
  ) async {
    await _update(
      (settings) => settings.copyWith(
        storageDestinationMode: storageDestinationMode,
      ),
    );
  }

  Future<void> setSameFolderAction(SameFolderAction sameFolderAction) async {
    await _update(
      (settings) => settings.copyWith(sameFolderAction: sameFolderAction),
    );
  }

  Future<void> setDifferentLocationPath(String? differentLocationPath) async {
    await _update(
      (settings) => settings.copyWith(
        differentLocationPath: differentLocationPath,
      ),
    );
  }

  Future<void> setPreserveFolderStructure(bool preserveFolderStructure) async {
    await _update(
      (settings) => settings.copyWith(
        preserveFolderStructure: preserveFolderStructure,
      ),
    );
  }

  Future<void> setPreserveOriginalDate(bool preserveOriginalDate) async {
    await _update(
      (settings) => settings.copyWith(
        preserveOriginalDate: preserveOriginalDate,
      ),
    );
  }

  Future<void> setDeveloperModeEnabled(bool developerModeEnabled) async {
    await _update(
      (settings) => settings.copyWith(
        developerModeEnabled: developerModeEnabled,
        timingLogsEnabled: developerModeEnabled
            ? settings.timingLogsEnabled
            : false,
      ),
    );
  }

  Future<void> setTimingLogsEnabled(bool timingLogsEnabled) async {
    await _update(
      (settings) => settings.copyWith(timingLogsEnabled: timingLogsEnabled),
    );
  }

  Future<void> setPreviewPathHeaderEnabled(bool previewPathHeaderEnabled) async {
    await _update(
      (settings) => settings.copyWith(
        previewPathHeaderEnabled: previewPathHeaderEnabled,
      ),
    );
  }

  Future<void> _update(
    AppSettings Function(AppSettings settings) transform,
  ) async {
    final currentSettings = state.hasValue ? state.requireValue : await future;
    final nextSettings = transform(currentSettings);
    _applyDiagnostics(nextSettings);
    state = AsyncData(nextSettings);
    await _repository.save(nextSettings);
  }

  void _applyDiagnostics(AppSettings settings) {
    DeveloperDiagnostics.setTimingLogsEnabled(
      settings.developerModeEnabled && settings.timingLogsEnabled,
    );
  }
}
