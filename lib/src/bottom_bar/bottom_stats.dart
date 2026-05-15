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
  const _BottomStatsSection({required this.stats});

  final List<_BottomStatData> stats;

  @override
  Widget build(BuildContext context) {
    final topRow = stats.take(2).toList(growable: false);
    final bottomRow = stats.skip(2).take(2).toList(growable: false);

    return Column(
      children: [
        Expanded(child: _BottomStatRow(stats: topRow)),
        const SizedBox(height: 10),
        Expanded(child: _BottomStatRow(stats: bottomRow)),
      ],
    );
  }
}

class _BottomStatRow extends StatelessWidget {
  const _BottomStatRow({required this.stats});

  final List<_BottomStatData> stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < stats.length; index++) ...[
          Expanded(child: _BottomStatTile(stat: stats[index])),
          if (index + 1 < stats.length) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _BottomStatTile extends ConsumerWidget {
  const _BottomStatTile({required this.stat});

  final _BottomStatData stat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider).asData?.value;
    final savingsDisplayMode = ref.watch(_savingsDisplayModeProvider);
    final isToggleable = stat.toggleable && !stat.loading;
    final displayedValue =
        stat.toggleable && savingsDisplayMode == _SavingsDisplayMode.ratio
        ? (stat.alternateValue ?? stat.value)
        : stat.value;
    final defaultValueColor = switch (stat.colorMode) {
      _BottomStatColorMode.none => stat.color,
      _ => theme.colorScheme.foreground,
    };
    final valueColor = switch (stat.colorMode) {
      _BottomStatColorMode.none => defaultValueColor,
      _BottomStatColorMode.fileSize
          when settings?.fileSizeColorsEnabled == true &&
              stat.colorScore != null =>
        _qualityMetricColor(_bitsPerPixelColorScore(stat.colorScore!)),
      _BottomStatColorMode.similarity
          when settings?.similarityMetricColorsEnabled == true &&
              stat.colorScore != null =>
        _qualityMetricColor(stat.colorScore!),
      _BottomStatColorMode.savings
          when settings?.savingsColorsEnabled == true &&
              stat.colorScore != null =>
        _savingsMetricColor(stat.colorScore!),
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
          if (stat.loading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: stat.color,
              ),
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
