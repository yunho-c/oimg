import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oimg/src/file_open/file_open_providers.dart';
import 'package:oimg/src/file_open/opened_image_file.dart';
import 'package:oimg/src/rust/slimg_api.dart';
import 'package:oimg/src/rust/types.dart';
import 'package:oimg/src/settings/app_settings_controller.dart';
import 'package:oimg/src/settings/developer_diagnostics.dart';

import 'optimization_plan.dart';

final slimgApiProvider = Provider<SlimgApi>((ref) => const FrbSlimgApi());
int _previewRequestSequence = 0;
int _previewMetricsRequestSequence = 0;

final currentOptimizationPlanProvider =
    FutureProvider.autoDispose<OptimizationPlan?>((ref) async {
      final controller = ref.watch(fileOpenControllerProvider);
      final currentFile = controller.currentFile;
      if (currentFile == null) {
        return null;
      }

      final settings = await ref.watch(appSettingsProvider.future);
      return buildOptimizationPlan(file: currentFile, settings: settings);
    });

class OptimizationPreview {
  const OptimizationPreview({
    required this.sourceFile,
    required this.plan,
    required this.result,
  });

  final OpenedImageFile sourceFile;
  final OptimizationPlan plan;
  final PreviewResult result;

  int? get originalSize => sourceFile.metadata.fileSize?.toInt();

  int? get savingsBytes {
    final size = originalSize;
    if (size == null) {
      return null;
    }
    return size - result.sizeBytes.toInt();
  }

  double? get savingsPercent {
    final size = originalSize;
    final savings = savingsBytes;
    if (size == null || size <= 0 || savings == null) {
      return null;
    }
    return (savings / size) * 100;
  }
}

final currentPreviewProvider = FutureProvider.autoDispose<OptimizationPreview?>((
  ref,
) async {
  final requestId = ++_previewRequestSequence;
  final totalStopwatch = Stopwatch()..start();
  ref.onDispose(() {
    DeveloperDiagnostics.logTiming(
      'preview:$requestId',
      'disposed total=${totalStopwatch.elapsedMilliseconds}ms',
    );
  });

  try {
    final planStopwatch = Stopwatch()..start();
    final plan = await ref.watch(currentOptimizationPlanProvider.future);
    planStopwatch.stop();
    if (plan == null) {
      return null;
    }

    DeveloperDiagnostics.logTiming(
      'preview:$requestId',
      'plan=${planStopwatch.elapsedMilliseconds}ms path=${plan.sourceFile.path} codec=${plan.targetCodec.name} useSource=${plan.useSourceImageForPreview}',
    );

    final debounceStopwatch = Stopwatch()..start();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    debounceStopwatch.stop();
    DeveloperDiagnostics.logTiming(
      'preview:$requestId',
      'debounce=${debounceStopwatch.elapsedMilliseconds}ms target=${plan.targetCodec.name} sourceCodec=${plan.usesSourceCodec}',
    );

    final previewStopwatch = Stopwatch()..start();
    final result = await ref
        .read(slimgApiProvider)
        .previewFile(request: plan.previewRequest);
    previewStopwatch.stop();
    totalStopwatch.stop();
    DeveloperDiagnostics.logTiming(
      'preview:$requestId',
      'preview=${previewStopwatch.elapsedMilliseconds}ms total=${totalStopwatch.elapsedMilliseconds}ms format=${result.format} size=${result.sizeBytes}',
    );

    return OptimizationPreview(
      sourceFile: plan.sourceFile,
      plan: plan,
      result: result,
    );
  } on Object catch (error, stackTrace) {
    DeveloperDiagnostics.logTimingError('preview:$requestId', error, stackTrace);
    rethrow;
  }
});

final currentPreviewQualityMetricsProvider =
    FutureProvider.autoDispose<PreviewQualityMetrics?>((ref) async {
      final requestId = ++_previewMetricsRequestSequence;
      final totalStopwatch = Stopwatch()..start();
      ref.onDispose(() {
        DeveloperDiagnostics.logTiming(
          'preview-metrics:$requestId',
          'disposed total=${totalStopwatch.elapsedMilliseconds}ms',
        );
      });

      try {
        final preview = await ref.watch(currentPreviewProvider.future);
        if (preview == null) {
          return null;
        }

        DeveloperDiagnostics.logTiming(
          'preview-metrics:$requestId',
          'start path=${preview.sourceFile.path}',
        );

        final metricsStopwatch = Stopwatch()..start();
        final result = await ref
            .read(slimgApiProvider)
            .computePreviewQualityMetrics(
              request: PreviewQualityMetricsRequest(
                inputPath: preview.sourceFile.path,
                previewEncodedBytes: preview.result.encodedBytes,
              ),
            );
        metricsStopwatch.stop();
        totalStopwatch.stop();
        DeveloperDiagnostics.logTiming(
          'preview-metrics:$requestId',
          'done metrics=${metricsStopwatch.elapsedMilliseconds}ms total=${totalStopwatch.elapsedMilliseconds}ms msSsim=${result.msSsim}',
        );
        return result;
      } on Object catch (error, stackTrace) {
        DeveloperDiagnostics.logTimingError(
          'preview-metrics:$requestId',
          error,
          stackTrace,
        );
        rethrow;
      }
    });

enum OptimizationItemStatus {
  idle,
  queued,
  running,
  written,
  skipped,
  failed,
  canceled,
}

class OptimizationItemState {
  const OptimizationItemState({
    required this.status,
    this.message,
    this.result,
  });

  final OptimizationItemStatus status;
  final String? message;
  final ProcessResult? result;
}

class OptimizationRunState {
  const OptimizationRunState({
    this.jobId,
    this.jobState,
    this.completedCount = 0,
    this.totalCount = 0,
    this.currentInputPath,
    this.appliedResultCount = 0,
    this.items = const {},
    this.globalError,
  });

  final String? jobId;
  final BatchJobState? jobState;
  final int completedCount;
  final int totalCount;
  final String? currentInputPath;
  final int appliedResultCount;
  final Map<String, OptimizationItemState> items;
  final String? globalError;

  bool get isRunning =>
      jobState == BatchJobState.running ||
      jobState == BatchJobState.cancelRequested;

  bool get isCancelRequested => jobState == BatchJobState.cancelRequested;

  OptimizationRunState copyWith({
    String? jobId,
    BatchJobState? jobState,
    int? completedCount,
    int? totalCount,
    String? currentInputPath,
    int? appliedResultCount,
    Map<String, OptimizationItemState>? items,
    String? globalError,
    bool clearGlobalError = false,
    bool clearJobId = false,
    bool clearJobState = false,
    bool clearCurrentInputPath = false,
  }) {
    return OptimizationRunState(
      jobId: clearJobId ? null : (jobId ?? this.jobId),
      jobState: clearJobState ? null : (jobState ?? this.jobState),
      completedCount: completedCount ?? this.completedCount,
      totalCount: totalCount ?? this.totalCount,
      currentInputPath: clearCurrentInputPath
          ? null
          : (currentInputPath ?? this.currentInputPath),
      appliedResultCount: appliedResultCount ?? this.appliedResultCount,
      items: items ?? this.items,
      globalError: clearGlobalError ? null : (globalError ?? this.globalError),
    );
  }
}

final optimizationRunControllerProvider =
    NotifierProvider<OptimizationRunController, OptimizationRunState>(
      OptimizationRunController.new,
    );

class OptimizationRunController extends Notifier<OptimizationRunState> {
  List<String> _activeInputPaths = const <String>[];

  @override
  OptimizationRunState build() => const OptimizationRunState();

  Future<void> optimizeSelected() async {
    final file = ref.read(fileOpenControllerProvider).currentFile;
    if (file == null) {
      return;
    }
    await _run([file]);
  }

  Future<void> optimizeAll() async {
    final files = ref.read(fileOpenControllerProvider).sessionFiles.toList();
    if (files.isEmpty) {
      return;
    }
    await _run(files);
  }

  Future<void> cancelCurrentRun() async {
    if (!state.isRunning || state.isCancelRequested || state.jobId == null) {
      return;
    }

    final jobId = state.jobId!;
    state = state.copyWith(
      jobState: BatchJobState.cancelRequested,
      clearGlobalError: true,
    );

    try {
      await ref.read(slimgApiProvider).cancelProcessFileBatchJob(jobId: jobId);
    } on Object catch (error) {
      state = _idleState(
        items: state.items,
        globalError: error.toString(),
      );
    }
  }

  Future<void> _run(List<OpenedImageFile> files) async {
    if (state.isRunning) {
      return;
    }

    final settings = await ref.read(appSettingsProvider.future);
    final requests = files
        .map((file) => buildOptimizationPlan(file: file, settings: settings))
        .map((plan) => plan.processRequest)
        .toList(growable: false);
    final inputPaths = files.map((file) => file.path).toList(growable: false);
    final queuedItems = {
      for (final path in inputPaths)
        path: const OptimizationItemState(status: OptimizationItemStatus.queued),
    };

    try {
      DeveloperDiagnostics.logTiming(
        'optimize-run',
        'start files=${inputPaths.length} paths=${inputPaths.join(",")}',
      );
      final handle = await ref
          .read(slimgApiProvider)
          .startProcessFileBatchJob(
            request: ProcessFileBatchRequest(
              requests: requests,
              continueOnError: true,
            ),
          );
      _activeInputPaths = inputPaths;
      state = OptimizationRunState(
        jobId: handle.jobId,
        jobState: BatchJobState.running,
        totalCount: inputPaths.length,
        items: queuedItems,
      );
      DeveloperDiagnostics.logTiming(
        'optimize-run',
        'job-started jobId=${handle.jobId} total=${inputPaths.length}',
      );
      unawaited(_pollJob(handle.jobId));
    } on Object catch (error) {
      DeveloperDiagnostics.logTimingError('optimize-run', error);
      state = _idleState(
        items: queuedItems,
        globalError: error.toString(),
      );
    }
  }

  Future<void> _pollJob(String jobId) async {
    while (state.jobId == jobId) {
      try {
        final snapshot = await ref
            .read(slimgApiProvider)
            .getProcessFileBatchJob(jobId: jobId);
        if (state.jobId != jobId) {
          return;
        }

        DeveloperDiagnostics.logTiming(
          'optimize-run',
          'snapshot jobId=$jobId state=${snapshot.state.name} completed=${snapshot.completedCount}/${snapshot.totalCount} current=${snapshot.currentInputPath} results=${snapshot.results.length} error=${snapshot.error}',
        );
        await _applySnapshot(jobId, snapshot);
        if (_isTerminalJobState(snapshot.state)) {
          await _disposeJob(jobId);
          DeveloperDiagnostics.logTiming(
            'optimize-run',
            'job-terminal jobId=$jobId state=${snapshot.state.name} error=${snapshot.error}',
          );
          state = _idleState(
            items: _buildItemsForSnapshot(snapshot),
            globalError: snapshot.error?.toString(),
          );
          _activeInputPaths = const <String>[];
          return;
        }
      } on Object catch (error) {
        if (state.jobId != jobId) {
          return;
        }

        await _disposeJob(jobId);
        DeveloperDiagnostics.logTimingError('optimize-run', error);
        state = _idleState(
          items: state.items,
          globalError: error.toString(),
        );
        _activeInputPaths = const <String>[];
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> _applySnapshot(String jobId, BatchJobSnapshot snapshot) async {
    final newResults = snapshot.results.skip(state.appliedResultCount).toList();
    if (newResults.isNotEmpty) {
      for (final item in newResults) {
        DeveloperDiagnostics.logTiming(
          'optimize-run',
          'result input=${item.inputPath} success=${item.success} error=${item.error} output=${item.result?.outputPath} didWrite=${item.result?.didWrite}',
        );
      }
      await ref.read(fileOpenControllerProvider).applyProcessResults(newResults);
      if (state.jobId != jobId) {
        return;
      }
    }

    state = state.copyWith(
      jobState: snapshot.state,
      completedCount: snapshot.completedCount,
      totalCount: snapshot.totalCount,
      currentInputPath: snapshot.currentInputPath,
      appliedResultCount: snapshot.results.length,
      items: _buildItemsForSnapshot(snapshot),
      globalError: snapshot.error?.toString(),
      clearGlobalError: snapshot.error == null,
      clearCurrentInputPath: snapshot.currentInputPath == null,
    );
  }

  Map<String, OptimizationItemState> _buildItemsForSnapshot(
    BatchJobSnapshot snapshot,
  ) {
    final nextItems = <String, OptimizationItemState>{
      for (final path in _activeInputPaths)
        path: const OptimizationItemState(status: OptimizationItemStatus.queued),
    };
    final completedInputs = <String>{};

    for (final item in snapshot.results) {
      completedInputs.add(item.inputPath);
      nextItems.remove(item.inputPath);

      if (!item.success || item.result == null) {
        nextItems[item.inputPath] = OptimizationItemState(
          status: OptimizationItemStatus.failed,
          message: item.error?.toString() ?? 'Failed',
        );
        continue;
      }

      final result = item.result!;
      nextItems[result.outputPath] = OptimizationItemState(
        status: result.didWrite
            ? OptimizationItemStatus.written
            : OptimizationItemStatus.skipped,
        result: result,
      );
    }

    if (snapshot.currentInputPath case final currentPath?) {
      nextItems[currentPath] = const OptimizationItemState(
        status: OptimizationItemStatus.running,
      );
    }

    if (snapshot.state == BatchJobState.canceled) {
      for (final path in _activeInputPaths) {
        if (!completedInputs.contains(path)) {
          nextItems[path] = const OptimizationItemState(
            status: OptimizationItemStatus.canceled,
          );
        }
      }
    }

    return nextItems;
  }

  OptimizationRunState _idleState({
    required Map<String, OptimizationItemState> items,
    String? globalError,
  }) {
    return OptimizationRunState(
      items: items,
      globalError: globalError,
    );
  }

  Future<void> _disposeJob(String jobId) async {
    try {
      await ref.read(slimgApiProvider).disposeProcessFileBatchJob(jobId: jobId);
    } on Object {
      // The job is already terminal in the UI path; disposal failures are non-fatal.
    }
  }
}

bool _isTerminalJobState(BatchJobState state) {
  return switch (state) {
    BatchJobState.completed ||
    BatchJobState.canceled ||
    BatchJobState.failed => true,
    BatchJobState.running || BatchJobState.cancelRequested => false,
  };
}
