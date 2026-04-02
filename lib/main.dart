import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oimg/src/file_open/file_open_channel.dart';
import 'package:oimg/src/file_open/file_open_controller.dart';
import 'package:oimg/src/file_open/file_open_providers.dart';
import 'package:oimg/src/file_open/opened_image_file.dart';
import 'package:oimg/src/optimization/optimization_plan.dart';
import 'package:oimg/src/optimization/optimization_providers.dart';
import 'package:oimg/src/rust/frb_generated.dart';
import 'package:oimg/src/rust/slimg_api.dart';
import 'package:oimg/src/settings/app_settings.dart';
import 'package:oimg/src/settings/app_settings_controller.dart';
import 'package:oimg/src/settings/developer_diagnostics.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:window_manager/window_manager.dart';

const _uiScale = 0.8;
const _uiRadius = 0.4;
const _titleBarHeight = 24.0;
const _defaultSidebarWidth = 280.0;
const _minSidebarWidth = 180.0;
const _maxSidebarWidth = 420.0;
const _settingsSidebarWidth = 320.0;
const _bottomSidebarHeight = 188.0;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureWindow();
  await RustLib.init();

  const slimgApi = FrbSlimgApi();
  final controller = FileOpenController(
    channel: MethodChannelFileOpenChannel(),
    slimg: slimgApi,
    initialPaths: args,
  );
  await controller.initialize();

  runApp(
    ProviderScope(
      overrides: [
        slimgApiProvider.overrideWithValue(slimgApi),
        fileOpenControllerProvider.overrideWith((ref) => controller),
      ],
      child: const MyApp(),
    ),
  );
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
  const MyApp({super.key});

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
      home: const OimgHomePage(),
    );
  }
}

class OimgHomePage extends ConsumerStatefulWidget {
  const OimgHomePage({super.key});

  @override
  ConsumerState<OimgHomePage> createState() => _OimgHomePageState();
}

class _OimgHomePageState extends ConsumerState<OimgHomePage> {
  late final FileOpenController _controller;
  late final ProviderSubscription<AsyncValue<AppSettings>>
  _appSettingsSubscription;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(fileOpenControllerProvider);
    _controller.addListener(_onControllerChanged);
    _appSettingsSubscription = ref.listenManual<AsyncValue<AppSettings>>(
      appSettingsProvider,
      (previous, next) {
        next.whenData(_syncDeveloperSettings);
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _appSettingsSubscription.close();
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final notice = _controller.takePendingNotice();
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
                  child: Text(
                    notice,
                    style: TextStyle(
                      color: theme.colorScheme.mutedForeground,
                    ),
                  ).small(),
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

  void _syncDeveloperSettings(AppSettings settings) {
    final enabled =
        settings.developerModeEnabled && settings.timingLogsEnabled;
    DeveloperDiagnostics.setTimingLogsEnabled(enabled);
    ref.read(slimgApiProvider).setTimingLogsEnabled(enabled: enabled);
  }

  Future<void> _openDeveloperDialog() {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return const _DeveloperSettingsDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(fileOpenControllerProvider);
    final title =
        controller.currentDisplayTitle ?? 'Open images from your desktop';

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
              if (controller.currentPositionLabel case final position?)
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Card(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(position),
                      ),
                      const SizedBox(width: 6),
                      _DeveloperButton(
                        onPressed: () {
                          unawaited(_openDeveloperDialog());
                        },
                      ),
                    ],
                  ),
                ),
              if (controller.currentPositionLabel == null)
                Align(
                  alignment: Alignment.centerRight,
                  child: _DeveloperButton(
                    onPressed: () {
                      unawaited(_openDeveloperDialog());
                    },
                  ),
                ),
            ],
          ),
        ),
        const Divider(),
      ],
      child: _FileDropSurface(
        child: controller.hasSession
            ? _ImageSessionView(title: title)
            : const _EmptyState(),
      ),
    );
  }
}

class _FileDropSurface extends ConsumerStatefulWidget {
  const _FileDropSurface({required this.child});

  final Widget child;

  @override
  ConsumerState<_FileDropSurface> createState() => _FileDropSurfaceState();
}

class _FileDropSurfaceState extends ConsumerState<_FileDropSurface> {
  bool _isDragOver = false;
  late bool _dropSurfaceReady;

  @override
  void initState() {
    super.initState();
    _dropSurfaceReady = !Platform.isMacOS;
    if (!_dropSurfaceReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_enableDropSurface());
      });
    }
  }

  Future<void> _enableDropSurface() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return;
    }
    setState(() {
      _dropSurfaceReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_dropSurfaceReady) {
      return widget.child;
    }

    return DropRegion(
      formats: const [Formats.fileUri],
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        final hasFileUri = event.session.items.any(
          (item) => item.canProvide(Formats.fileUri),
        );
        if (!hasFileUri) {
          return DropOperation.none;
        }

        return event.session.allowedOperations.contains(DropOperation.copy)
            ? DropOperation.copy
            : DropOperation.none;
      },
      onDropEnter: (_) {
        setState(() {
          _isDragOver = true;
        });
      },
      onDropLeave: (_) {
        setState(() {
          _isDragOver = false;
        });
      },
      onDropEnded: (_) {
        if (!_isDragOver) {
          return;
        }
        setState(() {
          _isDragOver = false;
        });
      },
      onPerformDrop: (event) async {
        final paths = await _readDroppedPaths(event);
        if (!mounted) {
          return;
        }

        setState(() {
          _isDragOver = false;
        });

        if (paths.isEmpty) {
          return;
        }

        await ref.read(fileOpenControllerProvider).openPaths(paths);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (_isDragOver)
            IgnorePointer(
              child: Container(
                margin: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.6),
                    width: 2,
                  ),
                  borderRadius: theme.borderRadiusXxl,
                ),
                child: Center(
                  child: Card(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    borderRadius: theme.borderRadiusXl,
                    child: const Text('Drop files or folders here').small(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<List<String>> _readDroppedPaths(PerformDropEvent event) async {
    final paths = <String>[];

    for (final item in event.session.items) {
      final reader = item.dataReader;
      if (reader == null || !reader.canProvide(Formats.fileUri)) {
        continue;
      }

      final uri = await _readDroppedFileUri(reader);
      if (uri == null || uri.scheme != 'file') {
        continue;
      }
      paths.add(uri.toFilePath());
    }

    return paths;
  }

  Future<Uri?> _readDroppedFileUri(Object reader) {
    final completer = Completer<Uri?>();
    final progress = (reader as dynamic).getValue<Uri>(
      Formats.fileUri,
      (value) {
        if (!completer.isCompleted) {
          completer.complete(value);
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );
    if (progress == null && !completer.isCompleted) {
      completer.complete(null);
    }
    return completer.future;
  }
}

class _ImageSessionView extends ConsumerStatefulWidget {
  const _ImageSessionView({required this.title});

  final String title;

  @override
  ConsumerState<_ImageSessionView> createState() => _ImageSessionViewState();
}

class _ImageSessionViewState extends ConsumerState<_ImageSessionView> {
  double _sidebarWidth = _defaultSidebarWidth;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(fileOpenControllerProvider);
    final currentFile = controller.currentFile;
    if (currentFile == null) {
      return const _EmptyState();
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wideLayout = constraints.maxWidth >= 1120;
          final sidebar = _ExplorerSidebar(controller: controller);
          final stage = controller.isFolderSelected
              ? _FolderStage(controller: controller)
              : _ImageStage(title: widget.title, currentFile: currentFile);
          const settingsSidebar = _SettingsSidebar();
          final bottomSidebar = _BottomSidebar(controller: controller);

          if (wideLayout) {
            final maxWidth = _clampSidebarWidth(constraints.maxWidth * 0.38);
            final sidebarWidth = _sidebarWidth.clamp(
              _minSidebarWidth,
              maxWidth,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Row(
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
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(height: _bottomSidebarHeight, child: bottomSidebar),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 220, child: sidebar),
                    const SizedBox(height: 16),
                    Expanded(child: stage),
                    const SizedBox(height: 16),
                    const SizedBox(height: 420, child: settingsSidebar),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(height: _bottomSidebarHeight, child: bottomSidebar),
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

class _ImageStage extends ConsumerWidget {
  const _ImageStage({required this.title, required this.currentFile});

  final String title;
  final OpenedImageFile currentFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plan = ref.watch(currentOptimizationPlanProvider);
    final preview = ref.watch(currentPreviewProvider);

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
                  currentFile.path,
                  style: TextStyle(color: theme.colorScheme.mutedForeground),
                ).xSmall(),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${currentFile.metadata.width} x ${currentFile.metadata.height}',
                      textAlign: TextAlign.right,
                      style: TextStyle(color: theme.colorScheme.mutedForeground),
                    ).xSmall(),
                  ],
                ),
                if (preview.hasError) ...[
                  const SizedBox(height: 10),
                  Text('Preview unavailable').xSmall().muted(),
                ],
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: Container(
              color: theme.colorScheme.background,
              padding: const EdgeInsets.all(10),
              child: plan.when(
                data: (plan) {
                  final useSourceImage = plan?.useSourceImageForPreview ?? false;
                  return preview.when(
                    data: (preview) => _PreviewCanvas(
                      path: currentFile.path,
                      fileName: FileOpenController.fileNameOf(currentFile.path),
                      preview: useSourceImage ? null : preview,
                    ),
                    loading: () => useSourceImage
                        ? _PreviewCanvas(
                            path: currentFile.path,
                            fileName: FileOpenController.fileNameOf(
                              currentFile.path,
                            ),
                            preview: null,
                          )
                        : const Center(child: CircularProgressIndicator()),
                    error: (_, _) => _PreviewCanvas(
                      path: currentFile.path,
                      fileName: FileOpenController.fileNameOf(currentFile.path),
                      preview: null,
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => _PreviewCanvas(
                  path: currentFile.path,
                  fileName: FileOpenController.fileNameOf(currentFile.path),
                  preview: null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderStage extends StatelessWidget {
  const _FolderStage({required this.controller});

  final FileOpenController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folderPath = controller.selectedFolderPath;
    final folderFiles = controller.selectedFolderFiles;
    final totalBytes = controller.selectedFolderSizeBytes;
    if (folderPath == null) {
      return const SizedBox.shrink();
    }

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
                  folderPath,
                  style: TextStyle(color: theme.colorScheme.mutedForeground),
                ).xSmall(),
                const SizedBox(height: 4),
                Text(
                  controller.selectedFolderName ?? folderPath,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _PreviewMetaItem(
                      label: 'Images',
                      value: '${folderFiles.length}',
                    ),
                    if (totalBytes case final bytes?)
                      _PreviewMetaItem(
                        label: 'Size',
                        value: _formatBytes(bytes),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: Container(
              color: theme.colorScheme.background,
              padding: const EdgeInsets.all(14),
              child: _FolderCollage(
                files: folderFiles,
                onOpenFile: controller.showPath,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCanvas extends StatelessWidget {
  const _PreviewCanvas({
    required this.path,
    required this.fileName,
    required this.preview,
  });

  final String path;
  final String fileName;
  final OptimizationPreview? preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 6,
      child: Container(
        alignment: Alignment.center,
        child: preview == null
            ? Image.file(
                File(path),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return _ImageLoadError(fileName: fileName);
                },
              )
            : Image.memory(
                preview!.result.encodedBytes,
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
                          'Unable to render optimized preview.',
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
    );
  }
}

class _FolderCollage extends StatelessWidget {
  const _FolderCollage({
    required this.files,
    required this.onOpenFile,
  });

  final List<OpenedImageFile> files;
  final ValueChanged<String> onOpenFile;

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
        final tileWidth = (constraints.maxWidth - totalSpacing) / crossAxisCount;

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
  });

  final OpenedImageFile file;
  final double tileWidth;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = math.max(1, (tileWidth * devicePixelRatio).round());

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
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
                  leading: entry.isDirectory
                      ? Icon(
                          LucideIcons.folder,
                          size: 16,
                          color: theme.colorScheme.mutedForeground,
                        )
                      : null,
                  trailing: entry.sizeLabel == null
                      ? null
                      : Text(entry.sizeLabel!).small().muted(),
                  expandable: false,
                  onPressed: entry.isDirectory
                      ? () => controller.showFolder(entry.path)
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
    final selection = controller.explorerSelection;
    final groups = <String, List<OpenedImageFile>>{};
    for (final file in controller.sessionFiles) {
      final directory = FileOpenController.directoryOf(file.path);
      groups.putIfAbsent(directory, () => <OpenedImageFile>[]).add(file);
    }

    return groups.entries
        .map((entry) {
          final folderSizeLabel = _folderSizeLabel(entry.value);
          return TreeItem<_ExplorerEntry>(
            data: _ExplorerEntry.directory(
              label: FileOpenController.directoryLabelOf(entry.key),
              path: entry.key,
              sizeLabel: folderSizeLabel,
            ),
            expanded: true,
            selected:
                selection?.type == ExplorerSelectionType.folder &&
                selection?.path == entry.key,
            children: entry.value
                .map(
                  (file) => TreeItem<_ExplorerEntry>(
                    data: _ExplorerEntry.file(
                      label: FileOpenController.fileNameOf(file.path),
                      path: file.path,
                      sizeLabel: _fileSizeLabel(file),
                    ),
                    selected:
                        selection?.type == ExplorerSelectionType.file &&
                        selection?.path == file.path,
                  ),
                )
                .toList(growable: false),
          );
        })
        .toList(growable: false);
  }
}

class _ExplorerEntry {
  const _ExplorerEntry._({
    required this.label,
    required this.path,
    required this.sizeLabel,
    required this.isDirectory,
  });

  const _ExplorerEntry.directory({
    required String label,
    required String path,
    required String? sizeLabel,
  }) : this._(
         label: label,
         path: path,
         sizeLabel: sizeLabel,
         isDirectory: true,
       );

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
    final runState = ref.watch(optimizationRunControllerProvider);
    final fileController = ref.watch(fileOpenControllerProvider);

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
                          onChanged: runState.isRunning
                              ? null
                              : notifier.setAdvancedMode,
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
                          onChanged: runState.isRunning
                              ? null
                              : notifier.setPreferredCodec,
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
                                            title: codecLabel(codec),
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
                          onChanged: runState.isRunning
                              ? null
                              : notifier.setCompressionMethod,
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
                          onChanged: runState.isRunning
                              ? null
                              : notifier.setCompressionPriority,
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
                          onChanged: runState.isRunning
                              ? null
                              : (value) {
                                  notifier.setQuality(value.value.round());
                                },
                        ),
                        const SizedBox(height: 12),
                      ],
                      _SettingsLabel('Current codec'),
                      const SizedBox(height: 8),
                      Text(codecLabel(settings.effectiveCodec)).small().medium(),
                      if (runState.globalError case final error?)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(error).xSmall().muted(),
                        ),
                      const SizedBox(height: 16),
                      _SettingsLabel('Status'),
                      const SizedBox(height: 8),
                      ...fileController.sessionFiles.map(
                        (file) => _StatusRow(
                          fileName: FileOpenController.fileNameOf(file.path),
                          status: _statusForFile(file, runState),
                        ),
                      ),
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

class _DeveloperButton extends StatelessWidget {
  const _DeveloperButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: 16,
          height: 16,
          child: Icon(
            LucideIcons.wrench,
            size: 10,
            color: theme.colorScheme.mutedForeground.withValues(alpha: 0.55),
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
                              Text('Unlock diagnostics and internal controls.')
                                  .xSmall()
                                  .muted(),
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
                    child: Checkbox(
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

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.fileName, required this.status});

  final String fileName;
  final OptimizationItemState status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(fileName).small()),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary,
              borderRadius: theme.borderRadiusLg,
            ),
            child: Text(_statusLabel(status)).xSmall().muted(),
          ),
        ],
      ),
    );
  }
}

class _BottomSidebar extends ConsumerWidget {
  const _BottomSidebar({required this.controller});

  final FileOpenController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentFile = controller.currentFile;
    if (currentFile == null) {
      return const SizedBox.shrink();
    }

    final preview = ref.watch(currentPreviewProvider).maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final plan = ref.watch(currentOptimizationPlanProvider).maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final settings = ref.watch(appSettingsProvider).maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final runState = ref.watch(optimizationRunControllerProvider);
    final runController = ref.read(optimizationRunControllerProvider.notifier);
    final progressValue = runState.totalCount > 0
        ? (runState.completedCount / runState.totalCount).clamp(0.0, 1.0)
        : 0.0;
    final summary = _BottomSummaryViewModel.build(
      controller: controller,
      currentFile: currentFile,
      runState: runState,
      preview: preview,
      plan: plan,
      settings: settings,
    );

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
              'Details',
              style: TextStyle(
                color: theme.colorScheme.mutedForeground,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ).xSmall(),
          ),
          const Divider(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _BottomStatsSection(stats: summary.stats),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _BottomDetail(
                            label: '',
                            value: '',
                            child: _BottomInfoSection(
                              originalTitle: summary.originalSectionTitle,
                              originalRows: summary.originalRows,
                              outputTitle: summary.outputSectionTitle,
                              outputRows: summary.outputRows,
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _BottomDetail(
                            label: '',
                            value: '',
                            child: const _BottomQualitySection(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: theme.colorScheme.border,
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 188,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: 36,
                          child: runState.isCancelRequested
                              ? Button.destructive(
                                  alignment: Alignment.center,
                                  onPressed: null,
                                  child: const Text(
                                    'Canceling...',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 15),
                                  ),
                                )
                              : runState.isRunning
                              ? Button.destructive(
                                  alignment: Alignment.center,
                                  onPressed: runController.cancelCurrentRun,
                                  child: const Text(
                                    'Cancel',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 15),
                                  ),
                                )
                              : PrimaryButton(
                                  alignment: Alignment.center,
                                  onPressed: runController.optimizeAll,
                                  child: const Text(
                                    'Optimize',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ),
                        ),
                        if (runState.isRunning) ...[
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progressValue,
                            minHeight: 6,
                            borderRadius: theme.borderRadiusLg,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomDetail extends StatelessWidget {
  const _BottomDetail({
    required this.label,
    required this.value,
    this.child,
  });

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

class _BottomStatTile extends StatelessWidget {
  const _BottomStatTile({required this.stat});

  final _BottomStatData stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary,
        borderRadius: theme.borderRadiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stat.label).xSmall().medium().muted(),
          const Spacer(),
          Text(
            stat.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: stat.color,
            ),
          ),
        ],
      ),
    );
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
          child: _BottomInfoColumn(
            title: originalTitle,
            rows: originalRows,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: _BottomInfoColumn(
            title: outputTitle,
            rows: outputRows,
          ),
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
        color: theme.colorScheme.secondary,
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

class _BottomInfoRow extends StatelessWidget {
  const _BottomInfoRow({required this.row});

  final _BottomInfoRowData row;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(row.label).xSmall().medium().muted(),
        const SizedBox(height: 2),
        Text(
          row.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ).small().medium(),
      ],
    );
  }
}

class _BottomQualitySection extends StatelessWidget {
  const _BottomQualitySection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary,
        borderRadius: theme.borderRadiusLg,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BottomMetricRow(label: 'PSNR', value: 'N/A'),
          SizedBox(height: 8),
          _BottomMetricRow(label: 'SSIM', value: 'N/A'),
          SizedBox(height: 8),
          _BottomMetricRow(label: 'Butteraugli', value: 'N/A'),
        ],
      ),
    );
  }
}

class _BottomMetricRow extends StatelessWidget {
  const _BottomMetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label).xSmall().medium().muted()),
        Text(value).xSmall().medium().muted(),
      ],
    );
  }
}

class _BottomSummaryViewModel {
  const _BottomSummaryViewModel({
    required this.stats,
    required this.originalSectionTitle,
    required this.originalRows,
    required this.outputSectionTitle,
    required this.outputRows,
  });

  final List<_BottomStatData> stats;
  final String originalSectionTitle;
  final List<_BottomInfoRowData> originalRows;
  final String outputSectionTitle;
  final List<_BottomInfoRowData> outputRows;

  static _BottomSummaryViewModel build({
    required FileOpenController controller,
    required OpenedImageFile currentFile,
    required OptimizationRunState runState,
    required OptimizationPreview? preview,
    required OptimizationPlan? plan,
    required AppSettings? settings,
  }) {
    if (controller.isFolderSelected) {
      return _buildFolder(
        controller: controller,
        runState: runState,
        settings: settings,
      );
    }

    return _buildFile(
      file: currentFile,
      runState: runState,
      preview: preview,
      plan: plan,
    );
  }

  static _BottomSummaryViewModel _buildFile({
    required OpenedImageFile file,
    required OptimizationRunState runState,
    required OptimizationPreview? preview,
    required OptimizationPlan? plan,
  }) {
    final originalBytes = _originalFileSizeBytes(file);
    final newBytes = preview?.result.sizeBytes.toInt() ?? _effectiveFileSizeBytes(file);
    final savingsBytes = originalBytes != null && newBytes != null
        ? originalBytes - newBytes
        : null;
    final savingsPercent = originalBytes != null &&
            originalBytes > 0 &&
            savingsBytes != null
        ? (savingsBytes / originalBytes) * 100
        : null;
    final outputFormat =
        file.lastResult?.format ??
        (plan == null ? null : codecIdOf(plan.targetCodec));
    return _BottomSummaryViewModel(
      stats: [
        _BottomStatData(
          label: 'Original',
          value: _formatNullableBytes(originalBytes),
          color: const Color(0xFF6B7280),
        ),
        _BottomStatData(
          label: 'New',
          value: _formatNullableBytes(newBytes),
          color: const Color(0xFF2563EB),
        ),
        _BottomStatData(
          label: 'Savings',
          value: _formatNullablePercentValue(savingsPercent),
          color: const Color(0xFF16A34A),
        ),
        const _BottomStatData(
          label: 'Similarity',
          value: 'N/A',
          color: Color(0xFFF59E0B),
        ),
      ],
      originalSectionTitle: 'Original',
      originalRows: [
        _BottomInfoRowData(
          label: 'Format',
          value: formatLabel(file.metadata.format),
        ),
      ],
      outputSectionTitle: 'Optimized',
      outputRows: [
        _BottomInfoRowData(
          label: 'Format',
          value: outputFormat == null ? '—' : formatLabel(outputFormat),
        ),
      ],
    );
  }

  static _BottomSummaryViewModel _buildFolder({
    required FileOpenController controller,
    required OptimizationRunState runState,
    required AppSettings? settings,
  }) {
    final files = controller.selectedFolderFiles;
    final originalBytes = _aggregateFolderBytes(
      files,
      useOriginalSizes: true,
    );
    final newBytes = _aggregateFolderBytes(files, useOriginalSizes: false);
    final savingsBytes = originalBytes != null && newBytes != null
        ? originalBytes - newBytes
        : null;
    final savingsPercent = originalBytes != null &&
            originalBytes > 0 &&
            savingsBytes != null
        ? (savingsBytes / originalBytes) * 100
        : null;
    final completedCount = files
        .where((file) => _isTerminalStatus(_statusForFile(file, runState).status))
        .length;

    return _BottomSummaryViewModel(
      stats: [
        _BottomStatData(
          label: 'Original',
          value: _formatNullableBytes(originalBytes),
          color: const Color(0xFF6B7280),
        ),
        _BottomStatData(
          label: 'New',
          value: _formatNullableBytes(newBytes),
          color: const Color(0xFF2563EB),
        ),
        _BottomStatData(
          label: 'Savings',
          value: _formatNullablePercentValue(savingsPercent),
          color: const Color(0xFF16A34A),
        ),
        const _BottomStatData(
          label: 'Similarity',
          value: 'N/A',
          color: Color(0xFFF59E0B),
        ),
      ],
      originalSectionTitle: 'Original',
      originalRows: [
        _BottomInfoRowData(
          label: 'Folder',
          value: controller.selectedFolderName ??
              controller.selectedFolderPath ??
              'Unknown',
        ),
        _BottomInfoRowData(label: 'Images', value: '${files.length}'),
        const _BottomInfoRowData(label: 'Scope', value: 'Loaded'),
      ],
      outputSectionTitle: 'Optimized',
      outputRows: [
        _BottomInfoRowData(
          label: 'Target',
          value: settings == null ? '—' : codecLabel(settings.effectiveCodec),
        ),
        _BottomInfoRowData(
          label: 'Completed',
          value: '$completedCount / ${files.length}',
        ),
      ],
    );
  }
}

class _BottomStatData {
  const _BottomStatData({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}

class _BottomInfoRowData {
  const _BottomInfoRowData({required this.label, required this.value});

  final String label;
  final String value;
}

int? _effectiveFileSizeBytes(OpenedImageFile file) {
  return file.lastResult?.newSize.toInt() ?? file.metadata.fileSize?.toInt();
}

int? _originalFileSizeBytes(OpenedImageFile file) {
  return file.lastResult?.originalSize.toInt() ?? file.metadata.fileSize?.toInt();
}

int? _aggregateFolderBytes(
  List<OpenedImageFile> files, {
  required bool useOriginalSizes,
}) {
  var hasSize = false;
  var totalBytes = 0;

  for (final file in files) {
    final bytes = useOriginalSizes
        ? _originalFileSizeBytes(file)
        : _effectiveFileSizeBytes(file);
    if (bytes == null) {
      continue;
    }
    hasSize = true;
    totalBytes += bytes;
  }

  return hasSize ? totalBytes : null;
}

String _formatNullableBytes(int? bytes) {
  if (bytes == null) {
    return '—';
  }
  return _formatBytes(bytes);
}

String? _formatNullablePercent(double? value) {
  if (value == null) {
    return null;
  }
  return '${value.toStringAsFixed(1)}%';
}

String _formatNullablePercentValue(double? value) {
  return _formatNullablePercent(value) ?? '—';
}

bool _isTerminalStatus(OptimizationItemStatus status) {
  return switch (status) {
    OptimizationItemStatus.written ||
    OptimizationItemStatus.skipped ||
    OptimizationItemStatus.failed ||
    OptimizationItemStatus.canceled => true,
    OptimizationItemStatus.idle ||
    OptimizationItemStatus.queued ||
    OptimizationItemStatus.running => false,
  };
}

OptimizationItemState _statusForFile(
  OpenedImageFile file,
  OptimizationRunState runState,
) {
  final direct = runState.items[file.path];
  if (direct != null) {
    return direct;
  }

  if (file.lastError != null) {
    return OptimizationItemState(
      status: OptimizationItemStatus.failed,
      message: file.lastError,
    );
  }

  if (file.lastResult != null) {
    return OptimizationItemState(
      status: file.lastResult!.didWrite
          ? OptimizationItemStatus.written
          : OptimizationItemStatus.skipped,
      result: file.lastResult,
    );
  }

  return const OptimizationItemState(status: OptimizationItemStatus.idle);
}

String _statusLabel(OptimizationItemState state) {
  return switch (state.status) {
    OptimizationItemStatus.idle => 'Idle',
    OptimizationItemStatus.queued => 'Queued',
    OptimizationItemStatus.running => 'Working',
    OptimizationItemStatus.written => 'Saved',
    OptimizationItemStatus.skipped => 'Unchanged',
    OptimizationItemStatus.failed => 'Failed',
    OptimizationItemStatus.canceled => 'Canceled',
  };
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
    return Basic(title: Text(title).small().medium());
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

String? _fileSizeLabel(OpenedImageFile file) {
  final bytes = file.metadata.fileSize?.toInt();
  if (bytes == null) {
    return null;
  }
  return _formatBytes(bytes);
}

String? _folderSizeLabel(List<OpenedImageFile> files) {
  var hasSize = false;
  var totalBytes = 0;
  for (final file in files) {
    final bytes = file.metadata.fileSize?.toInt();
    if (bytes == null) {
      continue;
    }
    hasSize = true;
    totalBytes += bytes;
  }
  if (!hasSize) {
    return null;
  }
  return _formatBytes(totalBytes);
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
