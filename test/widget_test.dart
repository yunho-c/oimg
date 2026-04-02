import 'dart:async';
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
import 'package:oimg/src/settings/app_settings.dart';
import 'package:oimg/src/settings/app_settings_controller.dart';
import 'package:oimg/src/settings/app_settings_repository.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

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
    await tester.pumpAndSettle();

    expect(find.text('Open an image with OIMG'), findsOneWidget);
    expect(find.byType(DropRegion), findsOneWidget);
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
    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Optimize'), findsOneWidget);
    expect(find.text('Optimize selected'), findsNothing);
    expect(find.text('Optimize all'), findsNothing);
    expect(find.text('first.png'), findsWidgets);
    expect(find.text('second.jpg'), findsWidgets);
    expect(find.text('JPEG'), findsWidgets);
    expect(find.text('PSNR'), findsOneWidget);
    expect(find.text('SSIM'), findsOneWidget);
    expect(find.text('Butteraugli'), findsOneWidget);
    expect(find.text('50.0%'), findsOneWidget);

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

  testWidgets('folder rows open a collage and file selection returns to file view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final slimg = _FakeSlimgApi(
      inspectResults: {
        '/tmp/animals/cat.png': _metadata('png', 2400),
        '/tmp/animals/dog.jpg': _metadata('jpeg', 1800),
        '/tmp/cars/road.png': _metadata('png', 900),
      },
    );
    final controller = FileOpenController(
      channel: _FakeFileOpenChannel(),
      slimg: slimg,
      initialPaths: const [
        '/tmp/animals/cat.png',
        '/tmp/animals/dog.jpg',
        '/tmp/cars/road.png',
      ],
    );
    await controller.initialize();

    await tester.pumpWidget(_buildApp(controller: controller, slimg: slimg));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('4.1 KB'), findsOneWidget);

    await tester.tap(find.text('animals').first);
    await tester.pump();

    expect(find.text('1 / 3'), findsNothing);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('0 / 2'), findsOneWidget);
    expect(find.text('Loaded'), findsOneWidget);

    await tester.tap(find.text('dog.jpg').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('folder summary aggregates original and optimized sizes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final slimg = _FakeSlimgApi(
      inspectResults: {
        '/tmp/animals/cat.png': _metadata('png', 2400),
        '/tmp/animals/dog.jpg': _metadata('jpeg', 1800),
        '/tmp/animals/cat.optimized.jpeg': _metadata('jpeg', 900),
      },
    );
    final controller = FileOpenController(
      channel: _FakeFileOpenChannel(),
      slimg: slimg,
      initialPaths: const [
        '/tmp/animals/cat.png',
        '/tmp/animals/dog.jpg',
      ],
    );
    await controller.initialize();
    await controller.applyProcessResults([
      BatchItemResult(
        inputPath: '/tmp/animals/cat.png',
        success: true,
        result: ProcessResult(
          outputPath: '/tmp/animals/cat.optimized.jpeg',
          format: 'jpeg',
          width: 48,
          height: 32,
          originalSize: BigInt.from(2400),
          newSize: BigInt.from(900),
          didWrite: true,
        ),
      ),
    ]);

    await tester.pumpWidget(_buildApp(controller: controller, slimg: slimg));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('animals').first);
    await tester.pump();

    expect(find.text('4.1 KB'), findsOneWidget);
    expect(find.text('2.6 KB'), findsWidgets);
    expect(find.text('35.7%'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('JPEG'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 200));
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

    expect(find.text('PNG'), findsWidgets);
    expect(find.text('WebP'), findsOneWidget);
    expect(find.text('AVIF'), findsOneWidget);
    expect(find.text('JPEG XL'), findsOneWidget);

    await tester.tap(find.text('PNG').first);
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

    await tester.tap(find.text('Optimize'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
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

  testWidgets('cancel stops queued files after the active item finishes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final slimg = _FakeSlimgApi(
      inspectResults: {
        '/tmp/first.png': _metadata('png', 2400),
        '/tmp/second.png': _metadata('png', 2200),
        '/tmp/third.png': _metadata('png', 2000),
        '/tmp/first.optimized.jpeg': _metadata('jpeg', 900),
        '/tmp/second.optimized.jpeg': _metadata('jpeg', 850),
      },
      batchDelay: const Duration(seconds: 1),
    );
    final controller = FileOpenController(
      channel: _FakeFileOpenChannel(),
      slimg: slimg,
      initialPaths: const ['/tmp/first.png', '/tmp/second.png', '/tmp/third.png'],
    );
    await controller.initialize();

    await tester.pumpWidget(_buildApp(controller: controller, slimg: slimg));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('Optimize'));
    await tester.pump();

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Optimize'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('first.optimized.jpeg'), findsWidgets);
    expect(find.text('Saved'), findsWidgets);

    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(find.text('Canceling...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Optimize'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Canceling...'), findsNothing);
    expect(find.text('second.optimized.jpeg'), findsWidgets);
    expect(find.text('third.png'), findsWidgets);
    expect(find.text('third.optimized.jpeg'), findsNothing);
    expect(find.text('Canceled'), findsOneWidget);
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

  testWidgets(
    'lossless preview shows the source image while estimating in background',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final store = _FakeAppSettingsStore()
        ..value = const AppSettings(
          compressionMethod: CompressionMethod.lossless,
          compressionPriority: CompressionPriority.compatibility,
          advancedMode: false,
          preferredCodec: PreferredCodec.jpeg,
          quality: 80,
          developerModeEnabled: false,
          timingLogsEnabled: false,
        ).toJsonString();
      final slimg = _FakeSlimgApi(
        inspectResults: {'/tmp/first.jpg': _metadata('jpeg', 2400)},
        previewDelay: const Duration(seconds: 5),
      );
      final controller = FileOpenController(
        channel: _FakeFileOpenChannel(),
        slimg: slimg,
        initialPaths: const ['/tmp/first.jpg'],
      );
      await controller.initialize();

      await tester.pumpWidget(
        _buildApp(controller: controller, slimg: slimg, store: store),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Estimating'), findsNothing);
      expect(slimg.previewCallCount, 1);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
    },
  );
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
  _FakeSlimgApi({
    Map<String, ImageMetadata>? inspectResults,
    this.previewDelay = Duration.zero,
    this.batchDelay = Duration.zero,
  }) : inspectResults = inspectResults ?? {};

  final Map<String, ImageMetadata> inspectResults;
  final Duration previewDelay;
  final Duration batchDelay;
  ProcessFileBatchRequest? lastBatchRequest;
  bool lastTimingLogsEnabled = false;
  int previewCallCount = 0;
  int _nextJobId = 0;
  final Map<String, _FakeBatchJob> _jobs = {};

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
    previewCallCount += 1;
    if (previewDelay > Duration.zero) {
      await Future<void>.delayed(previewDelay);
    }
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
    if (batchDelay > Duration.zero) {
      await Future<void>.delayed(batchDelay);
    }
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

  @override
  Future<BatchJobHandle> startProcessFileBatchJob({
    required ProcessFileBatchRequest request,
  }) async {
    lastBatchRequest = request;
    final jobId = 'job-${++_nextJobId}';
    final snapshot = BatchJobSnapshot(
      jobId: jobId,
      state: BatchJobState.running,
      totalCount: request.requests.length,
      completedCount: 0,
      results: const [],
    );
    final job = _FakeBatchJob(snapshot: snapshot);
    _jobs[jobId] = job;
    unawaited(_runJob(jobId, request));
    return BatchJobHandle(jobId: jobId);
  }

  @override
  Future<BatchJobSnapshot> getProcessFileBatchJob({required String jobId}) async {
    final job = _jobs[jobId];
    if (job == null) {
      throw StateError('unknown job');
    }
    return job.snapshot;
  }

  @override
  Future<void> cancelProcessFileBatchJob({required String jobId}) async {
    final job = _jobs[jobId];
    if (job == null) {
      throw StateError('unknown job');
    }
    job.cancelRequested = true;
    if (job.snapshot.state == BatchJobState.running) {
      job.snapshot = BatchJobSnapshot(
        jobId: job.snapshot.jobId,
        state: BatchJobState.cancelRequested,
        totalCount: job.snapshot.totalCount,
        completedCount: job.snapshot.completedCount,
        currentInputPath: job.snapshot.currentInputPath,
        results: job.snapshot.results,
        error: job.snapshot.error,
      );
    }
  }

  @override
  Future<void> disposeProcessFileBatchJob({required String jobId}) async {
    _jobs.remove(jobId);
  }

  Future<void> _runJob(String jobId, ProcessFileBatchRequest request) async {
    final job = _jobs[jobId];
    if (job == null) {
      return;
    }

    for (final item in request.requests) {
      if (job.cancelRequested) {
        job.snapshot = BatchJobSnapshot(
          jobId: job.snapshot.jobId,
          state: BatchJobState.canceled,
          totalCount: job.snapshot.totalCount,
          completedCount: job.snapshot.completedCount,
          results: job.snapshot.results,
          error: job.snapshot.error,
        );
        return;
      }

      job.snapshot = BatchJobSnapshot(
        jobId: job.snapshot.jobId,
        state: job.cancelRequested
            ? BatchJobState.cancelRequested
            : BatchJobState.running,
        totalCount: job.snapshot.totalCount,
        completedCount: job.snapshot.completedCount,
        currentInputPath: item.inputPath,
        results: job.snapshot.results,
        error: job.snapshot.error,
      );

      if (batchDelay > Duration.zero) {
        await Future<void>.delayed(batchDelay);
      }

      final results = List<BatchItemResult>.from(job.snapshot.results)
        ..add(
          BatchItemResult(
            inputPath: item.inputPath,
            success: true,
            result: ProcessResult(
              outputPath: item.outputPath ?? item.inputPath,
              format: 'jpeg',
              width: 48,
              height: 32,
              originalSize: BigInt.from(2400),
              newSize: BigInt.from(900),
              didWrite: true,
            ),
          ),
        );

      job.snapshot = BatchJobSnapshot(
        jobId: job.snapshot.jobId,
        state: job.cancelRequested
            ? BatchJobState.cancelRequested
            : BatchJobState.running,
        totalCount: job.snapshot.totalCount,
        completedCount: results.length,
        results: results,
        error: job.snapshot.error,
      );
    }

    job.snapshot = BatchJobSnapshot(
      jobId: job.snapshot.jobId,
      state: BatchJobState.completed,
      totalCount: job.snapshot.totalCount,
      completedCount: job.snapshot.completedCount,
      results: job.snapshot.results,
      error: job.snapshot.error,
    );
  }
}

class _FakeBatchJob {
  _FakeBatchJob({required this.snapshot});

  BatchJobSnapshot snapshot;
  bool cancelRequested = false;
}
