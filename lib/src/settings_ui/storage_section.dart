part of 'package:oimg/main.dart';

class _StorageCollapsible extends ConsumerStatefulWidget {
  const _StorageCollapsible({
    required this.settings,
    required this.controlsLocked,
  });

  final AppSettings settings;
  final bool controlsLocked;

  @override
  ConsumerState<_StorageCollapsible> createState() =>
      _StorageCollapsibleState();
}

class _StorageCollapsibleState extends ConsumerState<_StorageCollapsible> {
  bool _isExpanded = false;
  bool _isPickingFolder = false;

  Future<void> _handleSameFolderSelection() async {
    if (widget.controlsLocked) {
      return;
    }
    await ref
        .read(appSettingsProvider.notifier)
        .setStorageDestinationMode(StorageDestinationMode.sameFolder);
  }

  Future<void> _handleDifferentLocationSelection({
    required bool forcePicker,
  }) async {
    if (widget.controlsLocked || _isPickingFolder) {
      return;
    }

    final currentPath = widget.settings.differentLocationPath;
    final currentBookmark = widget.settings.differentLocationBookmark;
    final needsPersistentAccess = Platform.isMacOS;
    final needsPicker =
        forcePicker ||
        currentPath == null ||
        currentPath.isEmpty ||
        (needsPersistentAccess &&
            (currentBookmark == null || currentBookmark.isEmpty)) ||
        widget.settings.storageDestinationMode !=
            StorageDestinationMode.differentLocation;
    if (!needsPicker) {
      return;
    }

    setState(() {
      _isPickingFolder = true;
    });
    final pickedFolder = await ref
        .read(fileOpenControllerProvider)
        .pickStorageFolder();
    if (!mounted) {
      return;
    }
    setState(() {
      _isPickingFolder = false;
    });
    if (pickedFolder == null || pickedFolder.path.isEmpty) {
      return;
    }

    final notifier = ref.read(appSettingsProvider.notifier);
    await notifier.setDifferentLocation(
      path: pickedFolder.path,
      bookmark: pickedFolder.bookmark,
    );
    await notifier.setStorageDestinationMode(
      StorageDestinationMode.differentLocation,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = ref.read(appSettingsProvider.notifier);
    final currentFile = ref.watch(fileOpenControllerProvider).currentFile;
    final primarySameFolderLabel =
        currentFile != null &&
            currentFile.metadata.format !=
                codecIdOf(widget.settings.effectiveCodec)
        ? 'Remove original'
        : 'Overwrite';

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 4),
            child: Row(
              children: [
                Expanded(child: const Text('Storage').small().medium()),
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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cardWidth = (constraints.maxWidth - 8) / 2;
                          return ComponentTheme(
                            data: const RadioCardTheme(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            child: RadioGroup<StorageDestinationMode>(
                              value: widget.settings.storageDestinationMode,
                              onChanged: widget.controlsLocked ? null : (_) {},
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  SizedBox(
                                    width: cardWidth,
                                    child: _StorageDestinationCard(
                                      value: StorageDestinationMode.sameFolder,
                                      enabled: !widget.controlsLocked,
                                      onTap: _handleSameFolderSelection,
                                      child: const _ChoiceCard(
                                        title: 'Same folder',
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: cardWidth,
                                    child: _StorageDestinationCard(
                                      value: StorageDestinationMode
                                          .differentLocation,
                                      enabled:
                                          !widget.controlsLocked &&
                                          !_isPickingFolder,
                                      onTap: () =>
                                          _handleDifferentLocationSelection(
                                            forcePicker:
                                                widget
                                                    .settings
                                                    .storageDestinationMode ==
                                                StorageDestinationMode
                                                    .differentLocation,
                                          ),
                                      child: _ChoiceCard(
                                        title: _isPickingFolder
                                            ? 'Choosing...'
                                            : 'Different location',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      if (widget.settings.storageDestinationMode ==
                          StorageDestinationMode.sameFolder) ...[
                        const SizedBox(height: 10),
                        RadioGroup<SameFolderAction>(
                          value: widget.settings.sameFolderAction,
                          onChanged: widget.controlsLocked
                              ? null
                              : notifier.setSameFolderAction,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RadioItem<SameFolderAction>(
                                value: SameFolderAction.replaceSource,
                                enabled: !widget.controlsLocked,
                                trailing: Text(primarySameFolderLabel).small(),
                              ),
                              const SizedBox(height: 8),
                              RadioItem<SameFolderAction>(
                                value: SameFolderAction.keepSource,
                                enabled: !widget.controlsLocked,
                                trailing: const Text('Keep original').small(),
                              ),
                              if (widget.settings.sameFolderAction ==
                                  SameFolderAction.keepSource) ...[
                                const SizedBox(height: 8),
                                _KeepSourceNamingControls(
                                  settings: widget.settings,
                                  controlsLocked: widget.controlsLocked,
                                  notifier: notifier,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      if (widget.settings.storageDestinationMode ==
                          StorageDestinationMode.differentLocation) ...[
                        if (widget.settings.differentLocationPath
                            case final path?)
                          Padding(
                            padding: const EdgeInsets.only(top: 10, left: 4),
                            child: Text(
                              path,
                              style: TextStyle(
                                color: theme.colorScheme.mutedForeground,
                              ),
                            ).xSmall(),
                          ),
                        const SizedBox(height: 10),
                        Checkbox(
                          state: widget.settings.preserveFolderStructure
                              ? CheckboxState.checked
                              : CheckboxState.unchecked,
                          onChanged: widget.controlsLocked
                              ? null
                              : (value) {
                                  notifier.setPreserveFolderStructure(
                                    value == CheckboxState.checked,
                                  );
                                },
                          trailing: Expanded(
                            child: Text(
                              'Preserve folder structure',
                              style: TextStyle(
                                color: theme.colorScheme.mutedForeground,
                              ),
                            ).small(),
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

class _KeepSourceNamingControls extends StatelessWidget {
  const _KeepSourceNamingControls({
    required this.settings,
    required this.controlsLocked,
    required this.notifier,
  });

  final AppSettings settings;
  final bool controlsLocked;
  final AppSettingsController notifier;

  @override
  Widget build(BuildContext context) {
    final suffix = settings.keepSourceNaming == KeepSourceNaming.renameOriginal
        ? settings.keepSourceOriginalSuffix
        : settings.keepSourceOptimizedSuffix;
    return Padding(
      padding: const EdgeInsets.only(left: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioGroup<KeepSourceNaming>(
            value: settings.keepSourceNaming,
            onChanged: controlsLocked ? null : notifier.setKeepSourceNaming,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RadioItem<KeepSourceNaming>(
                  value: KeepSourceNaming.renameOptimized,
                  enabled: !controlsLocked,
                  trailing: const Text('Rename optimized').small(),
                ),
                const SizedBox(height: 8),
                RadioItem<KeepSourceNaming>(
                  value: KeepSourceNaming.renameOriginal,
                  enabled: !controlsLocked,
                  trailing: const Text('Rename original').small(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const _SettingsLabel('Suffix'),
              const SizedBox(width: 10),
              SizedBox(
                width: 160,
                child: TextField(
                  key: ValueKey(
                    'keep-source-suffix-${settings.keepSourceNaming.name}',
                  ),
                  initialValue: suffix,
                  enabled: !controlsLocked,
                  onChanged: (value) {
                    if (settings.keepSourceNaming ==
                        KeepSourceNaming.renameOriginal) {
                      unawaited(notifier.setKeepSourceOriginalSuffix(value));
                      return;
                    }
                    unawaited(notifier.setKeepSourceOptimizedSuffix(value));
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
