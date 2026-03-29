import 'slimg_bridge.dart';

abstract class SlimgApi {
  const SlimgApi();

  Future<ImageMetadata> inspectFile({required String inputPath});

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
  Future<PreviewResult> previewFile({required PreviewFileRequest request}) {
    return _bridge.previewFile(request: request);
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
