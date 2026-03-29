import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oimg/src/file_open/file_open_channel.dart';
import 'package:oimg/src/file_open/file_open_controller.dart';
import 'package:oimg/src/rust/frb_generated.dart';
import 'package:oimg/src/settings/app_settings.dart';
import 'package:oimg/src/settings/app_settings_controller.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart';

const _uiScale = 0.8;
const _uiRadius = 0.4;
const _titleBarHeight = 24.0;
const _defaultSidebarWidth = 280.0;
const _minSidebarWidth = 180.0;
const _maxSidebarWidth = 420.0;
const _settingsSidebarWidth = 280.0;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureWindow();
  await RustLib.init();

  final controller = FileOpenController(
    channel: MethodChannelFileOpenChannel(),
    initialPaths: args,
  );
  await controller.initialize();

  runApp(ProviderScope(child: MyApp(controller: controller)));
}

Future<void> _configureWindow() async {
  if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
    return;
  }

  await windowManager.ensureInitialized();
  final windowOptions = WindowOptions(
    size: const Size(1280, 720),
    center: true,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  unawaited(
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    }),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.controller});

  final FileOpenController controller;

  @override
  Widget build(BuildContext context) {
    final baseTypography = const Typography.geist().scale(_uiScale);

    return ShadcnApp(
      title: 'OIMG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorSchemes.lightSlate,
        radius: _uiRadius,
        scaling: _uiScale,
        typography: baseTypography,
        surfaceOpacity: 0.92,
        surfaceBlur: 8,
      ),
      darkTheme: ThemeData.dark(
        colorScheme: ColorSchemes.darkSlate,
        radius: _uiRadius,
        scaling: _uiScale,
        typography: baseTypography,
        surfaceOpacity: 0.88,
        surfaceBlur: 12,
      ),
      themeMode: ThemeMode.system,
      home: OimgHomePage(controller: controller),
    );
  }
}

class OimgHomePage extends ConsumerStatefulWidget {
  const OimgHomePage({super.key, required this.controller});

  final FileOpenController controller;

  @override
  ConsumerState<OimgHomePage> createState() => _OimgHomePageState();
}

class _OimgHomePageState extends ConsumerState<OimgHomePage> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final notice = widget.controller.takePendingNotice();
    if (notice == null || !mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      showToast(
        context: context,
        location: ToastLocation.topRight,
        builder: (context, overlay) {
          final theme = Theme.of(context);
          return Card(
            borderRadius: theme.borderRadiusLg,
            child: Row(
              children: [
                Icon(
                  LucideIcons.triangleAlert,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unsupported files',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notice,
                        style: TextStyle(
                          color: theme.colorScheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GhostButton(
                  onPressed: overlay.close,
                  density: ButtonDensity.icon,
                  child: const Icon(LucideIcons.x),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final title =
            widget.controller.currentFileName ??
            'Open images from your desktop';

        return Scaffold(
          headers: [
            AppBar(
              height: _titleBarHeight,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Positioned.fill(
                    child: DragToMoveArea(child: Center(child: Text('OIMG'))),
                  ),
                  if (widget.controller.currentPositionLabel
                      case final position?)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Card(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(position),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(),
          ],
          child: widget.controller.hasSession
              ? _ImageSessionView(controller: widget.controller, title: title)
              : const _EmptyState(),
        );
      },
    );
  }
}

class _ImageSessionView extends StatefulWidget {
  const _ImageSessionView({required this.controller, required this.title});

  final FileOpenController controller;
  final String title;

  @override
  State<_ImageSessionView> createState() => _ImageSessionViewState();
}

class _ImageSessionViewState extends State<_ImageSessionView> {
  double _sidebarWidth = _defaultSidebarWidth;

  @override
  Widget build(BuildContext context) {
    final currentPath = widget.controller.currentPath;
    final currentFileName = widget.controller.currentFileName;
    if (currentPath == null || currentFileName == null) {
      return const _EmptyState();
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wideLayout = constraints.maxWidth >= 980;
          final sidebar = _ExplorerSidebar(controller: widget.controller);
          final stage = _ImageStage(
            title: widget.title,
            currentPath: currentPath,
            currentFileName: currentFileName,
          );
          const settingsSidebar = _SettingsSidebar();

          if (wideLayout) {
            final maxWidth = _clampSidebarWidth(constraints.maxWidth * 0.45);
            final sidebarWidth = _sidebarWidth.clamp(
              _minSidebarWidth,
              maxWidth,
            );
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: sidebarWidth, child: sidebar),
                _SidebarResizeHandle(
                  onDragUpdate: (delta) {
                    setState(() {
                      _sidebarWidth = _clampSidebarWidth(
                        _sidebarWidth + delta,
                        maxWidth: maxWidth,
                      );
                    });
                  },
                ),
                const SizedBox(width: 12),
                Expanded(child: stage),
                const SizedBox(width: 12),
                const SizedBox(
                  width: _settingsSidebarWidth,
                  child: settingsSidebar,
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 220, child: sidebar),
              const SizedBox(height: 16),
              Expanded(child: stage),
              const SizedBox(height: 16),
              const SizedBox(height: 320, child: settingsSidebar),
            ],
          );
        },
      ),
    );
  }

  double _clampSidebarWidth(double width, {double? maxWidth}) {
    return width.clamp(_minSidebarWidth, maxWidth ?? _maxSidebarWidth);
  }
}

class _SidebarResizeHandle extends StatelessWidget {
  const _SidebarResizeHandle({required this.onDragUpdate});

  final ValueChanged<double> onDragUpdate;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) => onDragUpdate(details.delta.dx),
        child: const SizedBox(width: 8),
      ),
    );
  }
}

class _ImageStage extends StatelessWidget {
  const _ImageStage({
    required this.title,
    required this.currentPath,
    required this.currentFileName,
  });

  final String title;
  final String currentPath;
  final String currentFileName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      padding: EdgeInsets.zero,
      borderRadius: theme.borderRadiusXl,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentPath,
                  style: TextStyle(color: theme.colorScheme.mutedForeground),
                ).xSmall(),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: Container(
              color: theme.colorScheme.background,
              padding: const EdgeInsets.all(10),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 6,
                child: Container(
                  alignment: Alignment.center,
                  child: Image.file(
                    File(currentPath),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
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
                              'Unable to load $currentFileName.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.colorScheme.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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

class _ExplorerSidebar extends StatelessWidget {
  const _ExplorerSidebar({required this.controller});

  final FileOpenController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nodes = _buildExplorerNodes(controller);

    return Card(
      padding: EdgeInsets.zero,
      borderRadius: theme.borderRadiusXl,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Text(
              'Files',
              style: TextStyle(
                color: theme.colorScheme.mutedForeground,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ).xSmall(),
          ),
          const Divider(),
          Expanded(
            child: TreeView<_ExplorerEntry>(
              nodes: nodes,
              branchLine: BranchLine.none,
              expandIcon: false,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              builder: (context, node) {
                final entry = node.data;
                return TreeItemView(
                  leading: Icon(
                    entry.isDirectory ? LucideIcons.folder : LucideIcons.image,
                    size: 16,
                    color: entry.isDirectory
                        ? theme.colorScheme.mutedForeground
                        : theme.colorScheme.foreground,
                  ),
                  trailing: entry.sizeLabel == null
                      ? null
                      : Text(entry.sizeLabel!).small().muted(),
                  expandable: false,
                  onPressed: entry.isDirectory
                      ? null
                      : () => controller.showPath(entry.path),
                  child: Text(entry.label).small().mediumIf(entry.isDirectory),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<TreeNode<_ExplorerEntry>> _buildExplorerNodes(
    FileOpenController controller,
  ) {
    final groups = <String, List<String>>{};
    for (final path in controller.sessionPaths) {
      final directory = _directoryOf(path);
      groups.putIfAbsent(directory, () => <String>[]).add(path);
    }

    return groups.entries
        .map((entry) {
          return TreeItem<_ExplorerEntry>(
            data: _ExplorerEntry.directory(
              label: _directoryLabel(entry.key),
              path: entry.key,
            ),
            expanded: true,
            children: entry.value
                .map((path) {
                  return TreeItem<_ExplorerEntry>(
                    data: _ExplorerEntry.file(
                      label: FileOpenController.fileNameOf(path),
                      path: path,
                      sizeLabel: _fileSizeLabel(path),
                    ),
                    selected: path == controller.currentPath,
                  );
                })
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }

  static String _directoryOf(String path) {
    final normalized = path.replaceAll('\\', '/');
    final separator = normalized.lastIndexOf('/');
    if (separator < 0) {
      return '.';
    }
    if (separator == 0) {
      return '/';
    }
    return normalized.substring(0, separator);
  }

  static String _directoryLabel(String directory) {
    final label = FileOpenController.fileNameOf(directory);
    if (label.isNotEmpty) {
      return label;
    }
    return directory;
  }
}

class _ExplorerEntry {
  const _ExplorerEntry._({
    required this.label,
    required this.path,
    required this.sizeLabel,
    required this.isDirectory,
  });

  const _ExplorerEntry.directory({required String label, required String path})
    : this._(label: label, path: path, sizeLabel: null, isDirectory: true);

  const _ExplorerEntry.file({
    required String label,
    required String path,
    required String? sizeLabel,
  }) : this._(
         label: label,
         path: path,
         sizeLabel: sizeLabel,
         isDirectory: false,
       );

  final String label;
  final String path;
  final String? sizeLabel;
  final bool isDirectory;
}

class _SettingsSidebar extends ConsumerWidget {
  const _SettingsSidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Card(
      padding: EdgeInsets.zero,
      borderRadius: theme.borderRadiusXl,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      color: theme.colorScheme.mutedForeground,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ).xSmall(),
                ),
                settings.when(
                  data: (settings) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Advanced',
                          style: TextStyle(
                            color: theme.colorScheme.mutedForeground,
                          ),
                        ).xSmall(),
                        const SizedBox(width: 8),
                        Switch(
                          value: settings.advancedMode,
                          onChanged: notifier.setAdvancedMode,
                        ),
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: settings.when(
                data: (settings) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (settings.advancedMode) ...[
                        _SettingsLabel('Codec'),
                        const SizedBox(height: 8),
                        RadioGroup<PreferredCodec>(
                          value: settings.preferredCodec,
                          onChanged: notifier.setPreferredCodec,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final cardWidth = (constraints.maxWidth - 8) / 2;
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: PreferredCodec.values
                                    .map(
                                      (codec) => SizedBox(
                                        width: cardWidth,
                                        child: RadioCard<PreferredCodec>(
                                          value: codec,
                                          child: _ChoiceCard(
                                            title: _codecLabel(codec),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(growable: false),
                              );
                            },
                          ),
                        ),
                      ] else ...[
                        _SettingsLabel('Compression'),
                        const SizedBox(height: 8),
                        RadioGroup<CompressionMethod>(
                          value: settings.compressionMethod,
                          onChanged: notifier.setCompressionMethod,
                          child: Row(
                            children: [
                              Expanded(
                                child: RadioCard<CompressionMethod>(
                                  value: CompressionMethod.lossless,
                                  child: const _ChoiceCard(title: 'Lossless'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RadioCard<CompressionMethod>(
                                  value: CompressionMethod.lossy,
                                  child: const _ChoiceCard(title: 'Lossy'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _SettingsLabel('Priority'),
                        const SizedBox(height: 8),
                        RadioGroup<CompressionPriority>(
                          value: settings.compressionPriority,
                          onChanged: notifier.setCompressionPriority,
                          child: Row(
                            children: [
                              Expanded(
                                child: RadioCard<CompressionPriority>(
                                  value: CompressionPriority.compatibility,
                                  child: const _ChoiceCard(
                                    title: 'Compatibility',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: RadioCard<CompressionPriority>(
                                  value: CompressionPriority.efficiency,
                                  child: const _ChoiceCard(
                                    title: 'Efficiency',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (settings.showsQualityControl) ...[
                        _SettingsLabel('Quality'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('0').xSmall().muted(),
                            const Spacer(),
                            Text(_qualityValueLabel(settings))
                                .xSmall()
                                .medium()
                                .muted(),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: SliderValue.single(settings.quality.toDouble()),
                          min: 0,
                          max: 100,
                          divisions: 100,
                          onChanged: (value) {
                            notifier.setQuality(value.value.round());
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                      _SettingsLabel('Current codec'),
                      const SizedBox(height: 8),
                      Text(_codecLabel(settings.effectiveCodec)).small().medium(),
                    ],
                  );
                },
                loading: () => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: const Text('Loading settings').small(),
                  ),
                ),
                error: (_, _) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: const Text('Unable to load settings')
                        .small()
                        .muted(),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsLabel extends StatelessWidget {
  const _SettingsLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label).xSmall().medium().muted();
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Basic(
      title: Text(title).small().medium(),
    );
  }
}

extension on Widget {
  Widget mediumIf(bool condition) {
    if (!condition) {
      return this;
    }
    return medium();
  }
}

String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unitIndex = 0;

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }

  final fractionDigits = value >= 10 || unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
}

String? _fileSizeLabel(String path) {
  try {
    return _formatBytes(File(path).lengthSync());
  } catch (_) {
    return null;
  }
}

String _codecLabel(PreferredCodec codec) {
  return switch (codec) {
    PreferredCodec.png => 'PNG',
    PreferredCodec.jpeg => 'JPEG',
    PreferredCodec.webp => 'WebP',
    PreferredCodec.avif => 'AVIF',
    PreferredCodec.jxl => 'JPEG XL',
  };
}

String _qualityValueLabel(AppSettings settings) {
  if (settings.quality == 100 && settings.qualitySupportsLosslessAtMax) {
    return 'Lossless';
  }

  return '${settings.quality}';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                borderRadius: theme.borderRadiusXxl,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(color: theme.colorScheme.border),
                          borderRadius: theme.borderRadiusLg,
                        ),
                        child: Icon(
                          LucideIcons.image,
                          size: 28,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Open an image with OIMG',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22.4,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
