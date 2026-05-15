part of 'package:oimg/main.dart';

class _ImageStage extends ConsumerWidget {
  const _ImageStage({required this.title, required this.currentFile});

  final String title;
  final OpenedImageFile currentFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appSettings = ref.watch(appSettingsProvider).asData?.value;
    final plan = ref.watch(currentOptimizationPlanProvider);
    final preview = ref.watch(currentPreviewProvider);
    final optimizedDisplay = ref.watch(currentOptimizedDisplayProvider);
    final displayMode = ref.watch(currentPreviewDisplayModeProvider);
    final differenceFrame = ref.watch(currentPreviewDifferenceFrameProvider);
    final hasOptimizedPreview = optimizedDisplay != null;
    final planData = plan.maybeWhen(data: (value) => value, orElse: () => null);
    final differenceUnavailableTooltip =
        planData?.useSourceImageForPreview == true
        ? 'Not available for lossless formats'
        : null;
    final supportsDifference =
        hasOptimizedPreview &&
        differenceUnavailableTooltip == null &&
        optimizedDisplay.width == currentFile.metadata.width &&
        optimizedDisplay.height == currentFile.metadata.height;
    final showPreviewPathHeader =
        appSettings?.developerModeEnabled == true &&
        appSettings?.previewPathHeaderEnabled == true;

    void selectOriginal() {
      ref
          .read(previewDisplaySelectionProvider.notifier)
          .select(
            filePath: currentFile.path,
            mode: PreviewDisplayMode.original,
          );
    }

    void selectOptimized() {
      if (!hasOptimizedPreview) {
        return;
      }
      ref
          .read(previewDisplaySelectionProvider.notifier)
          .select(
            filePath: currentFile.path,
            mode: PreviewDisplayMode.optimized,
          );
    }

    void selectDifference() {
      if (!supportsDifference) {
        return;
      }
      final artifactId = optimizedDisplay.artifactId;
      ref
          .read(previewDifferenceRequestProvider.notifier)
          .requestForArtifact(artifactId);
      ref
          .read(previewDisplaySelectionProvider.notifier)
          .select(
            filePath: currentFile.path,
            mode: PreviewDisplayMode.difference,
          );
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyR): selectOriginal,
        const SingleActivator(LogicalKeyboardKey.keyE): selectOptimized,
        const SingleActivator(LogicalKeyboardKey.keyD): selectDifference,
      },
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        child: Card(
          padding: EdgeInsets.zero,
          borderRadius: theme.borderRadiusXl,
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showPreviewPathHeader) ...[
                      Text(
                        FileOpenController.directoryOf(currentFile.path),
                        style: TextStyle(
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ).xSmall(),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (currentFile.metadata.hasTransparency) ...[
                              Text(
                                'transparent',
                                style: TextStyle(
                                  color: theme.colorScheme.mutedForeground,
                                ),
                              ).xSmall(),
                              const SizedBox(width: 10),
                            ],
                            Tooltip(
                              waitDuration: const Duration(milliseconds: 250),
                              showDuration: const Duration(milliseconds: 120),
                              tooltip: (context) => TooltipContainer(
                                child: Text(
                                  _formatMegapixels(
                                    currentFile.metadata.width,
                                    currentFile.metadata.height,
                                  ),
                                ),
                              ),
                              child: Text(
                                '${currentFile.metadata.width} x ${currentFile.metadata.height}',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: theme.colorScheme.mutedForeground,
                                ),
                              ).xSmall(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (preview.hasError) ...[
                      const SizedBox(height: 10),
                      Text('Preview unavailable').xSmall().muted(),
                    ],
                  ],
                ),
              ),
              Divider(color: theme.colorScheme.border.withValues(alpha: 0.4)),
              Expanded(
                child: Container(
                  color: theme.colorScheme.background,
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: plan.when(
                    data: (_) {
                      final fileName = FileOpenController.fileNameOf(
                        currentFile.path,
                      );
                      switch (displayMode) {
                        case PreviewDisplayMode.original:
                          return _PreviewCanvas(
                            fileName: fileName,
                            path: currentFile.path,
                          );
                        case PreviewDisplayMode.optimized:
                          if (optimizedDisplay != null) {
                            if (optimizedDisplay.usesOutputPath) {
                              return _PreviewCanvas(
                                fileName: fileName,
                                path: optimizedDisplay.outputPath,
                                unavailableMessage:
                                    'Unable to render optimized preview.',
                              );
                            }
                            return _PreviewCanvas(
                              fileName: fileName,
                              encodedBytes: optimizedDisplay.encodedBytes,
                              unavailableMessage:
                                  'Unable to render optimized preview.',
                            );
                          }
                          return preview.when(
                            data: (_) => _PreviewCanvas(
                              fileName: fileName,
                              path: currentFile.path,
                            ),
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, _) => _PreviewCanvas(
                              fileName: fileName,
                              path: currentFile.path,
                            ),
                          );
                        case PreviewDisplayMode.difference:
                          return DifferencePreview(
                            retentionScopeKey: currentFile.path,
                            frame: differenceFrame,
                            fileName: fileName,
                            showCoordinates:
                                appSettings
                                    ?.differenceTooltipShowsCoordinates ??
                                true,
                            useRgbSwatches:
                                appSettings?.differenceTooltipUsesSwatches ??
                                false,
                            onShowCoordinatesChanged: (value) {
                              unawaited(
                                ref
                                    .read(appSettingsProvider.notifier)
                                    .setDifferenceTooltipShowsCoordinates(
                                      value,
                                    ),
                              );
                            },
                            onUseRgbSwatchesChanged: (value) {
                              unawaited(
                                ref
                                    .read(appSettingsProvider.notifier)
                                    .setDifferenceTooltipUsesSwatches(value),
                              );
                            },
                            unavailableMessage:
                                'Difference preview unavailable.',
                          );
                      }
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => _PreviewCanvas(
                      fileName: FileOpenController.fileNameOf(currentFile.path),
                      path: currentFile.path,
                    ),
                  ),
                ),
              ),
              // const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: _PreviewDisplayModeRow(
                  filePath: currentFile.path,
                  displayMode: displayMode,
                  hasOptimizedPreview: hasOptimizedPreview,
                  supportsDifference: supportsDifference,
                  differenceUnavailableTooltip: differenceUnavailableTooltip,
                  optimizedArtifactId: optimizedDisplay?.artifactId,
                  onSelectOriginal: selectOriginal,
                  onSelectOptimized: selectOptimized,
                  onSelectDifference: selectDifference,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
