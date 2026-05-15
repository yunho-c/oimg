part of 'package:oimg/main.dart';

class _PreviewUnavailable extends StatelessWidget {
  const _PreviewUnavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.imageOff,
            size: 32,
            color: theme.colorScheme.mutedForeground,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class _FolderCollage extends StatelessWidget {
  const _FolderCollage({
    required this.files,
    required this.onOpenFile,
    required this.onRevealFile,
  });

  final List<OpenedImageFile> files;
  final ValueChanged<String> onOpenFile;
  final Future<void> Function(String) onRevealFile;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final crossAxisCount = math.max(
          1,
          math.min(4, (constraints.maxWidth / 180).floor()),
        );
        final totalSpacing = spacing * (crossAxisCount - 1);
        final tileWidth =
            (constraints.maxWidth - totalSpacing) / crossAxisCount;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
            childAspectRatio: 0.95,
          ),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            return _FolderCollageTile(
              file: file,
              tileWidth: tileWidth,
              onPressed: () => onOpenFile(file.path),
              onRevealFile: () => onRevealFile(file.path),
            );
          },
        );
      },
    );
  }
}

class _FolderCollageTile extends StatelessWidget {
  const _FolderCollageTile({
    required this.file,
    required this.tileWidth,
    required this.onPressed,
    required this.onRevealFile,
  });

  final OpenedImageFile file;
  final double tileWidth;
  final VoidCallback onPressed;
  final Future<void> Function() onRevealFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = math.max(1, (tileWidth * devicePixelRatio).round());
    final showInFileManagerLabel = _showInFileManagerLabel();
    final tile = GestureDetector(
      key: ValueKey('folder-collage-tile-${file.path}'),
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Card(
        padding: EdgeInsets.zero,
        borderRadius: theme.borderRadiusLg,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                color: theme.colorScheme.secondary,
                alignment: Alignment.center,
                child: Image.file(
                  File(file.path),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  cacheWidth: cacheWidth,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      LucideIcons.imageOff,
                      size: 24,
                      color: theme.colorScheme.mutedForeground,
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      FileOpenController.fileNameOf(file.path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ).small().medium(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _fileSizeLabel(file) ?? 'Unknown',
                    textAlign: TextAlign.right,
                  ).xSmall().muted(),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: showInFileManagerLabel == null
          ? tile
          : ContextMenu(
              items: [
                MenuButton(
                  onPressed: (context) {
                    unawaited(onRevealFile());
                  },
                  child: Text(showInFileManagerLabel),
                ),
              ],
              child: tile,
            ),
    );
  }
}

class _ImageLoadError extends StatelessWidget {
  const _ImageLoadError({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.imageOff,
            size: 32,
            color: theme.colorScheme.mutedForeground,
          ),
          const SizedBox(height: 12),
          Text(
            'Unable to load $fileName.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class _PreviewMetaItem extends StatelessWidget {
  const _PreviewMetaItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text('$label $value').xSmall().muted();
  }
}

class _PreviewDisplayModeRow extends ConsumerWidget {
  const _PreviewDisplayModeRow({
    required this.filePath,
    required this.displayMode,
    required this.hasOptimizedPreview,
    required this.supportsDifference,
    required this.differenceUnavailableTooltip,
    required this.optimizedArtifactId,
    required this.onSelectOriginal,
    required this.onSelectOptimized,
    required this.onSelectDifference,
  });

  final String filePath;
  final PreviewDisplayMode displayMode;
  final bool hasOptimizedPreview;
  final bool supportsDifference;
  final String? differenceUnavailableTooltip;
  final String? optimizedArtifactId;
  final VoidCallback onSelectOriginal;
  final VoidCallback onSelectOptimized;
  final VoidCallback onSelectDifference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(currentPreviewProvider);
    final analyzeState = ref.watch(analyzeRunControllerProvider);
    final analyzeAvailability = ref.watch(analyzeAvailabilityProvider);
    final analyzeController = ref.read(analyzeRunControllerProvider.notifier);
    final settings = ref.watch(appSettingsProvider).asData?.value;
    final optimizedLoading = preview.isLoading && !hasOptimizedPreview;
    final differenceFrame = ref.watch(currentPreviewDifferenceFrameProvider);
    final differenceLoading =
        displayMode == PreviewDisplayMode.difference &&
        differenceFrame.isLoading;
    final hasAnalyzeResults = analyzeState.samples.isNotEmpty;
    final canToggleAnalyzeChart =
        hasAnalyzeResults &&
        !analyzeState.isRunning &&
        !analyzeState.isCancelRequested;
    final analyzeTooltip = canToggleAnalyzeChart
        ? (analyzeState.isChartVisible ? 'Hide graph' : 'Show graph')
        : !analyzeAvailability.isEnabled &&
              settings != null &&
              settings.compressionMethod == CompressionMethod.lossless &&
              !settings.showsQualityControl
        ? 'Not available for lossless formats'
        : analyzeAvailability.reason ??
              'Visualize the quality/efficiency tradeoff';

    return Row(
      key: const ValueKey('preview-display-mode-row'),
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _PreviewDisplayModeButton(
          shortcutKey: LogicalKeyboardKey.keyR,
          label: 'Original',
          selected: displayMode == PreviewDisplayMode.original,
          enabled: true,
          onPressed: onSelectOriginal,
        ),
        const SizedBox(width: 8),
        _PreviewDisplayModeButton(
          shortcutKey: LogicalKeyboardKey.keyE,
          label: 'Optimized',
          selected: displayMode == PreviewDisplayMode.optimized,
          enabled: hasOptimizedPreview,
          tooltip: optimizedLoading ? 'Optimizing image...' : null,
          loading: optimizedLoading,
          onPressed: onSelectOptimized,
        ),
        const SizedBox(width: 8),
        _PreviewDisplayModeButton(
          shortcutKey: LogicalKeyboardKey.keyD,
          label: 'Difference',
          selected: displayMode == PreviewDisplayMode.difference,
          enabled: supportsDifference,
          tooltip: differenceUnavailableTooltip,
          loading: differenceLoading,
          onPressed: onSelectDifference,
        ),
        const Spacer(),
        Tooltip(
          waitDuration: const Duration(milliseconds: 250),
          showDuration: const Duration(milliseconds: 120),
          tooltip: (context) => TooltipContainer(child: Text(analyzeTooltip)),
          child: analyzeState.isCancelRequested
              ? OutlineButton(
                  alignment: Alignment.center,
                  onPressed: null,
                  child: const Text('Canceling...'),
                )
              : analyzeState.isRunning
              ? Button.destructive(
                  alignment: Alignment.center,
                  onPressed: analyzeController.cancelAnalyze,
                  child: const Text('Cancel'),
                )
              : OutlineButton(
                  alignment: Alignment.center,
                  onPressed: canToggleAnalyzeChart
                      ? analyzeController.toggleChartVisibility
                      : analyzeAvailability.isEnabled
                      ? analyzeController.startAnalyze
                      : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        canToggleAnalyzeChart
                            ? analyzeState.isChartVisible
                                  ? LucideIcons.eyeOff
                                  : LucideIcons.eye
                            : LucideIcons.chartSpline,
                        size: 15,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        canToggleAnalyzeChart
                            ? analyzeState.isChartVisible
                                  ? 'Hide'
                                  : 'Show'
                            : 'Analyze',
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _PreviewDisplayModeButton extends StatelessWidget {
  const _PreviewDisplayModeButton({
    required this.shortcutKey,
    required this.label,
    required this.selected,
    required this.enabled,
    this.tooltip,
    this.loading = false,
    required this.onPressed,
  });

  final LogicalKeyboardKey shortcutKey;
  final String label;
  final bool selected;
  final bool enabled;
  final String? tooltip;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final buttonChild = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading) ...[
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
        ],
        _PreviewModeShortcutKey(shortcutKey: shortcutKey),
        const SizedBox(width: 8),
        Text(label).xSmall().medium(),
      ],
    );
    final button = SizedBox(
      key: ValueKey('preview-mode-$label'),
      height: 30,
      child: selected
          ? PrimaryButton(
              onPressed: enabled ? onPressed : null,
              child: buttonChild,
            )
          : OutlineButton(
              onPressed: enabled ? onPressed : null,
              child: buttonChild,
            ),
    );

    if (tooltip == null) {
      return button;
    }

    return Tooltip(
      waitDuration: const Duration(milliseconds: 250),
      showDuration: const Duration(milliseconds: 120),
      tooltip: (context) => TooltipContainer(child: Text(tooltip!)),
      child: button,
    );
  }
}

class _PreviewModeShortcutKey extends StatelessWidget {
  const _PreviewModeShortcutKey({required this.shortcutKey});

  final LogicalKeyboardKey shortcutKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 4, 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.7),
        borderRadius: theme.borderRadiusSm,
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Text(
        shortcutKey.keyLabel.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.mutedForeground,
          height: 1,
        ),
      ),
    );
  }
}
