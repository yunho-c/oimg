import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings.dart';
import 'app_settings_repository.dart';

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
  Future<AppSettings> build() {
    return _repository.load();
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

  Future<void> _update(
    AppSettings Function(AppSettings settings) transform,
  ) async {
    final currentSettings = state.hasValue ? state.requireValue : await future;
    final nextSettings = transform(currentSettings);
    state = AsyncData(nextSettings);
    await _repository.save(nextSettings);
  }
}
