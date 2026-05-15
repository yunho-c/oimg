part of 'package:oimg/main.dart';

class _AnalyzePanel extends ConsumerWidget {
  const _AnalyzePanel({required this.state});

  final AnalyzeRunState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(analyzeRunControllerProvider.notifier);
    final displayMode = ref.watch(currentPreviewDisplayModeProvider);
    final selectedAnalyzeSample = ref.watch(selectedAnalyzeSampleProvider);
    final fileController = ref.watch(fileOpenControllerProvider);
    final currentFilePath = fileController.currentPath;
    final currentFile = fileController.currentFile;
    final samples = [...state.samples]
      ..sort((a, b) => a.sizeBytes.compareTo(b.sizeBytes));
    final qualityIndicator = state.isRunning
        ? state.currentQuality
        : selectedAnalyzeSample?.quality;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.2),
        borderRadius: theme.borderRadiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Analyze',
                  style: TextStyle(
                    color: theme.colorScheme.mutedForeground,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ).xSmall(),
              ),
              if (qualityIndicator case final quality?)
                Text('Q$quality').xSmall().muted(),
            ],
          ),
          const SizedBox(height: 8),
          if (state.isRunning || samples.isNotEmpty) ...[
            Expanded(
              child: samples.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _AnalyzeChart(
                      samples: samples,
                      originalSizeBytes: state.isRunning
                          ? null
                          : currentFile?.metadata.fileSize?.toDouble(),
                      selectedArtifactId: state.activeArtifactId,
                      onHoverSample: (sample) {
                        controller.hoverSample(sample);
                        if (currentFilePath != null) {
                          ref
                              .read(previewDisplaySelectionProvider.notifier)
                              .select(
                                filePath: currentFilePath,
                                mode: displayMode,
                              );
                        }
                        if (displayMode == PreviewDisplayMode.difference) {
                          ref
                              .read(previewDifferenceRequestProvider.notifier)
                              .requestForArtifact(sample.artifactId);
                        }
                      },
                      onCommitSample: (sample) {
                        controller.selectSample(sample);
                        if (currentFilePath != null) {
                          ref
                              .read(previewDisplaySelectionProvider.notifier)
                              .select(
                                filePath: currentFilePath,
                                mode: displayMode,
                              );
                        }
                        if (displayMode == PreviewDisplayMode.difference) {
                          ref
                              .read(previewDifferenceRequestProvider.notifier)
                              .requestForArtifact(sample.artifactId);
                        }
                        unawaited(
                          ref
                              .read(appSettingsProvider.notifier)
                              .setQuality(sample.quality),
                        );
                      },
                      onExitChart: () {
                        final activeSample = controller.clearHoveredSample();
                        if (displayMode == PreviewDisplayMode.difference &&
                            activeSample != null) {
                          ref
                              .read(previewDifferenceRequestProvider.notifier)
                              .requestForArtifact(activeSample.artifactId);
                        }
                      },
                    ),
            ),
          ],
          if (state.globalError case final error?) ...[
            const SizedBox(height: 8),
            Text(error).xSmall().muted(),
          ],
        ],
      ),
    );
  }
}

class _AnalyzeChart extends StatefulWidget {
  const _AnalyzeChart({
    required this.samples,
    required this.originalSizeBytes,
    required this.selectedArtifactId,
    required this.onHoverSample,
    required this.onCommitSample,
    required this.onExitChart,
  });

  final List<AnalyzeSampleResult> samples;
  final double? originalSizeBytes;
  final String? selectedArtifactId;
  final ValueChanged<AnalyzeSampleResult> onHoverSample;
  final ValueChanged<AnalyzeSampleResult> onCommitSample;
  final VoidCallback onExitChart;

  @override
  State<_AnalyzeChart> createState() => _AnalyzeChartState();
}

class _AnalyzeChartState extends State<_AnalyzeChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _selectionPulseController;

  @override
  void initState() {
    super.initState();
    _selectionPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1,
    );
  }

  @override
  void dispose() {
    _selectionPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pixelMatchPoints = _metricPoints(
      widget.samples,
      (sample) => sample.pixelMatch,
    );
    final msSsimPoints = _metricPoints(
      widget.samples,
      (sample) => sample.msSsim == null ? null : sample.msSsim! * 100,
    );
    final ssimulacra2Points = _metricPoints(
      widget.samples,
      (sample) => sample.ssimulacra2,
    );
    final dataMaxX = widget.samples.fold<double>(
      0,
      (current, sample) => math.max(current, sample.sizeBytes.toDouble()),
    );
    final originalMarkerX = widget.originalSizeBytes;
    final visibleMaxX = math.max(dataMaxX, originalMarkerX ?? 0);
    final chartMaxX = visibleMaxX <= 0 ? 1.0 : visibleMaxX * 1.05;
    final xAxisInterval = visibleMaxX <= 0 ? 1.0 : visibleMaxX / 4;
    final originalSizeLineColor = const Color(0xFFD11A2A);
    final originalSizeOverlayColor = originalSizeLineColor.withValues(
      alpha: 0.08,
    );

    return MouseRegion(
      key: const ValueKey('analyze-chart-region'),
      onExit: (_) => widget.onExitChart(),
      child: AnimatedBuilder(
        animation: _selectionPulseController,
        builder: (context, child) {
          final selectedPulse = math
              .sin(_selectionPulseController.value * math.pi)
              .clamp(0.0, 1.0);
          return LineChart(
            LineChartData(
              minY: 0,
              maxY: 100,
              minX: 0,
              maxX: chartMaxX,
              gridData: FlGridData(
                drawVerticalLine: true,
                horizontalInterval: 20,
                verticalInterval: xAxisInterval,
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: theme.colorScheme.border, strokeWidth: 1),
                getDrawingVerticalLine: (value) => FlLine(
                  color: theme.colorScheme.border.withValues(alpha: 0.6),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 20,
                    getTitlesWidget: (value, meta) =>
                        Text(value.toInt().toString()).xSmall().muted(),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 18,
                    interval: xAxisInterval,
                    getTitlesWidget: (value, meta) {
                      if (dataMaxX > 0 && value > dataMaxX + 0.5) {
                        return const SizedBox.shrink();
                      }
                      return Text(_formatBytes(value.round())).xSmall().muted();
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: theme.colorScheme.border),
              ),
              rangeAnnotations: RangeAnnotations(
                verticalRangeAnnotations: [
                  if (originalMarkerX != null && originalMarkerX < chartMaxX)
                    VerticalRangeAnnotation(
                      x1: originalMarkerX,
                      x2: chartMaxX,
                      color: originalSizeOverlayColor,
                    ),
                ],
              ),
              extraLinesData: ExtraLinesData(
                extraLinesOnTop: true,
                verticalLines: [
                  if (originalMarkerX != null)
                    VerticalLine(
                      x: originalMarkerX,
                      color: originalSizeLineColor,
                      strokeWidth: 1.5,
                      dashArray: [3, 4],
                    ),
                ],
              ),
              lineTouchData: LineTouchData(
                handleBuiltInTouches: false,
                touchCallback: (event, response) {
                  final touchedSpots = response?.lineBarSpots;
                  if (touchedSpots == null ||
                      touchedSpots.isEmpty ||
                      !_isAnalyzeSelectionEvent(event)) {
                    return;
                  }
                  final touched = touchedSpots.first;
                  final point = switch (touched.barIndex) {
                    0 => pixelMatchPoints[touched.spotIndex],
                    1 => msSsimPoints[touched.spotIndex],
                    _ => ssimulacra2Points[touched.spotIndex],
                  };
                  if (_isAnalyzeCommitEvent(event)) {
                    _selectionPulseController.forward(from: 0);
                    widget.onCommitSample(point.sample);
                  } else if (event is FlPointerHoverEvent) {
                    widget.onHoverSample(point.sample);
                  }
                },
              ),
              lineBarsData: [
                _buildAnalyzeLine(
                  points: pixelMatchPoints,
                  color: _analyzeMetricColorForLabel('Pixel Match'),
                  selectedArtifactId: widget.selectedArtifactId,
                  selectedPulse: selectedPulse,
                ),
                _buildAnalyzeLine(
                  points: msSsimPoints,
                  color: _analyzeMetricColorForLabel('MS-SSIM'),
                  selectedArtifactId: widget.selectedArtifactId,
                  selectedPulse: selectedPulse,
                ),
                _buildAnalyzeLine(
                  points: ssimulacra2Points,
                  color: _analyzeMetricColorForLabel('SSIMULACRA 2'),
                  selectedArtifactId: widget.selectedArtifactId,
                  selectedPulse: selectedPulse,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AnalyzeMetricPoint {
  const _AnalyzeMetricPoint({required this.sample, required this.spot});

  final AnalyzeSampleResult sample;
  final FlSpot spot;
}

List<_AnalyzeMetricPoint> _metricPoints(
  List<AnalyzeSampleResult> samples,
  double? Function(AnalyzeSampleResult sample) metric,
) {
  return samples
      .where((sample) => metric(sample) != null)
      .map(
        (sample) => _AnalyzeMetricPoint(
          sample: sample,
          spot: FlSpot(sample.sizeBytes.toDouble(), metric(sample)!),
        ),
      )
      .toList(growable: false);
}

LineChartBarData _buildAnalyzeLine({
  required List<_AnalyzeMetricPoint> points,
  required Color color,
  required String? selectedArtifactId,
  required double selectedPulse,
}) {
  return LineChartBarData(
    spots: points.map((point) => point.spot).toList(growable: false),
    isCurved: false,
    color: color,
    barWidth: 2,
    dotData: FlDotData(
      show: true,
      getDotPainter: (spot, percent, barData, index) {
        final selected =
            selectedArtifactId != null &&
            points[index].sample.artifactId == selectedArtifactId;
        return FlDotCirclePainter(
          radius: selected ? 4 + (2.25 * selectedPulse) : 2.5,
          color: color,
          strokeWidth: selected ? 2 : 0,
          strokeColor: Colors.white,
        );
      },
    ),
  );
}
