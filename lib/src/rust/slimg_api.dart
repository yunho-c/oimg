import 'package:oimg/src/settings/developer_diagnostics.dart';

import 'slimg_bridge.dart';

abstract class SlimgApi {
  const SlimgApi();

  Future<ImageMetadata> inspectFile({required String inputPath});

  void setTimingLogsEnabled({required bool enabled});

  Future<PreviewResult> previewFile({required PreviewFileRequest request});

  Future<ProcessResult> processFile({required ProcessFileRequest request});

  Future<List<BatchItemResult>> processFileBatch({
    required ProcessFileBatchRequest request,
  });
}

class FrbSlimgApi implements SlimgApi {
  const FrbSlimgApi({SlimgBridge? bridge})
    : _bridge = bridge ?? const SlimgBridge();

  final SlimgBridge _bridge;

  @override
  Future<ImageMetadata> inspectFile({required String inputPath}) {
    return _bridge.inspectFile(inputPath: inputPath);
  }

  @override
  void setTimingLogsEnabled({required bool enabled}) {
    _bridge.setTimingLogsEnabled(enabled: enabled);
  }

  @override
  Future<PreviewResult> previewFile({required PreviewFileRequest request}) {
    final stopwatch = Stopwatch()..start();
    DeveloperDiagnostics.logTiming(
      'slimg-api',
      'preview start path=${request.inputPath}',
    );
    return _bridge
        .previewFile(request: request)
        .then(
          (result) {
            stopwatch.stop();
            DeveloperDiagnostics.logTiming(
              'slimg-api',
              'preview done path=${request.inputPath} total=${stopwatch.elapsedMilliseconds}ms format=${result.format} size=${result.sizeBytes}',
            );
            return result;
          },
          onError: (Object error, StackTrace stackTrace) {
            stopwatch.stop();
            DeveloperDiagnostics.logTimingError('slimg-api', error, stackTrace);
            throw error;
          },
        );
  }

  @override
  Future<ProcessResult> processFile({required ProcessFileRequest request}) {
    return _bridge.processFile(request: request);
  }

  @override
  Future<List<BatchItemResult>> processFileBatch({
    required ProcessFileBatchRequest request,
  }) {
    return _bridge.processFileBatch(request: request);
  }
}
