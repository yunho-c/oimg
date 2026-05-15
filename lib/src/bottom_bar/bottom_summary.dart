part of 'package:oimg/main.dart';

class _BottomSummaryViewModel {
  const _BottomSummaryViewModel({
    required this.stats,
    required this.originalSectionTitle,
    required this.originalRows,
    required this.outputSectionTitle,
    required this.outputRows,
  });

  final List<_BottomStatData> stats;
  final String originalSectionTitle;
  final List<_BottomInfoRowData> originalRows;
  final String outputSectionTitle;
  final List<_BottomInfoRowData> outputRows;

  static _BottomSummaryViewModel build({
    required FileOpenController controller,
    required OpenedImageFile currentFile,
    required OptimizationRunState runState,
    required OptimizationPreview? preview,
    required AnalyzeSampleResult? analyzeSample,
    required bool isPreviewPending,
    required OptimizationPlan? plan,
    required AppSettings? settings,
    required AsyncValue<PreviewMetricResult?> pixelMatchMetric,
    required AsyncValue<PreviewMetricResult?> msSsimMetric,
    required AsyncValue<PreviewMetricResult?> ssimulacra2Metric,
  }) {
    if (controller.isFolderSelected) {
      return _buildFolder(
        controller: controller,
        runState: runState,
        settings: settings,
      );
    }

    return _buildFile(
      file: currentFile,
      runState: runState,
      preview: preview,
      analyzeSample: analyzeSample,
      isPreviewPending: isPreviewPending,
      plan: plan,
      pixelMatchMetric: pixelMatchMetric,
      msSsimMetric: msSsimMetric,
      ssimulacra2Metric: ssimulacra2Metric,
    );
  }

  static _BottomSummaryViewModel _buildFile({
    required OpenedImageFile file,
    required OptimizationRunState runState,
    required OptimizationPreview? preview,
    required AnalyzeSampleResult? analyzeSample,
    required bool isPreviewPending,
    required OptimizationPlan? plan,
    required AsyncValue<PreviewMetricResult?> pixelMatchMetric,
    required AsyncValue<PreviewMetricResult?> msSsimMetric,
    required AsyncValue<PreviewMetricResult?> ssimulacra2Metric,
  }) {
    final originalBytes = _originalFileSizeBytes(file);
    final hasSavedResult = file.lastResult != null;
    final isOptimizedPreviewPending =
        analyzeSample == null &&
        preview == null &&
        isPreviewPending &&
        !hasSavedResult;
    final newBytes =
        analyzeSample?.sizeBytes.toInt() ??
        preview?.result.sizeBytes.toInt() ??
        (isOptimizedPreviewPending ? null : _effectiveFileSizeBytes(file));
    final originalBpp = _bitsPerPixel(
      bytes: originalBytes,
      width: file.metadata.width,
      height: file.metadata.height,
    );
    final optimizedBpp = _bitsPerPixel(
      bytes: newBytes,
      width:
          analyzeSample?.width ??
          preview?.result.width ??
          file.lastResult?.width ??
          file.metadata.width,
      height:
          analyzeSample?.height ??
          preview?.result.height ??
          file.lastResult?.height ??
          file.metadata.height,
    );
    final savingsBytes = originalBytes != null && newBytes != null
        ? originalBytes - newBytes
        : null;
    final savingsPercent =
        originalBytes != null && originalBytes > 0 && savingsBytes != null
        ? (savingsBytes / originalBytes) * 100
        : null;
    final outputFormat =
        analyzeSample?.format ??
        file.lastResult?.format ??
        (plan == null ? null : codecIdOf(plan.targetCodec));
    final optimizedTimingTooltip = analyzeSample == null && preview != null
        ? _formatMetricTimingTooltip(preview.elapsedMilliseconds)
        : null;
    final similarityStat = _deriveSimilarityStat(
      analyzeSample: analyzeSample,
      pixelMatchMetric: pixelMatchMetric,
      msSsimMetric: msSsimMetric,
      ssimulacra2Metric: ssimulacra2Metric,
    );
    return _BottomSummaryViewModel(
      stats: [
        _BottomStatData(
          label: 'Original',
          value: _formatNullableBytes(originalBytes),
          numericValue: originalBytes,
          numericFormatter: _formatByteTickerValue,
          color: const Color(0xFF6B7280),
          colorMode: _BottomStatColorMode.fileSize,
          colorScore: originalBpp,
        ),
        _BottomStatData(
          label: 'Optimized',
          value: _formatNullableBytes(newBytes),
          numericValue: newBytes,
          numericFormatter: _formatByteTickerValue,
          color: const Color(0xFF2563EB),
          colorMode: _BottomStatColorMode.fileSize,
          colorScore: optimizedBpp,
          loading: isOptimizedPreviewPending,
          pending: isOptimizedPreviewPending,
          tooltip: optimizedTimingTooltip,
        ),
        _BottomStatData(
          label: 'Savings',
          value: _formatNullablePercentValue(savingsPercent),
          alternateValue: _formatSavingsRatio(originalBytes, newBytes),
          numericValue: savingsPercent,
          numericFormatter: _formatPercentTickerValue,
          alternateNumericValue: _savingsRatio(originalBytes, newBytes),
          alternateNumericFormatter: _formatSavingsRatioTickerValue,
          color: const Color(0xFF16A34A),
          colorMode: _BottomStatColorMode.savings,
          colorScore: savingsPercent?.clamp(0, 400).toDouble(),
          pending: isOptimizedPreviewPending,
          toggleable: true,
        ),
        _BottomStatData(
          label: 'Similarity',
          value: similarityStat.value,
          numericValue: similarityStat.score,
          numericFormatter: similarityStat.numericFormatter,
          color: Color(0xFFF59E0B),
          colorMode: _BottomStatColorMode.similarity,
          colorScore: similarityStat.score,
          pending: similarityStat.pending,
        ),
      ],
      originalSectionTitle: 'Original',
      originalRows: [
        _BottomInfoRowData(
          label: 'Format',
          value: formatLabel(file.metadata.format),
        ),
        _BottomInfoRowData(
          label: 'Bits Per Pixel',
          value: _formatNullableBpp(originalBpp),
          key: 'original-bpp-value',
          rowKey: 'original-bpp-row',
          bitsPerPixelValue: originalBpp,
          supportsBitsPerPixelColors: true,
        ),
      ],
      outputSectionTitle: 'Optimized',
      outputRows: [
        _BottomInfoRowData(
          label: 'Format',
          value: outputFormat == null ? '—' : formatLabel(outputFormat),
          key: 'optimized-format-value',
          highlightOnValueChange: true,
        ),
        _BottomInfoRowData(
          label: 'Bits Per Pixel',
          value: _formatNullableBpp(optimizedBpp),
          key: 'optimized-bpp-value',
          rowKey: 'optimized-bpp-row',
          bitsPerPixelValue: optimizedBpp,
          supportsBitsPerPixelColors: true,
        ),
      ],
    );
  }

  static _BottomSummaryViewModel _buildFolder({
    required FileOpenController controller,
    required OptimizationRunState runState,
    required AppSettings? settings,
  }) {
    final files = controller.selectedFolderFiles;
    final originalBytes = _aggregateFolderBytes(files, useOriginalSizes: true);
    final newBytes = _aggregateFolderBytes(files, useOriginalSizes: false);
    final originalBpp = _aggregateFolderBpp(files, useOriginalSizes: true);
    final optimizedBpp = _aggregateFolderBpp(files, useOriginalSizes: false);
    final savingsBytes = originalBytes != null && newBytes != null
        ? originalBytes - newBytes
        : null;
    final savingsPercent =
        originalBytes != null && originalBytes > 0 && savingsBytes != null
        ? (savingsBytes / originalBytes) * 100
        : null;
    final completedCount = files
        .where(
          (file) => _isTerminalStatus(_statusForFile(file, runState).status),
        )
        .length;

    return _BottomSummaryViewModel(
      stats: [
        _BottomStatData(
          label: 'Original',
          value: _formatNullableBytes(originalBytes),
          numericValue: originalBytes,
          numericFormatter: _formatByteTickerValue,
          color: const Color(0xFF6B7280),
          colorMode: _BottomStatColorMode.fileSize,
          colorScore: originalBpp,
        ),
        _BottomStatData(
          label: 'Optimized',
          value: _formatNullableBytes(newBytes),
          numericValue: newBytes,
          numericFormatter: _formatByteTickerValue,
          color: const Color(0xFF2563EB),
          colorMode: _BottomStatColorMode.fileSize,
          colorScore: optimizedBpp,
        ),
        _BottomStatData(
          label: 'Savings',
          value: _formatNullablePercentValue(savingsPercent),
          alternateValue: _formatSavingsRatio(originalBytes, newBytes),
          numericValue: savingsPercent,
          numericFormatter: _formatPercentTickerValue,
          alternateNumericValue: _savingsRatio(originalBytes, newBytes),
          alternateNumericFormatter: _formatSavingsRatioTickerValue,
          color: const Color(0xFF16A34A),
          colorMode: _BottomStatColorMode.savings,
          colorScore: savingsPercent?.clamp(0, 400).toDouble(),
          toggleable: true,
        ),
        const _BottomStatData(
          label: 'Similarity',
          value: 'N/A',
          color: Color(0xFFF59E0B),
        ),
      ],
      originalSectionTitle: 'Original',
      originalRows: [
        _BottomInfoRowData(
          label: 'Folder',
          value:
              controller.selectedFolderName ??
              controller.selectedFolderPath ??
              'Unknown',
        ),
        _BottomInfoRowData(label: 'Images', value: '${files.length}'),
        _BottomInfoRowData(
          label: 'Bits Per Pixel',
          value: _formatNullableBpp(originalBpp),
          key: 'original-bpp-value',
          rowKey: 'original-bpp-row',
          bitsPerPixelValue: originalBpp,
          supportsBitsPerPixelColors: true,
        ),
      ],
      outputSectionTitle: 'Optimized',
      outputRows: [
        _BottomInfoRowData(
          label: 'Target',
          value: settings == null ? '—' : codecLabel(settings.effectiveCodec),
        ),
        _BottomInfoRowData(
          label: 'Completed',
          value: '$completedCount / ${files.length}',
        ),
        _BottomInfoRowData(
          label: 'Bits Per Pixel',
          value: _formatNullableBpp(optimizedBpp),
          key: 'optimized-bpp-value',
          rowKey: 'optimized-bpp-row',
          bitsPerPixelValue: optimizedBpp,
          supportsBitsPerPixelColors: true,
        ),
      ],
    );
  }
}

class _DerivedSimilarityStat {
  const _DerivedSimilarityStat({
    required this.value,
    required this.loading,
    this.pending = false,
    this.score,
    this.numericFormatter,
  });

  final String value;
  final bool loading;
  final bool pending;
  final double? score;
  final String Function(num value)? numericFormatter;
}

_DerivedSimilarityStat _deriveSimilarityStat({
  AnalyzeSampleResult? analyzeSample,
  required AsyncValue<PreviewMetricResult?> pixelMatchMetric,
  required AsyncValue<PreviewMetricResult?> msSsimMetric,
  required AsyncValue<PreviewMetricResult?> ssimulacra2Metric,
}) {
  if (analyzeSample != null) {
    final normalizedValues = <double>[
      if (analyzeSample.pixelMatch case final pixelMatch?)
        pixelMatch.clamp(0, 100).toDouble(),
      if (analyzeSample.msSsim case final msSsim?)
        (msSsim * 100).clamp(0, 100).toDouble(),
      if (analyzeSample.ssimulacra2 case final ssimulacra2?)
        ssimulacra2.clamp(0, 100).toDouble(),
    ];

    if (normalizedValues.isNotEmpty) {
      final average =
          normalizedValues.reduce((sum, value) => sum + value) /
          normalizedValues.length;
      return _DerivedSimilarityStat(
        value: _formatSimilarityPercentValue(average),
        loading: false,
        score: average,
        numericFormatter: _formatSimilarityTickerValue,
      );
    }
  }

  final normalizedValues = <double>[
    ..._normalizedSimilarityValues(
      pixelMatchMetric,
      transform: (value) => value.clamp(0, 100).toDouble(),
    ),
    ..._normalizedSimilarityValues(
      msSsimMetric,
      transform: (value) => (value * 100).clamp(0, 100).toDouble(),
    ),
    ..._normalizedSimilarityValues(
      ssimulacra2Metric,
      transform: (value) => value.clamp(0, 100).toDouble(),
    ),
  ];

  if (normalizedValues.isNotEmpty) {
    final average =
        normalizedValues.reduce((sum, value) => sum + value) /
        normalizedValues.length;
    final isLoading =
        pixelMatchMetric.isLoading ||
        msSsimMetric.isLoading ||
        ssimulacra2Metric.isLoading;
    return _DerivedSimilarityStat(
      value: '${isLoading ? '~' : ''}${_formatSimilarityPercentValue(average)}',
      loading: false,
      score: average,
      numericFormatter: isLoading
          ? _formatApproximateSimilarityTickerValue
          : _formatSimilarityTickerValue,
    );
  }

  final isLoading =
      pixelMatchMetric.isLoading ||
      msSsimMetric.isLoading ||
      ssimulacra2Metric.isLoading;
  return _DerivedSimilarityStat(
    value: isLoading ? '—' : 'N/A',
    loading: false,
    pending: isLoading,
  );
}

Iterable<double> _normalizedSimilarityValues(
  AsyncValue<PreviewMetricResult?> metric, {
  required double Function(double value) transform,
}) sync* {
  final result = metric.asData?.value;
  final value = result?.value;
  if (value == null) {
    return;
  }
  yield transform(value);
}

class _BottomStatData {
  const _BottomStatData({
    required this.label,
    required this.value,
    required this.color,
    this.alternateValue,
    this.numericValue,
    this.numericFormatter,
    this.alternateNumericValue,
    this.alternateNumericFormatter,
    this.colorScore,
    this.colorMode = _BottomStatColorMode.none,
    this.loading = false,
    this.pending = false,
    this.toggleable = false,
    this.tooltip,
  });

  final String label;
  final String value;
  final Color color;
  final String? alternateValue;
  final num? numericValue;
  final String Function(num value)? numericFormatter;
  final num? alternateNumericValue;
  final String Function(num value)? alternateNumericFormatter;
  final double? colorScore;
  final _BottomStatColorMode colorMode;
  final bool loading;
  final bool pending;
  final bool toggleable;
  final String? tooltip;
}

enum _BottomStatColorMode { none, fileSize, similarity, savings }

class _BottomInfoRowData {
  const _BottomInfoRowData({
    required this.label,
    required this.value,
    this.key,
    this.rowKey,
    this.bitsPerPixelValue,
    this.supportsBitsPerPixelColors = false,
    this.highlightOnValueChange = false,
  });

  final String label;
  final String value;
  final String? key;
  final String? rowKey;
  final double? bitsPerPixelValue;
  final bool supportsBitsPerPixelColors;
  final bool highlightOnValueChange;
}

int? _effectiveFileSizeBytes(OpenedImageFile file) {
  return file.lastResult?.newSize.toInt() ?? file.metadata.fileSize?.toInt();
}

int? _originalFileSizeBytes(OpenedImageFile file) {
  return file.lastResult?.originalSize.toInt() ??
      file.metadata.fileSize?.toInt();
}

int? _aggregateFolderBytes(
  List<OpenedImageFile> files, {
  required bool useOriginalSizes,
}) {
  var hasSize = false;
  var totalBytes = 0;

  for (final file in files) {
    final bytes = useOriginalSizes
        ? _originalFileSizeBytes(file)
        : _effectiveFileSizeBytes(file);
    if (bytes == null) {
      continue;
    }
    hasSize = true;
    totalBytes += bytes;
  }

  return hasSize ? totalBytes : null;
}

double? _aggregateFolderBpp(
  List<OpenedImageFile> files, {
  required bool useOriginalSizes,
}) {
  var totalBytes = 0;
  var totalPixels = 0;

  for (final file in files) {
    final bytes = useOriginalSizes
        ? _originalFileSizeBytes(file)
        : _effectiveFileSizeBytes(file);
    final width = useOriginalSizes
        ? file.metadata.width
        : (file.lastResult?.width ?? file.metadata.width);
    final height = useOriginalSizes
        ? file.metadata.height
        : (file.lastResult?.height ?? file.metadata.height);
    if (bytes == null || width <= 0 || height <= 0) {
      continue;
    }

    totalBytes += bytes;
    totalPixels += width * height;
  }

  if (totalBytes <= 0 || totalPixels <= 0) {
    return null;
  }

  return (totalBytes * 8) / totalPixels;
}

double? _bitsPerPixel({
  required int? bytes,
  required int width,
  required int height,
}) {
  if (bytes == null || bytes <= 0 || width <= 0 || height <= 0) {
    return null;
  }

  return (bytes * 8) / (width * height);
}

String _formatNullableBytes(int? bytes) {
  if (bytes == null) {
    return '—';
  }
  return _formatBytes(bytes);
}

String _formatByteTickerValue(num value) {
  return _formatBytes(value.round());
}

String? _formatNullablePercent(double? value) {
  if (value == null) {
    return null;
  }
  if (value.toStringAsFixed(1) == '100.0') {
    return '100%';
  }
  return '${value.toStringAsFixed(1)}%';
}

String _formatNullablePercentValue(double? value) {
  return _formatNullablePercent(value) ?? '—';
}

String _formatPercentTickerValue(num value) {
  return _formatNullablePercent(value.toDouble()) ?? '—';
}

String _formatSimilarityPercentValue(double? value) {
  if (value == null) {
    return '—';
  }

  final rounded = value.toStringAsFixed(1);
  if (rounded == '100.0') {
    return '100%';
  }

  return '$rounded%';
}

String _formatSimilarityTickerValue(num value) {
  return _formatSimilarityPercentValue(value.toDouble());
}

String _formatApproximateSimilarityTickerValue(num value) {
  return '~${_formatSimilarityTickerValue(value)}';
}

String _formatNullableBpp(double? value) {
  if (value == null) {
    return '—';
  }

  return value >= 10 ? value.toStringAsFixed(1) : value.toStringAsFixed(2);
}

String _formatNullableMetric(
  double? value, {
  int digits = 3,
  bool trimIfHundred = false,
  bool trimIfOne = false,
}) {
  if (value == null) {
    return 'N/A';
  }

  final formatted = value.toStringAsFixed(digits);
  if (trimIfOne) {
    final wholeOne = '1.${'0' * digits}';
    if (formatted == wholeOne && digits > 0) {
      return '1.${'0' * (digits - 1)}';
    }
  }
  if (trimIfHundred) {
    final wholeHundred = '100.${'0' * digits}';
    if (formatted == wholeHundred) {
      return '100';
    }
  }
  return formatted;
}

String _formatNullableMetricPercent(double? value) {
  return _formatNullablePercent(value) ?? 'N/A';
}

String _formatSavingsRatio(int? originalBytes, int? newBytes) {
  final ratio = _savingsRatio(originalBytes, newBytes);
  if (ratio == null) {
    return '—';
  }

  return _formatSavingsRatioTickerValue(ratio);
}

double? _savingsRatio(int? originalBytes, int? newBytes) {
  if (originalBytes == null ||
      newBytes == null ||
      originalBytes <= 0 ||
      newBytes <= 0) {
    return null;
  }

  return originalBytes / newBytes;
}

String _formatSavingsRatioTickerValue(num value) {
  return '${value.toStringAsFixed(1)}x';
}

String _formatMetricTimingTooltip(int elapsedMilliseconds) {
  if (elapsedMilliseconds >= 1000) {
    final seconds = elapsedMilliseconds / 1000;
    return '${seconds.toStringAsFixed(1)} s';
  }

  return '$elapsedMilliseconds ms';
}

String _formatOptimizeProgressTime({
  required Duration elapsed,
  required Duration? estimate,
}) {
  return '${_formatProgressDuration(elapsed)}/${estimate == null ? '--:--' : _formatProgressDuration(estimate)}';
}

String _formatProgressDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String _formatMegapixels(int width, int height) {
  final megapixels = (width * height) / 1000000;
  return '${megapixels.toStringAsFixed(1)} MP';
}

bool _isAnalyzeSelectionEvent(FlTouchEvent event) {
  return event.isInterestedForInteractions;
}

bool _isAnalyzeCommitEvent(FlTouchEvent event) {
  return event is FlTapDownEvent;
}

bool _isTerminalStatus(OptimizationItemStatus status) {
  return switch (status) {
    OptimizationItemStatus.written ||
    OptimizationItemStatus.skipped ||
    OptimizationItemStatus.failed ||
    OptimizationItemStatus.canceled => true,
    OptimizationItemStatus.idle ||
    OptimizationItemStatus.queued ||
    OptimizationItemStatus.running => false,
  };
}

OptimizationItemState _statusForFile(
  OpenedImageFile file,
  OptimizationRunState runState,
) {
  final direct = runState.items[file.path];
  if (direct != null) {
    return direct;
  }

  if (file.lastError != null) {
    return OptimizationItemState(
      status: OptimizationItemStatus.failed,
      message: file.lastError,
    );
  }

  if (file.lastResult != null) {
    return OptimizationItemState(
      status: file.lastResult!.didWrite
          ? OptimizationItemStatus.written
          : OptimizationItemStatus.skipped,
      result: file.lastResult,
    );
  }

  return const OptimizationItemState(status: OptimizationItemStatus.idle);
}
