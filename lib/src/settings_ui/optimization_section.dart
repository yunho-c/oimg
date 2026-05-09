part of 'package:oimg/main.dart';

class _OptimizationCollapsible extends ConsumerStatefulWidget {
  const _OptimizationCollapsible({
    required this.settings,
    required this.controlsLocked,
  });

  final AppSettings settings;
  final bool controlsLocked;

  @override
  ConsumerState<_OptimizationCollapsible> createState() =>
      _OptimizationCollapsibleState();
}

class _OptimizationCollapsibleState
    extends ConsumerState<_OptimizationCollapsible> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(appSettingsProvider.notifier);
    final currentFile = ref.watch(fileOpenControllerProvider).currentFile;

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 4),
            child: Row(
              children: [
                Expanded(child: const Text('Optimization').small().medium()),
                GhostButton(
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: Icon(
                      _isExpanded ? Icons.remove : Icons.add,
                      key: ValueKey<bool>(_isExpanded),
                    ).iconXSmall(),
                  ),
                ),
              ],
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: _isExpanded
                    ? const BoxConstraints()
                    : const BoxConstraints(maxHeight: 0),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SettingsLabel('Effort'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('0').xSmall().muted(),
                          const Spacer(),
                          Text(
                            '${widget.settings.effort}',
                          ).xSmall().medium().muted(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _HoverValueSlider(
                        key: const ValueKey('effort-slider'),
                        value: widget.settings.effort.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 100,
                        hoverEnabled: !widget.controlsLocked,
                        hoverOpacityKey: const ValueKey(
                          'effort-slider-hover-opacity',
                        ),
                        hoverValueKey: const ValueKey(
                          'effort-slider-hover-value',
                        ),
                        onChanged: widget.controlsLocked
                            ? null
                            : (value) {
                                notifier.setEffort(value.round());
                              },
                      ),
                      if (widget.settings.effectiveCodec ==
                          PreferredCodec.png) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const _SettingsLabel('Palette'),
                            const Spacer(),
                            if (_paletteSuggestionLabel(currentFile)
                                case final suggestion?)
                              Tooltip(
                                tooltip: (context) => TooltipContainer(
                                  child: Text(
                                    _paletteSuggestionTooltip(currentFile)!,
                                  ),
                                ),
                                child: Text(suggestion).xSmall().muted(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        RadioGroup<PngPalettePreference>(
                          value: widget.settings.pngPaletteMode,
                          onChanged: widget.controlsLocked
                              ? null
                              : notifier.setPngPaletteMode,
                          child: Row(
                            children: [
                              for (final mode
                                  in PngPalettePreference.values) ...[
                                Expanded(
                                  child: RadioItem<PngPalettePreference>(
                                    value: mode,
                                    enabled: !widget.controlsLocked,
                                    trailing: Text(
                                      _pngPaletteLabel(mode),
                                    ).xSmall(),
                                  ),
                                ),
                                if (mode != PngPalettePreference.values.last)
                                  const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
