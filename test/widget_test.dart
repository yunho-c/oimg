import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oimg/main.dart';
import 'package:oimg/src/file_open/file_open_channel.dart';
import 'package:oimg/src/file_open/file_open_controller.dart';
import 'package:oimg/src/file_open/file_open_providers.dart';
import 'package:oimg/src/optimization/optimization_providers.dart';
import 'package:oimg/src/rust/slimg_api.dart';
import 'package:oimg/src/rust/types.dart';
import 'package:oimg/src/settings/app_settings_controller.dart';
import 'package:oimg/src/settings/app_settings_repository.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('renders empty state with no startup files', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final slimg = _FakeSlimgApi();
    final controller = FileOpenController(
      channel: _FakeFileOpenChannel(),
      slimg: slimg,
    );
    await controller.initialize();

    await tester.pumpWidget(_buildApp(controller: controller, slimg: slimg));
    await tester.pump();

    expect(find.text('Open an image with OIMG'), findsOneWidget);
  });

  testWidgets('renders startup session, preview, and actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final slimg = _FakeSlimgApi(
      inspectResults: {
        '/tmp/first.png': _metadata('png', 2400),
        '/tmp/second.jpg': _metadata('jpeg', 1800),
      },
    );
    final controller = FileOpenController(
      channel: _FakeFileOpenChannel(),
      slimg: slimg,
      initialPaths: const ['/tmp/first.png', '/tmp/second.jpg'],
    );
    await controller.initialize();

    await tester.pumpWidget(_buildApp(controller: controller, slimg: slimg));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Optimize selected'), findsOneWidget);
    expect(find.text('Optimize all'), findsOneWidget);
    expect(find.text('first.png'), findsWidgets);
    expect(find.text('second.jpg'), findsWidgets);
    expect(find.text('JPEG'), findsWidgets);

    await tester.tap(find.text('second.jpg').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('later openFiles event replaces the session', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final channel = _FakeFileOpenChannel();
    final slimg = _FakeSlimgApi(
      inspectResults: {
        '/tmp/original.png': _metadata('png', 2000),
        '/tmp/new-one.webp': _metadata('webp', 1200),
        '/tmp/new-two.bmp': _metadata('jpeg', 1600),
      },
    );
    final controller = FileOpenController(
      channel: channel,
      slimg: slimg,
      initialPaths: const ['/tmp/original.png'],
    );
    await controller.initialize();

    await tester.pumpWidget(_buildApp(controller: controller, slimg: slimg));
    await tester.pump();

    expect(find.text('original.png'), findsWidgets);

    await channel.emit(const ['/tmp/new-one.webp', '/tmp/new-two.bmp']);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('new-one.webp'), findsWidgets);
    expect(find.text('new-two.bmp'), findsWidgets);
    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('toggles advanced mode in the settings sidebar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final slimg = _FakeSlimgApi(
      inspectResults: {'/tmp/first.png': _metadata('png', 2400)},
    );
    final controller = FileOpenController(
      channel: _FakeFileOpenChannel(),
      slimg: slimg,
      initialPaths: const ['/tmp/first.png'],
    );
    await controller.initialize();

    await tester.pumpWidget(_buildApp(controller: controller, slimg: slimg));
    await tester.pump();

    expect(find.text('Lossless'), findsOneWidget);
    expect(find.text('Lossy'), findsOneWidget);
    expect(find.text('Compatibility'), findsOneWidget);
    expect(find.text('Efficiency'), findsOneWidget);
    expect(find.text('Quality'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('PNG'), findsOneWidget);
    expect(find.text('WebP'), findsOneWidget);
    expect(find.text('AVIF'), findsOneWidget);
    expect(find.text('JPEG XL'), findsOneWidget);

    await tester.tap(find.text('PNG'));
    await tester.pumpAndSettle();

    expect(find.text('Quality'), findsNothing);
  });

  testWidgets('optimize all uses mixed slimg requests and updates the session', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final slimg = _FakeSlimgApi(
      inspectResults: {
        '/tmp/first.png': _metadata('png', 2400),
        '/tmp/second.jpg': _metadata('jpeg', 1800),
        '/tmp/first.optimized.jpeg': _metadata('jpeg', 900),
      },
    );
    final controller = FileOpenController(
      channel: _FakeFileOpenChannel(),
      slimg: slimg,
      initialPaths: const ['/tmp/first.png', '/tmp/second.jpg'],
    );
    await controller.initialize();

    await tester.pumpWidget(_buildApp(controller: controller, slimg: slimg));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Optimize all'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    final batch = slimg.lastBatchRequest!;
    expect(batch.requests.length, 2);
    batch.requests[0].operation.when(
      convert: (options) => expect(options.targetFormat, 'jpeg'),
      optimize: (_) => fail('expected convert for png -> jpeg'),
      resize: (_) => fail('unexpected resize'),
      crop: (_) => fail('unexpected crop'),
      extend: (_) => fail('unexpected extend'),
    );
    batch.requests[1].operation.when(
      convert: (_) => fail('expected optimize for jpeg source'),
      optimize: (_) {},
      resize: (_) => fail('unexpected resize'),
      crop: (_) => fail('unexpected crop'),
      extend: (_) => fail('unexpected extend'),
    );

    expect(find.text('first.optimized.jpeg'), findsWidgets);
    expect(find.text('Saved'), findsWidgets);
  });

  testWidgets('developer dialog toggles persisted timing logs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = _FakeAppSettingsStore();
    final slimg = _FakeSlimgApi(
      inspectResults: {'/tmp/first.png': _metadata('png', 2400)},
    );
    final controller = FileOpenController(
      channel: _FakeFileOpenChannel(),
      slimg: slimg,
      initialPaths: const ['/tmp/first.png'],
    );
    await controller.initialize();

    await tester.pumpWidget(
      _buildApp(controller: controller, slimg: slimg, store: store),
    );
    await tester.pump();

    await tester.tap(find.byIcon(LucideIcons.wrench));
    await tester.pumpAndSettle();

    expect(find.text('Developer'), findsOneWidget);
    expect(find.text('Timing logs'), findsOneWidget);
    expect(slimg.lastTimingLogsEnabled, isFalse);

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(slimg.lastTimingLogsEnabled, isTrue);
    expect(store.value, contains('"developerModeEnabled":true'));
    expect(store.value, contains('"timingLogsEnabled":true'));
  });
}

Widget _buildApp({
  required FileOpenController controller,
  required _FakeSlimgApi slimg,
  AppSettingsStore? store,
}) {
  return ProviderScope(
    overrides: [
      slimgApiProvider.overrideWithValue(slimg),
      fileOpenControllerProvider.overrideWith((ref) => controller),
      appSettingsRepositoryProvider.overrideWithValue(
        AppSettingsRepository(store: store ?? _FakeAppSettingsStore()),
      ),
    ],
    child: const MyApp(),
  );
}

ImageMetadata _metadata(String format, int bytes) {
  return ImageMetadata(
    width: 48,
    height: 32,
    format: format,
    fileSize: BigInt.from(bytes),
  );
}

class _FakeFileOpenChannel implements FileOpenChannel {
  OpenFilesHandler? _handler;

  @override
  Future<void> bind(OpenFilesHandler onOpenFiles) async {
    _handler = onOpenFiles;
  }

  Future<void> emit(List<String> paths) async {
    await _handler?.call(paths);
  }
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

class _FakeSlimgApi implements SlimgApi {
  _FakeSlimgApi({Map<String, ImageMetadata>? inspectResults})
    : inspectResults = inspectResults ?? {};

  final Map<String, ImageMetadata> inspectResults;
  ProcessFileBatchRequest? lastBatchRequest;
  bool lastTimingLogsEnabled = false;

  static final Uint8List _previewBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4////fwAJ+wP9KobjigAAAABJRU5ErkJggg==',
  );

  @override
  Future<ImageMetadata> inspectFile({required String inputPath}) async {
    final result = inspectResults[inputPath];
    if (result == null) {
      throw StateError('unsupported');
    }
    return result;
  }

  @override
  void setTimingLogsEnabled({required bool enabled}) {
    lastTimingLogsEnabled = enabled;
  }

  @override
  Future<PreviewResult> previewFile({required PreviewFileRequest request}) async {
    return PreviewResult(
      encodedBytes: _previewBytes,
      format: 'jpeg',
      width: 48,
      height: 32,
      sizeBytes: BigInt.from(1200),
    );
  }

  @override
  Future<ProcessResult> processFile({required ProcessFileRequest request}) {
    throw UnimplementedError();
  }

  @override
  Future<List<BatchItemResult>> processFileBatch({
    required ProcessFileBatchRequest request,
  }) async {
    lastBatchRequest = request;
    return request.requests
        .map((item) {
          final outputPath = item.outputPath ?? item.inputPath;
          return BatchItemResult(
            inputPath: item.inputPath,
            success: true,
            result: ProcessResult(
              outputPath: outputPath,
              format: outputPath.endsWith('.jpeg') ? 'jpeg' : 'jpeg',
              width: 48,
              height: 32,
              originalSize: BigInt.from(2400),
              newSize: BigInt.from(900),
              didWrite: true,
            ),
          );
        })
        .toList(growable: false);
  }
}
