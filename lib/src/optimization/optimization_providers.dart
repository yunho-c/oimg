import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oimg/src/file_open/file_open_providers.dart';
import 'package:oimg/src/file_open/opened_image_file.dart';
import 'package:oimg/src/rust/slimg_api.dart';
import 'package:oimg/src/rust/types.dart';
import 'package:oimg/src/settings/app_settings_controller.dart';

import 'optimization_plan.dart';

final slimgApiProvider = Provider<SlimgApi>((ref) => const FrbSlimgApi());

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
  final controller = ref.watch(fileOpenControllerProvider);
  final currentFile = controller.currentFile;
  if (currentFile == null) {
    return null;
  }

  final settings = await ref.watch(appSettingsProvider.future);
  final plan = buildOptimizationPlan(file: currentFile, settings: settings);

  await Future<void>.delayed(const Duration(milliseconds: 150));

  final result = await ref
      .read(slimgApiProvider)
      .previewFile(request: plan.previewRequest);

  return OptimizationPreview(
    sourceFile: currentFile,
    plan: plan,
    result: result,
  );
});

enum OptimizationItemStatus { idle, running, written, skipped, failed }

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
    this.isRunning = false,
    this.items = const {},
    this.globalError,
  });

  final bool isRunning;
  final Map<String, OptimizationItemState> items;
  final String? globalError;

  OptimizationRunState copyWith({
    bool? isRunning,
    Map<String, OptimizationItemState>? items,
    String? globalError,
    bool clearGlobalError = false,
  }) {
    return OptimizationRunState(
      isRunning: isRunning ?? this.isRunning,
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

  Future<void> _run(List<OpenedImageFile> files) async {
    if (state.isRunning) {
      return;
    }

    final settings = await ref.read(appSettingsProvider.future);
    final requests = files
        .map((file) => buildOptimizationPlan(file: file, settings: settings))
        .map((plan) => plan.processRequest)
        .toList(growable: false);

    state = OptimizationRunState(
      isRunning: true,
      items: {
        for (final file in files)
          file.path: const OptimizationItemState(
            status: OptimizationItemStatus.running,
          ),
      },
    );

    try {
      final results = await ref
          .read(slimgApiProvider)
          .processFileBatch(
            request: ProcessFileBatchRequest(
              requests: requests,
              continueOnError: true,
            ),
          );

      await ref.read(fileOpenControllerProvider).applyProcessResults(results);

      final nextItems = <String, OptimizationItemState>{};
      for (final item in results) {
        if (!item.success || item.result == null) {
          nextItems[item.inputPath] = OptimizationItemState(
            status: OptimizationItemStatus.failed,
            message: item.error?.toString() ?? 'Failed',
          );
          continue;
        }

        final result = item.result!;
        final key = result.outputPath;
        nextItems[key] = OptimizationItemState(
          status: result.didWrite
              ? OptimizationItemStatus.written
              : OptimizationItemStatus.skipped,
          result: result,
        );
      }

      state = OptimizationRunState(isRunning: false, items: nextItems);
    } on Object catch (error) {
      state = OptimizationRunState(
        isRunning: false,
        items: state.items,
        globalError: error.toString(),
      );
    }
  }
}
