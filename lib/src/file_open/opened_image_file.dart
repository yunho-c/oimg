import 'package:oimg/src/rust/types.dart';

class OpenedImageFile {
  const OpenedImageFile({
    required this.path,
    required this.metadata,
    this.lastResult,
    this.lastError,
  });

  final String path;
  final ImageMetadata metadata;
  final ProcessResult? lastResult;
  final String? lastError;

  OpenedImageFile copyWith({
    String? path,
    ImageMetadata? metadata,
    ProcessResult? lastResult,
    String? lastError,
    bool clearLastResult = false,
    bool clearLastError = false,
  }) {
    return OpenedImageFile(
      path: path ?? this.path,
      metadata: metadata ?? this.metadata,
      lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}
