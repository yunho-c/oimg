import 'package:oimg/src/file_open/opened_image_file.dart';
import 'package:oimg/src/rust/types.dart';
import 'package:oimg/src/settings/app_settings.dart';

class OptimizationPlan {
  const OptimizationPlan({
    required this.sourceFile,
    required this.targetCodec,
    required this.processRequest,
    required this.previewRequest,
  });

  final OpenedImageFile sourceFile;
  final PreferredCodec targetCodec;
  final ProcessFileRequest processRequest;
  final PreviewFileRequest previewRequest;

  bool get usesSourceCodec => sourceFile.metadata.format == codecIdOf(targetCodec);
}

OptimizationPlan buildOptimizationPlan({
  required OpenedImageFile file,
  required AppSettings settings,
}) {
  final targetCodec = settings.effectiveCodec;
  final targetFormat = codecIdOf(targetCodec);
  final usesSourceCodec = file.metadata.format == targetFormat;
  final operation = usesSourceCodec
      ? ImageOperation.optimize(
          OptimizeOptions(
            quality: settings.quality,
            writeOnlyIfSmaller: true,
          ),
        )
      : ImageOperation.convert(
          ConvertOptions(targetFormat: targetFormat, quality: settings.quality),
        );

  return OptimizationPlan(
    sourceFile: file,
    targetCodec: targetCodec,
    processRequest: ProcessFileRequest(
      inputPath: file.path,
      outputPath: usesSourceCodec
          ? null
          : _optimizedSiblingPath(file.path, targetFormat),
      overwrite: true,
      operation: operation,
    ),
    previewRequest: PreviewFileRequest(inputPath: file.path, operation: operation),
  );
}

String codecIdOf(PreferredCodec codec) {
  return switch (codec) {
    PreferredCodec.png => 'png',
    PreferredCodec.jpeg => 'jpeg',
    PreferredCodec.webp => 'webp',
    PreferredCodec.avif => 'avif',
    PreferredCodec.jxl => 'jxl',
  };
}

String codecLabel(PreferredCodec codec) {
  return switch (codec) {
    PreferredCodec.png => 'PNG',
    PreferredCodec.jpeg => 'JPEG',
    PreferredCodec.webp => 'WebP',
    PreferredCodec.avif => 'AVIF',
    PreferredCodec.jxl => 'JPEG XL',
  };
}

PreferredCodec? codecFromFormatId(String format) {
  for (final codec in PreferredCodec.values) {
    if (codecIdOf(codec) == format) {
      return codec;
    }
  }
  return null;
}

String formatLabel(String format) {
  final codec = codecFromFormatId(format);
  if (codec != null) {
    return codecLabel(codec);
  }
  return format.toUpperCase();
}

String _optimizedSiblingPath(String path, String targetFormat) {
  final normalized = path.replaceAll('\\', '/');
  final slash = normalized.lastIndexOf('/');
  final directory = slash >= 0 ? normalized.substring(0, slash + 1) : '';
  final fileName = slash >= 0 ? normalized.substring(slash + 1) : normalized;
  final dot = fileName.lastIndexOf('.');
  final stem = dot > 0 ? fileName.substring(0, dot) : fileName;
  return '$directory$stem.optimized.$targetFormat';
}
