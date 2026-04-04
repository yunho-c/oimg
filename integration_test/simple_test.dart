import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oimg/main.dart';
import 'package:oimg/src/file_open/file_open_channel.dart';
import 'package:oimg/src/file_open/file_open_controller.dart';
import 'package:oimg/src/file_open/file_open_providers.dart';
import 'package:oimg/src/optimization/optimization_providers.dart';
import 'package:oimg/src/rust/frb_generated.dart';
import 'package:oimg/src/rust/slimg_api.dart';
import 'package:oimg/src/rust/types.dart';
import 'package:oimg/src/settings/app_settings_controller.dart';
import 'package:oimg/src/settings/app_settings_repository.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());

  testWidgets('Shows the empty state without opened files', (
    WidgetTester tester,
  ) async {
    final slimg = _FakeSlimgApi();
    final controller = FileOpenController(
      channel: _NoopFileOpenChannel(),
      slimg: slimg,
    );
    await controller.initialize();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          slimgApiProvider.overrideWithValue(slimg),
          fileOpenControllerProvider.overrideWith((ref) => controller),
          appSettingsRepositoryProvider.overrideWithValue(
            AppSettingsRepository(store: _FakeAppSettingsStore()),
          ),
        ],
        child: const MyApp(),
      ),
    );
    expect(find.text('Open an image with OIMG'), findsOneWidget);
  });
}

class _NoopFileOpenChannel implements FileOpenChannel {
  @override
  Future<void> bind(OpenFilesHandler onOpenFiles) async {}
}

class _FakeSlimgApi implements SlimgApi {
  @override
  void setTimingLogsEnabled({required bool enabled}) {}

  @override
  Future<ImageMetadata> inspectFile({required String inputPath}) {
    throw StateError('unsupported');
  }

  @override
  Future<PreviewResult> previewFile({required PreviewFileRequest request}) async {
    return PreviewResult(
      encodedBytes: Uint8List(0),
      format: 'png',
      width: 1,
      height: 1,
      sizeBytes: BigInt.one,
    );
  }

  @override
  Future<double?> computePreviewPixelMatchPercentage({
    required PreviewQualityMetricsRequest request,
  }) async {
    return null;
  }

  @override
  Future<double?> computePreviewMsSsim({
    required PreviewQualityMetricsRequest request,
  }) async {
    return null;
  }

  @override
  Future<double?> computePreviewSsimulacra2({
    required PreviewQualityMetricsRequest request,
  }) async {
    return null;
  }

  @override
  Future<EncodedImageResult?> computePreviewDifferenceImage({
    required PreviewQualityMetricsRequest request,
  }) async {
    return null;
  }

  @override
  Future<ProcessResult> processFile({required ProcessFileRequest request}) {
    throw UnimplementedError();
  }

  @override
  Future<List<BatchItemResult>> processFileBatch({
    required ProcessFileBatchRequest request,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<BatchJobHandle> startProcessFileBatchJob({
    required ProcessFileBatchRequest request,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<BatchJobSnapshot> getProcessFileBatchJob({required String jobId}) {
    throw UnimplementedError();
  }

  @override
  Future<void> cancelProcessFileBatchJob({required String jobId}) {
    throw UnimplementedError();
  }

  @override
  Future<void> disposeProcessFileBatchJob({required String jobId}) {
    throw UnimplementedError();
  }
}

class _FakeAppSettingsStore implements AppSettingsStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String value) async {}
}
