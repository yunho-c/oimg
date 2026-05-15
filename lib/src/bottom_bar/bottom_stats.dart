part of 'package:oimg/main.dart';

class _BottomDetail extends StatelessWidget {
  const _BottomDetail({required this.label, required this.value, this.child});

  final String label;
  final String value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (child != null) {
      return child!;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label).xSmall().medium().muted(),
        const SizedBox(height: 6),
        Text(value).small().medium(),
      ],
    );
  }
}

class _OptimizeActionButtonFrame extends StatelessWidget {
  const _OptimizeActionButtonFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(child: child);
  }
}

class _OptimizeSuccessButton extends StatelessWidget {
  const _OptimizeSuccessButton({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    const successColor = Color(0xFF34C759);

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: successColor,
        borderRadius: theme.borderRadiusMd,
      ),
      child: const Text(
        'Success!',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _BottomStatsSection extends StatelessWidget {
  const _BottomStatsSection({required this.stats, required this.retentionKey});

  final List<_BottomStatData> stats;
  final Object retentionKey;

  @override
  Widget build(BuildContext context) {
    final topRow = stats.take(2).toList(growable: false);
    final bottomRow = stats.skip(2).take(2).toList(growable: false);

    return Column(
      children: [
        Expanded(
          child: _BottomStatRow(stats: topRow, retentionKey: retentionKey),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _BottomStatRow(stats: bottomRow, retentionKey: retentionKey),
        ),
      ],
    );
  }
}

class _BottomStatRow extends StatelessWidget {
  const _BottomStatRow({required this.stats, required this.retentionKey});

  final List<_BottomStatData> stats;
  final Object retentionKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < stats.length; index++) ...[
          Expanded(
            child: _BottomStatTile(
              key: ValueKey('bottom-stat-tile-${stats[index].label}'),
              stat: stats[index],
              retentionKey: retentionKey,
            ),
          ),
          if (index + 1 < stats.length) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _BottomStatTile extends ConsumerStatefulWidget {
  const _BottomStatTile({
    super.key,
    required this.stat,
    required this.retentionKey,
  });

  final _BottomStatData stat;
  final Object retentionKey;

  @override
  ConsumerState<_BottomStatTile> createState() => _BottomStatTileState();
}

class _BottomStatTileState extends ConsumerState<_BottomStatTile> {
  _RetainedBottomStatValue? _primaryRetainedValue;
  _RetainedBottomStatValue? _alternateRetainedValue;
  num? _primaryAnimationStart;
  num? _primaryAnimationTarget;
  num? _alternateAnimationStart;
  num? _alternateAnimationTarget;
  String _primaryAnimationKeySuffix = 'live';
  String _alternateAnimationKeySuffix = 'live';

  @override
  void didUpdateWidget(covariant _BottomStatTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.retentionKey != widget.retentionKey ||
        oldWidget.stat.label != widget.stat.label) {
      _primaryRetainedValue = null;
      _alternateRetainedValue = null;
      _primaryAnimationStart = null;
      _primaryAnimationTarget = null;
      _alternateAnimationStart = null;
      _alternateAnimationTarget = null;
      _primaryAnimationKeySuffix = 'live';
      _alternateAnimationKeySuffix = 'live';
      return;
    }
    _captureResolvedAnimationStarts(oldWidget.stat, widget.stat);
  }

  void _captureResolvedAnimationStarts(
    _BottomStatData oldStat,
    _BottomStatData newStat,
  ) {
    if (oldStat.pending &&
        newStat.numericValue != null &&
        newStat.numericFormatter != null &&
        _primaryRetainedValue != null &&
        _primaryRetainedValue!.value != newStat.numericValue) {
      _primaryAnimationStart = _primaryRetainedValue!.value;
      _primaryAnimationTarget = newStat.numericValue;
      _primaryAnimationKeySuffix =
          'from-$_primaryAnimationStart-to-$_primaryAnimationTarget';
    }
    if (oldStat.pending &&
        newStat.alternateNumericValue != null &&
        newStat.alternateNumericFormatter != null &&
        _alternateRetainedValue != null &&
        _alternateRetainedValue!.value != newStat.alternateNumericValue) {
      _alternateAnimationStart = _alternateRetainedValue!.value;
      _alternateAnimationTarget = newStat.alternateNumericValue;
      _alternateAnimationKeySuffix =
          'from-$_alternateAnimationStart-to-$_alternateAnimationTarget';
    }
  }

  void _rememberResolvedValues(_BottomStatData stat) {
    if (stat.loading) {
      return;
    }
    if (stat.numericValue != null && stat.numericFormatter != null) {
      _primaryRetainedValue = _RetainedBottomStatValue(
        value: stat.numericValue!,
        formatter: stat.numericFormatter!,
        fallbackValue: stat.value,
        colorScore: stat.colorScore,
      );
    }
    if (stat.alternateNumericValue != null &&
        stat.alternateNumericFormatter != null) {
      _alternateRetainedValue = _RetainedBottomStatValue(
        value: stat.alternateNumericValue!,
        formatter: stat.alternateNumericFormatter!,
        fallbackValue: stat.alternateValue ?? stat.value,
        colorScore: stat.colorScore,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final stat = widget.stat;
    _rememberResolvedValues(stat);

    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider).asData?.value;
    final savingsDisplayMode = ref.watch(_savingsDisplayModeProvider);
    final isToggleable = stat.toggleable && !stat.loading;
    final showAlternate =
        stat.toggleable && savingsDisplayMode == _SavingsDisplayMode.ratio;
    final displayedValue = showAlternate
        ? (stat.alternateValue ?? stat.value)
        : stat.value;
    final numericValue = showAlternate
        ? stat.alternateNumericValue
        : stat.numericValue;
    final numericFormatter = showAlternate
        ? stat.alternateNumericFormatter
        : stat.numericFormatter;
    final retainedValue = showAlternate
        ? _alternateRetainedValue
        : _primaryRetainedValue;
    final animationStart = showAlternate
        ? (_alternateAnimationTarget == numericValue
              ? _alternateAnimationStart
              : null)
        : (_primaryAnimationTarget == numericValue
              ? _primaryAnimationStart
              : null);
    final animationKeySuffix = showAlternate
        ? _alternateAnimationKeySuffix
        : _primaryAnimationKeySuffix;
    final hasResolvedNumericValue =
        !stat.loading && numericValue != null && numericFormatter != null;
    final retainedValueVisible =
        stat.pending && !hasResolvedNumericValue && retainedValue != null;
    final valueColorScore = retainedValueVisible
        ? retainedValue.colorScore
        : stat.colorScore;
    final defaultValueColor = switch (stat.colorMode) {
      _BottomStatColorMode.none => stat.color,
      _ => theme.colorScheme.foreground,
    };
    final valueColor = switch (stat.colorMode) {
      _BottomStatColorMode.none => defaultValueColor,
      _BottomStatColorMode.fileSize
          when settings?.fileSizeColorsEnabled == true &&
              valueColorScore != null =>
        _qualityMetricColor(_bitsPerPixelColorScore(valueColorScore)),
      _BottomStatColorMode.similarity
          when settings?.similarityMetricColorsEnabled == true &&
              valueColorScore != null =>
        _qualityMetricColor(valueColorScore),
      _BottomStatColorMode.savings
          when settings?.savingsColorsEnabled == true &&
              valueColorScore != null =>
        _savingsMetricColor(valueColorScore),
      _ => defaultValueColor,
    };

    final tile = Container(
      key: ValueKey('bottom-stat-${stat.label}'),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.2),
        borderRadius: theme.borderRadiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stat.label).xSmall().medium().muted(),
          const Spacer(),
          if (stat.loading && !retainedValueVisible)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: stat.color,
              ),
            )
          else if (retainedValueVisible)
            _BottomStatAnimatedValue(
              key: ValueKey(
                'bottom-stat-${stat.label}-${showAlternate ? 'alternate' : 'primary'}-$animationKeySuffix',
              ),
              mode:
                  settings?.bottomStatAnimationMode ??
                  AppSettings.defaults.bottomStatAnimationMode,
              value: retainedValue.value,
              formatter: retainedValue.formatter,
              fallbackValue: retainedValue.fallbackValue,
              initialValue: null,
              color: valueColor,
            )
          else if (numericValue != null && numericFormatter != null)
            _BottomStatAnimatedValue(
              key: ValueKey(
                'bottom-stat-${stat.label}-${showAlternate ? 'alternate' : 'primary'}-$animationKeySuffix',
              ),
              mode:
                  settings?.bottomStatAnimationMode ??
                  AppSettings.defaults.bottomStatAnimationMode,
              value: numericValue,
              formatter: numericFormatter,
              fallbackValue: displayedValue,
              initialValue: animationStart,
              color: valueColor,
            )
          else
            Text(
              displayedValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: valueColor,
              ),
            ),
        ],
      ),
    );

    final decoratedTile = stat.tooltip == null || stat.loading
        ? tile
        : Tooltip(
            waitDuration: const Duration(milliseconds: 250),
            showDuration: const Duration(milliseconds: 120),
            tooltip: (context) => TooltipContainer(child: Text(stat.tooltip!)),
            child: tile,
          );

    final tappableTile = !isToggleable
        ? decoratedTile
        : MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ref.read(_savingsDisplayModeProvider.notifier).toggle();
              },
              child: decoratedTile,
            ),
          );
    final contextMenuItem = switch (stat.colorMode) {
      _BottomStatColorMode.similarity => MenuButton(
        key: const ValueKey('bottom-stat-similarity-colors-toggle'),
        onPressed: (context) {
          unawaited(
            ref
                .read(appSettingsProvider.notifier)
                .setSimilarityMetricColorsEnabled(
                  !(settings?.similarityMetricColorsEnabled ?? false),
                ),
          );
        },
        child: Text(
          settings?.similarityMetricColorsEnabled == true
              ? 'Disable similarity colors'
              : 'Enable similarity colors',
        ),
      ),
      _BottomStatColorMode.savings => MenuButton(
        key: const ValueKey('bottom-stat-savings-colors-toggle'),
        onPressed: (context) {
          unawaited(
            ref
                .read(appSettingsProvider.notifier)
                .setSavingsColorsEnabled(
                  !(settings?.savingsColorsEnabled ?? false),
                ),
          );
        },
        child: Text(
          settings?.savingsColorsEnabled == true
              ? 'Disable savings colors'
              : 'Enable savings colors',
        ),
      ),
      _BottomStatColorMode.fileSize => MenuButton(
        key: const ValueKey('bottom-stat-file-size-colors-toggle'),
        onPressed: (context) {
          unawaited(
            ref
                .read(appSettingsProvider.notifier)
                .setFileSizeColorsEnabled(
                  !(settings?.fileSizeColorsEnabled ?? false),
                ),
          );
        },
        child: Text(
          settings?.fileSizeColorsEnabled == true
              ? 'Disable file size colors'
              : 'Enable file size colors',
        ),
      ),
      _BottomStatColorMode.none => null,
    };

    if (contextMenuItem == null) {
      return tappableTile;
    }

    return ContextMenu(items: [contextMenuItem], child: tappableTile);
  }
}

class _RetainedBottomStatValue {
  const _RetainedBottomStatValue({
    required this.value,
    required this.formatter,
    required this.fallbackValue,
    required this.colorScore,
  });

  final num value;
  final String Function(num value) formatter;
  final String fallbackValue;
  final double? colorScore;
}

class _BottomStatAnimatedValue extends StatelessWidget {
  const _BottomStatAnimatedValue({
    super.key,
    required this.mode,
    required this.value,
    required this.formatter,
    required this.fallbackValue,
    required this.initialValue,
    required this.color,
  });

  final BottomStatAnimationMode mode;
  final num value;
  final String Function(num value) formatter;
  final String fallbackValue;
  final num? initialValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: color,
    );

    return switch (mode) {
      BottomStatAnimationMode.ticker => NumberTicker.builder(
        initialNumber: initialValue,
        number: value,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Text(
            formatter(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
        },
      ),
      BottomStatAnimationMode.flipper => DefaultTextStyle.merge(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
        child: TextFlipper(
          text: formatter(value),
          charset: FlipperCharset.alphanumeric + const FlipperCharset('.% x-'),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        ),
      ),
      BottomStatAnimationMode.off => Text(
        fallbackValue,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    };
  }
}

class _BottomInfoSection extends StatelessWidget {
  const _BottomInfoSection({
    required this.originalTitle,
    required this.originalRows,
    required this.outputTitle,
    required this.outputRows,
  });

  final String originalTitle;
  final List<_BottomInfoRowData> originalRows;
  final String outputTitle;
  final List<_BottomInfoRowData> outputRows;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BottomInfoColumn(title: originalTitle, rows: originalRows),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: _BottomInfoColumn(title: outputTitle, rows: outputRows),
        ),
      ],
    );
  }
}

class _BottomInfoColumn extends StatelessWidget {
  const _BottomInfoColumn({required this.title, required this.rows});

  final String title;
  final List<_BottomInfoRowData> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.2),
        borderRadius: theme.borderRadiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title).xSmall().medium().muted(),
          const SizedBox(height: 10),
          for (var index = 0; index < rows.length; index++) ...[
            _BottomInfoRow(row: rows[index]),
            if (index + 1 < rows.length) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _BottomInfoRow extends ConsumerStatefulWidget {
  const _BottomInfoRow({required this.row});

  final _BottomInfoRowData row;

  @override
  ConsumerState<_BottomInfoRow> createState() => _BottomInfoRowState();
}

class _BottomInfoRowState extends ConsumerState<_BottomInfoRow> {
  Timer? _highlightTimer;
  var _isHighlighted = false;

  @override
  void didUpdateWidget(covariant _BottomInfoRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.row.highlightOnValueChange) {
      return;
    }
    if (oldWidget.row.value == widget.row.value) {
      return;
    }
    _highlightTimer?.cancel();
    setState(() {
      _isHighlighted = true;
    });
    _highlightTimer = Timer(const Duration(seconds: 1), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _isHighlighted = false;
      });
    });
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = widget.row.supportsBitsPerPixelColors
        ? ref.watch(appSettingsProvider).asData?.value
        : null;
    final valueColor = widget.row.supportsBitsPerPixelColors
        ? settings?.bitsPerPixelColorsEnabled == true &&
                  widget.row.bitsPerPixelValue != null
              ? _qualityMetricColor(
                  _bitsPerPixelColorScore(widget.row.bitsPerPixelValue!),
                )
              : theme.colorScheme.foreground
        : null;
    final rowWidget = SizedBox(
      key: widget.row.rowKey == null ? null : ValueKey(widget.row.rowKey!),
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.row.label} ').xSmall().medium().muted(),
          Expanded(
            child: TweenAnimationBuilder<TextStyle?>(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              tween: TextStyleTween(
                end: Theme.of(context).typography.xSmall.copyWith(
                  fontWeight: _isHighlighted
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: valueColor,
                ),
              ),
              builder: (context, style, child) {
                return Text(
                  widget.row.value,
                  key: widget.row.key == null
                      ? null
                      : ValueKey(widget.row.key!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: style,
                );
              },
            ),
          ),
        ],
      ),
    );

    if (!widget.row.supportsBitsPerPixelColors) {
      return rowWidget;
    }

    return ContextMenu(
      items: [
        MenuButton(
          key: const ValueKey('bottom-info-bpp-colors-toggle'),
          onPressed: (context) {
            unawaited(
              ref
                  .read(appSettingsProvider.notifier)
                  .setBitsPerPixelColorsEnabled(
                    !(settings?.bitsPerPixelColorsEnabled ?? false),
                  ),
            );
          },
          child: Text(
            settings?.bitsPerPixelColorsEnabled == true
                ? 'Disable bits per pixel colors'
                : 'Enable bits per pixel colors',
          ),
        ),
      ],
      child: rowWidget,
    );
  }
}
