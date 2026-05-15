part of 'package:oimg/main.dart';

class _BottomQualitySection extends ConsumerWidget {
  const _BottomQualitySection({required this.isFolderSelected});

  final bool isFolderSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider).asData?.value;
    final previewState = ref.watch(currentPreviewProvider);
    final analyzeState = ref.watch(analyzeRunControllerProvider);
    final selectedAnalyzeSample = ref.watch(selectedAnalyzeSampleProvider);
    final previewPendingBeforeMetrics =
        selectedAnalyzeSample == null &&
        previewState.isLoading &&
        previewState.asData?.value == null;
    final colorCodingEnabled = settings?.qualityMetricColorsEnabled ?? false;
    final showMetricLegendDots = analyzeState.samples.isNotEmpty;
    final rows = isFolderSelected
        ? const <_BottomMetricRowState>[
            _BottomMetricRowState.text(label: 'Pixel Match', value: 'N/A'),
            _BottomMetricRowState.text(label: 'MS-SSIM', value: 'N/A'),
            _BottomMetricRowState.text(label: 'SSIMULACRA 2', value: 'N/A'),
          ]
        : selectedAnalyzeSample != null
        ? <_BottomMetricRowState>[
            _metricRowStateFromAnalyzeSample(
              label: 'Pixel Match',
              value: selectedAnalyzeSample.pixelMatch,
              formatter: _formatNullableMetricPercent,
              scoreMapper: (value) => value?.clamp(0, 100).toDouble(),
            ),
            _metricRowStateFromAnalyzeSample(
              label: 'MS-SSIM',
              value: selectedAnalyzeSample.msSsim,
              formatter: (value) =>
                  _formatNullableMetric(value, trimIfOne: true),
              scoreMapper: (value) =>
                  value == null ? null : (value * 100).clamp(0, 100).toDouble(),
            ),
            _metricRowStateFromAnalyzeSample(
              label: 'SSIMULACRA 2',
              value: selectedAnalyzeSample.ssimulacra2,
              formatter: (value) =>
                  _formatNullableMetric(value, digits: 1, trimIfHundred: true),
              scoreMapper: (value) => value?.clamp(0, 100).toDouble(),
            ),
          ]
        : <_BottomMetricRowState>[
            _metricRowState(
              label: 'Pixel Match',
              metric: ref.watch(currentPreviewPixelMatchProvider),
              formatter: _formatNullableMetricPercent,
              scoreMapper: (value) => value?.clamp(0, 100).toDouble(),
              previewPendingBeforeMetrics: previewPendingBeforeMetrics,
            ),
            _metricRowState(
              label: 'MS-SSIM',
              metric: ref.watch(currentPreviewMsSsimProvider),
              formatter: (value) =>
                  _formatNullableMetric(value, trimIfOne: true),
              scoreMapper: (value) =>
                  value == null ? null : (value * 100).clamp(0, 100).toDouble(),
              previewPendingBeforeMetrics: previewPendingBeforeMetrics,
            ),
            _metricRowState(
              label: 'SSIMULACRA 2',
              metric: ref.watch(currentPreviewSsimulacra2Provider),
              formatter: (value) =>
                  _formatNullableMetric(value, digits: 1, trimIfHundred: true),
              scoreMapper: (value) => value?.clamp(0, 100).toDouble(),
              previewPendingBeforeMetrics: previewPendingBeforeMetrics,
            ),
          ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.2),
        borderRadius: theme.borderRadiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: const Text('Quality').small().medium().muted()),
              SizedBox(
                width: 18,
                height: 18,
                child: Center(
                  child: GhostButton(
                    key: const ValueKey('quality-metric-colors-button'),
                    size: ButtonSize.xSmall,
                    density: ButtonDensity.iconDense,
                    onPressed: settings == null
                        ? null
                        : () {
                            showDropdown(
                              context: context,
                              builder: (context) {
                                return Consumer(
                                  builder: (context, ref, child) {
                                    final settings = ref
                                        .watch(appSettingsProvider)
                                        .asData
                                        ?.value;
                                    if (settings == null) {
                                      return const SizedBox.shrink();
                                    }
                                    final colorCodingEnabled =
                                        settings.qualityMetricColorsEnabled;
                                    return DropdownMenu(
                                      children: [
                                        MenuCheckbox(
                                          key: const ValueKey(
                                            'quality-metric-colors-toggle',
                                          ),
                                          value: colorCodingEnabled,
                                          autoClose: false,
                                          onChanged: (context, value) {
                                            unawaited(
                                              ref
                                                  .read(
                                                    appSettingsProvider
                                                        .notifier,
                                                  )
                                                  .setQualityMetricColorsEnabled(
                                                    value,
                                                  ),
                                            );
                                          },
                                          child: Text(
                                            colorCodingEnabled
                                                ? 'Disable metric colors'
                                                : 'Enable metric colors',
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                          },
                    child: Icon(
                      Icons.settings,
                      size: 11,
                      color: theme.colorScheme.mutedForeground.withValues(
                        alpha: 0.35,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < rows.length; index++) ...[
            _BottomMetricRow(
              row: rows[index],
              colorCodingEnabled: colorCodingEnabled,
              showLegendDot: showMetricLegendDots,
            ),
            if (index + 1 < rows.length) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

_BottomMetricRowState _metricRowStateFromAnalyzeSample({
  required String label,
  required double? value,
  required String Function(double? value) formatter,
  required double? Function(double? value) scoreMapper,
}) {
  return _BottomMetricRowState.text(
    label: label,
    value: formatter(value),
    qualityScore: scoreMapper(value),
  );
}

_BottomMetricRowState _metricRowState({
  required String label,
  required AsyncValue<PreviewMetricResult?> metric,
  required String Function(double?) formatter,
  required double? Function(double? value) scoreMapper,
  required bool previewPendingBeforeMetrics,
}) {
  if (previewPendingBeforeMetrics) {
    return _BottomMetricRowState.text(label: label, value: '—');
  }
  return metric.when(
    data: (result) => _BottomMetricRowState.text(
      label: label,
      value: formatter(result?.value),
      qualityScore: scoreMapper(result?.value),
      timingTooltip: result == null
          ? null
          : _formatMetricTimingTooltip(result.elapsedMilliseconds),
    ),
    error: (_, _) => _BottomMetricRowState.text(label: label, value: 'N/A'),
    loading: () => _BottomMetricRowState.loading(label: label),
  );
}

class _BottomMetricRowState {
  const _BottomMetricRowState._({
    required this.label,
    required this.state,
    this.value,
    this.qualityScore,
    this.timingTooltip,
  });

  const _BottomMetricRowState.loading({required String label})
    : this._(label: label, state: _BottomMetricRowDisplayState.loading);

  const _BottomMetricRowState.text({
    required String label,
    required String value,
    double? qualityScore,
    String? timingTooltip,
  }) : this._(
         label: label,
         state: _BottomMetricRowDisplayState.text,
         value: value,
         qualityScore: qualityScore,
         timingTooltip: timingTooltip,
       );

  final String label;
  final _BottomMetricRowDisplayState state;
  final String? value;
  final double? qualityScore;
  final String? timingTooltip;
}

enum _BottomMetricRowDisplayState { loading, text }

const _pixelMatchAnalyzeColor = Color(0xFF06B6D4);
const _msSsimAnalyzeColor = Color(0xFFD946EF);
const _ssimulacra2AnalyzeColor = Color(0xFFEAB308);

Color _analyzeMetricColorForLabel(String label) {
  return switch (label) {
    'Pixel Match' => _pixelMatchAnalyzeColor,
    'MS-SSIM' => _msSsimAnalyzeColor,
    'SSIMULACRA 2' => _ssimulacra2AnalyzeColor,
    _ => const Color(0xFF94A3B8),
  };
}

class _BottomMetricRow extends StatelessWidget {
  const _BottomMetricRow({
    required this.row,
    required this.colorCodingEnabled,
    required this.showLegendDot,
  });

  final _BottomMetricRowState row;
  final bool colorCodingEnabled;
  final bool showLegendDot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLegendDot) ...[
          Container(
            key: ValueKey('metric-legend-dot-${row.label}'),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _analyzeMetricColorForLabel(row.label),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Flexible(child: Text(row.label).xSmall().medium().muted()),
      ],
    );
    final help = _metricHelpFor(row.label);
    final valueColor = colorCodingEnabled && row.qualityScore != null
        ? _qualityMetricColor(row.qualityScore!)
        : theme.colorScheme.mutedForeground;

    return Row(
      children: [
        Expanded(
          child: help == null
              ? labelWidget
              : _MetricHelpHoverCard(help: help, child: labelWidget),
        ),
        if (row.state == _BottomMetricRowDisplayState.loading)
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else ...[
          (() {
            final valueWidget = Text(
              row.value!,
              style: TextStyle(color: valueColor),
            ).xSmall().medium();
            return row.timingTooltip == null
                ? valueWidget
                : Tooltip(
                    waitDuration: const Duration(milliseconds: 250),
                    showDuration: const Duration(milliseconds: 120),
                    tooltip: (context) =>
                        TooltipContainer(child: Text(row.timingTooltip!)),
                    child: valueWidget,
                  );
          })(),
        ],
      ],
    );
  }
}

Color _qualityMetricColor(double score) {
  return _interpolateColorStops(score, _qualityMetricColorStops);
}

Color _savingsMetricColor(double score) {
  return _interpolateColorStops(score, _savingsMetricColorStops);
}

double _bitsPerPixelColorScore(double bitsPerPixel) {
  if (bitsPerPixel <= 0.25) {
    return 100;
  }
  if (bitsPerPixel <= 0.5) {
    return _interpolateLinear(bitsPerPixel, 0.25, 0.5, 100, 75);
  }
  if (bitsPerPixel <= 1.0) {
    return _interpolateLinear(bitsPerPixel, 0.5, 1.0, 75, 60);
  }
  if (bitsPerPixel <= 1.6) {
    return _interpolateLinear(bitsPerPixel, 1.0, 1.6, 60, 40);
  }
  if (bitsPerPixel <= 2.0) {
    return _interpolateLinear(bitsPerPixel, 1.6, 2.0, 40, 20);
  }
  if (bitsPerPixel <= 5.0) {
    return _interpolateLinear(bitsPerPixel, 2.0, 5.0, 20, 0);
  }
  return 0;
}

double _interpolateLinear(
  double value,
  double lowerBound,
  double upperBound,
  double lowerOutput,
  double upperOutput,
) {
  final range = upperBound - lowerBound;
  if (range <= 0) {
    return upperOutput;
  }
  final t = (value - lowerBound) / range;
  return lowerOutput + ((upperOutput - lowerOutput) * t);
}

Color _interpolateColorStops(
  double score,
  List<({double value, Color color})> colorStops,
) {
  final clampedScore = score
      .clamp(colorStops.first.value, colorStops.last.value)
      .toDouble();

  for (var index = 1; index < colorStops.length; index++) {
    final lower = colorStops[index - 1];
    final upper = colorStops[index];
    if (clampedScore > upper.value) {
      continue;
    }

    final range = upper.value - lower.value;
    if (range <= 0) {
      return upper.color;
    }

    final t = (clampedScore - lower.value) / range;
    return Color.lerp(lower.color, upper.color, t) ?? upper.color;
  }

  return colorStops.last.color;
}

class _MetricHelpData {
  const _MetricHelpData({
    required this.description,
    required this.linkLabel,
    required this.linkUrl,
  });

  final String description;
  final String linkLabel;
  final Uri linkUrl;
}

class _MetricHelpHoverCard extends StatelessWidget {
  const _MetricHelpHoverCard({required this.help, required this.child});

  final _MetricHelpData help;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return HoverCard(
      wait: const Duration(milliseconds: 250),
      debounce: const Duration(milliseconds: 120),
      hoverBuilder: (context) {
        return Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.popover,
            borderRadius: theme.borderRadiusLg,
            border: Border.all(color: theme.colorScheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(help.description).xSmall().muted(),
              const SizedBox(height: 10),
              LinkButton(
                density: ButtonDensity.compact,
                onPressed: () async {
                  await launchUrl(
                    help.linkUrl,
                    mode: LaunchMode.externalApplication,
                  );
                },
                child: Text(help.linkLabel),
              ),
            ],
          ),
        );
      },
      child: child,
    );
  }
}

_MetricHelpData? _metricHelpFor(String label) {
  return switch (label) {
    'Pixel Match' => _MetricHelpData(
      description:
          'Estimates what percentage of the image remains visually unchanged.',
      linkLabel: 'Learn more on GitHub (dify)',
      linkUrl: Uri.parse('https://github.com/jihchi/dify'),
    ),
    'MS-SSIM' => _MetricHelpData(
      description:
          'Compares preserved structure and contrast across several viewing scales.',
      linkLabel: 'Learn more on Wikipedia',
      linkUrl: Uri.parse(
        'https://en.wikipedia.org/wiki/Structural_similarity_index_measure',
      ),
    ),
    'SSIMULACRA 2' => _MetricHelpData(
      description: 'A perceptual quality metric tuned to human vision.',
      linkLabel: 'Learn more on x266 wiki',
      linkUrl: Uri.parse('https://wiki.x266.mov/docs/metrics/SSIMULACRA2'),
    ),
    _ => null,
  };
}
