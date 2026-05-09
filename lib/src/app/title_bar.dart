part of 'package:oimg/main.dart';

IconData _themePreferenceIcon(AppThemePreference preference) {
  return switch (preference) {
    AppThemePreference.system => LucideIcons.monitor,
    AppThemePreference.light => LucideIcons.sun,
    AppThemePreference.dark => LucideIcons.moon,
  };
}

class _DeveloperButton extends StatelessWidget {
  const _DeveloperButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 16,
      height: 16,
      child: Center(
        child: GhostButton(
          key: const ValueKey('title-bar-developer-button'),
          size: ButtonSize.xSmall,
          density: ButtonDensity.iconDense,
          onPressed: onPressed,
          child: Icon(
            LucideIcons.wrench,
            size: 10,
            color: theme.colorScheme.mutedForeground.withValues(alpha: 0.05),
          ),
        ),
      ),
    );
  }
}

class _TitleBarSettingsButton extends ConsumerWidget {
  const _TitleBarSettingsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasSettings = ref.watch(appSettingsProvider).hasValue;

    return SizedBox(
      width: 16,
      height: 16,
      child: Center(
        child: GhostButton(
          key: const ValueKey('title-bar-settings-button'),
          size: ButtonSize.xSmall,
          density: ButtonDensity.iconDense,
          onPressed: !hasSettings
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
                          final packageVersion = ref
                              .watch(_packageVersionProvider)
                              .asData
                              ?.value;
                          if (settings == null) {
                            return const SizedBox.shrink();
                          }
                          return DropdownMenu(
                            children: [
                              MenuButton(
                                enabled: false,
                                key: const ValueKey('title-bar-settings-label'),
                                child: const Text(
                                  'Settings',
                                ).xSmall().medium().muted(),
                              ),
                              MenuButton(
                                key: const ValueKey('title-bar-theme-toggle'),
                                autoClose: false,
                                trailing: Icon(
                                  _themePreferenceIcon(
                                    settings.themePreference,
                                  ),
                                  size: 15,
                                ),
                                onPressed: (context) {
                                  unawaited(
                                    ref
                                        .read(appSettingsProvider.notifier)
                                        .cycleThemePreference(),
                                  );
                                },
                                child: const Text('Theme'),
                              ),
                              MenuButton(
                                key: const ValueKey(
                                  'title-bar-color-scheme-toggle',
                                ),
                                autoClose: false,
                                trailing: Text(
                                  settings.colorSchemePreference.label,
                                ).xSmall().muted(),
                                onPressed: (context) {
                                  unawaited(
                                    ref
                                        .read(appSettingsProvider.notifier)
                                        .cycleColorSchemePreference(),
                                  );
                                },
                                child: const Text('Color'),
                              ),
                              const MenuDivider(),
                              MenuButton(
                                enabled: false,
                                key: const ValueKey(
                                  'title-bar-community-label',
                                ),
                                child: const Text(
                                  'Community',
                                ).xSmall().medium().muted(),
                              ),
                              MenuButton(
                                key: const ValueKey(
                                  'title-bar-bug-tracker-button',
                                ),
                                child: const Text('Bug Tracker'),
                                onPressed: (context) {
                                  unawaited(
                                    launchUrl(
                                      Uri.parse(
                                        'https://github.com/oimg/issues',
                                      ),
                                      mode: LaunchMode.externalApplication,
                                    ),
                                  );
                                },
                              ),
                              MenuButton(
                                key: const ValueKey('title-bar-blog-button'),
                                child: const Text('Blog'),
                                onPressed: (context) {
                                  unawaited(
                                    launchUrl(
                                      Uri.parse('https://oimg.substack.com'),
                                      mode: LaunchMode.externalApplication,
                                    ),
                                  );
                                },
                              ),
                              const MenuDivider(),
                              MenuLabel(
                                key: const ValueKey('title-bar-app-name-label'),
                                trailing: KeyedSubtree(
                                  key: const ValueKey(
                                    'title-bar-version-label',
                                  ),
                                  child: Text(
                                    packageVersion == null
                                        ? 'v'
                                        : 'v$packageVersion',
                                  ).xSmall().muted(),
                                ),
                                child: const Text('OIMG'),
                              ),
                              MenuButton(
                                key: const ValueKey('title-bar-donate-button'),
                                child: const Text('Donate'),
                                onPressed: (context) {
                                  unawaited(
                                    launchUrl(
                                      Uri.parse(
                                        'https://github.com/sponsors/yunho-c',
                                      ),
                                      mode: LaunchMode.externalApplication,
                                    ),
                                  );
                                },
                              ),
                              MenuButton(
                                key: const ValueKey(
                                  'title-bar-contributors-button',
                                ),
                                child: const Text('Contributors'),
                                onPressed: (context) {
                                  unawaited(
                                    launchUrl(
                                      Uri.parse(
                                        'https://github.com/yunho-c/oimg/graphs/contributors',
                                      ),
                                      mode: LaunchMode.externalApplication,
                                    ),
                                  );
                                },
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
            color: theme.colorScheme.mutedForeground.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

class _TitleBarHomeButton extends StatelessWidget {
  const _TitleBarHomeButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 16,
      height: 16,
      child: Center(
        child: GhostButton(
          key: const ValueKey('title-bar-home-button'),
          size: ButtonSize.xSmall,
          density: ButtonDensity.iconDense,
          onPressed: onPressed,
          child: Icon(
            Icons.home,
            size: 11,
            color: theme.colorScheme.mutedForeground.withValues(alpha: 0.35),
          ),
        ),
      ),
    );
  }
}

class _TitleBarCaptionControls extends StatelessWidget {
  const _TitleBarCaptionControls();

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const ValueKey('title-bar-caption-controls'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _TitleBarCaptionButton(
          key: const ValueKey('title-bar-minimize-button'),
          label: 'Minimize',
          icon: LucideIcons.minus,
          onPressed: () {
            unawaited(windowManager.minimize());
          },
        ),
        _TitleBarCaptionButton(
          key: const ValueKey('title-bar-maximize-button'),
          label: 'Maximize',
          icon: LucideIcons.square,
          onPressed: () {
            unawaited(_toggleMaximizeWindow());
          },
        ),
        _TitleBarCaptionButton(
          key: const ValueKey('title-bar-close-button'),
          label: 'Close',
          icon: LucideIcons.x,
          isClose: true,
          onPressed: () {
            unawaited(windowManager.close());
          },
        ),
      ],
    );
  }
}

Future<void> _toggleMaximizeWindow() async {
  if (await windowManager.isMaximized()) {
    await windowManager.unmaximize();
  } else {
    await windowManager.maximize();
  }
}

class _TitleBarCaptionButton extends StatefulWidget {
  const _TitleBarCaptionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isClose = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isClose;

  @override
  State<_TitleBarCaptionButton> createState() => _TitleBarCaptionButtonState();
}

class _TitleBarCaptionButtonState extends State<_TitleBarCaptionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = _hovered || _pressed;
    final closeActive = widget.isClose && active;
    final backgroundColor = closeActive
        ? const Color(0xffC42B1C).withValues(alpha: _pressed ? 0.88 : 1)
        : active
        ? theme.colorScheme.muted.withValues(alpha: _pressed ? 0.55 : 0.7)
        : Colors.transparent;
    final iconColor = closeActive
        ? Colors.white
        : theme.colorScheme.mutedForeground.withValues(alpha: 0.72);

    return Tooltip(
      waitDuration: const Duration(milliseconds: 250),
      showDuration: const Duration(milliseconds: 120),
      tooltip: (context) => TooltipContainer(child: Text(widget.label)),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: SizedBox(
            width: 28,
            height: _titleBarHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(color: backgroundColor),
              child: Center(
                child: Icon(widget.icon, size: 10, color: iconColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeveloperSettingsDialog extends ConsumerWidget {
  const _DeveloperSettingsDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return AlertDialog(
      title: const Text('Developer'),
      content: SizedBox(
        width: 640,
        child: settings.when(
          data: (settings) {
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DeveloperSection(
                    title: 'Mode',
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Developer mode').small().medium(),
                              const SizedBox(height: 4),
                              Text(
                                'Unlock diagnostics and internal controls.',
                              ).xSmall().muted(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Switch(
                          value: settings.developerModeEnabled,
                          onChanged: notifier.setDeveloperModeEnabled,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DeveloperSection(
                    title: 'Diagnostics',
                    child: Column(
                      children: [
                        Checkbox(
                          state: settings.timingLogsEnabled
                              ? CheckboxState.checked
                              : CheckboxState.unchecked,
                          onChanged: settings.developerModeEnabled
                              ? (value) {
                                  notifier.setTimingLogsEnabled(
                                    value == CheckboxState.checked,
                                  );
                                }
                              : null,
                          trailing: Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Timing logs').small().medium(),
                                const SizedBox(height: 4),
                                Text(
                                  'Measure preview and optimize timings in Dart and Rust.',
                                ).xSmall().muted(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Checkbox(
                          state: settings.previewPathHeaderEnabled
                              ? CheckboxState.checked
                              : CheckboxState.unchecked,
                          onChanged: settings.developerModeEnabled
                              ? (value) {
                                  notifier.setPreviewPathHeaderEnabled(
                                    value == CheckboxState.checked,
                                  );
                                }
                              : null,
                          trailing: Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Preview path header').small().medium(),
                                const SizedBox(height: 4),
                                Text(
                                  'Show the directory and file name above the preview.',
                                ).xSmall().muted(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DeveloperSection(
                    title: 'Home',
                    child: Column(
                      children: [
                        _DeveloperShaderSpeedField(
                          value: settings.homeShaderSpeed,
                          enabled: settings.developerModeEnabled,
                          onChanged: notifier.setHomeShaderSpeed,
                        ),
                        const SizedBox(height: 10),
                        Checkbox(
                          key: const ValueKey(
                            'developer-home-acrylic-panel-toggle',
                          ),
                          state: settings.homeAcrylicPanelEnabled
                              ? CheckboxState.checked
                              : CheckboxState.unchecked,
                          onChanged: settings.developerModeEnabled
                              ? (value) {
                                  notifier.setHomeAcrylicPanelEnabled(
                                    value == CheckboxState.checked,
                                  );
                                }
                              : null,
                          trailing: Expanded(
                            child: Text('Acrylic panel').small().medium(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DeveloperSection(
                    title: 'Window',
                    child: Checkbox(
                      state: settings.macOsCaptionButtonsEnabled
                          ? CheckboxState.checked
                          : CheckboxState.unchecked,
                      onChanged: settings.developerModeEnabled
                          ? (value) {
                              notifier.setMacOsCaptionButtonsEnabled(
                                value == CheckboxState.checked,
                              );
                            }
                          : null,
                      trailing: Expanded(
                        child: Text(
                          'Caption buttons on macOS',
                        ).small().medium(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const SizedBox(
            height: 320,
            child: Center(child: Text('Loading developer settings')),
          ),
          error: (_, _) => const SizedBox(
            height: 320,
            child: Center(child: Text('Unable to load developer settings')),
          ),
        ),
      ),
      actions: [
        OutlineButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _DeveloperShaderSpeedField extends StatelessWidget {
  const _DeveloperShaderSpeedField({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text('Shader speed').small().medium()),
        const SizedBox(width: 12),
        SizedBox(
          width: 96,
          child: TextField(
            key: const ValueKey('developer-home-shader-speed-field'),
            initialValue: value.toStringAsFixed(2),
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.end,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            onChanged: (value) {
              final parsed = double.tryParse(value);
              if (parsed == null || parsed.isNaN || parsed.isInfinite) {
                return;
              }
              onChanged(parsed.clamp(0.0, 4.0).toDouble());
            },
          ),
        ),
        const SizedBox(width: 8),
        Text('x').small().muted(),
      ],
    );
  }
}

class _DeveloperSection extends StatelessWidget {
  const _DeveloperSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      padding: const EdgeInsets.all(18),
      borderRadius: theme.borderRadiusXl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title).xSmall().medium().muted(),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
