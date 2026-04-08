import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oimg/src/file_open/file_open_channel.dart';
import 'package:oimg/src/file_open/file_open_controller.dart';
import 'package:oimg/src/file_open/file_open_providers.dart';
import 'package:oimg/src/file_open/opened_image_file.dart';
import 'package:oimg/src/optimization/optimization_plan.dart';
import 'package:oimg/src/optimization/optimization_providers.dart';
import 'package:oimg/src/rust/frb_generated.dart';
import 'package:oimg/src/rust/slimg_api.dart';
import 'package:oimg/src/rust/types.dart';
import 'package:oimg/src/settings/app_settings.dart';
import 'package:oimg/src/settings/app_settings_controller.dart';
import 'package:oimg/src/settings/developer_diagnostics.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

const _uiScale = 0.8;
const _uiRadius = 0.4;
const _titleBarHeight = 19.0;
const _defaultSidebarWidth = 280.0;
const _minSidebarWidth = 180.0;
const _maxSidebarWidth = 420.0;
const _defaultSettingsSidebarWidth = 320.0;
const _minSettingsSidebarWidth = 240.0;
const _maxSettingsSidebarWidth = 420.0;
const _defaultBottomSidebarHeight = 165.0;
const _minBottomSidebarHeight = 140.0;
const _maxBottomSidebarHeight = 320.0;
const List<({double value, Color color})> _qualityMetricColorStops = [
  (value: 0, color: Color(0xFF440000)),
  (value: 20, color: Color(0xFFAA0000)),
  (value: 40, color: Color(0xFFDE602E)),
  (value: 60, color: Color(0xFFDBDE25)),
  (value: 80, color: Color(0xFF34C759)),
  (value: 100, color: Color(0xFF0094D9)),
];

enum _SavingsDisplayMode { percent, ratio }

class _SavingsDisplayModeNotifier extends Notifier<_SavingsDisplayMode> {
  @override
  _SavingsDisplayMode build() => _SavingsDisplayMode.percent;

  void toggle() {
    state = state == _SavingsDisplayMode.percent
        ? _SavingsDisplayMode.ratio
        : _SavingsDisplayMode.percent;
  }
}

final _savingsDisplayModeProvider =
    NotifierProvider<_SavingsDisplayModeNotifier, _SavingsDisplayMode>(
      _SavingsDisplayModeNotifier.new,
    );

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
                    style: TextStyle(color: theme.colorScheme.mutedForeground),
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
    final enabled = settings.developerModeEnabled && settings.timingLogsEnabled;
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: DragToMoveArea(
                  child: Center(
                    child: Text(
                      'OIMG',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                        color: Theme.of(context).colorScheme.mutedForeground,
                      ),
                    ),
                  ),
                ),
              ),
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
  double _settingsSidebarWidth = _defaultSettingsSidebarWidth;
  double _bottomSidebarHeight = _defaultBottomSidebarHeight;

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(fileOpenControllerProvider);
    final currentFile = controller.currentFile;
    if (currentFile == null) {
      return const _EmptyState();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
            final settingsMaxWidth = _clampSettingsSidebarWidth(
              constraints.maxWidth * 0.34,
            );
            final settingsSidebarWidth = _settingsSidebarWidth.clamp(
              _minSettingsSidebarWidth,
              settingsMaxWidth,
            );
            final bottomSidebarMaxHeight = _clampBottomSidebarHeight(
              constraints.maxHeight * 0.4,
            );
            final bottomSidebarHeight = _bottomSidebarHeight.clamp(
              _minBottomSidebarHeight,
              bottomSidebarMaxHeight,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: sidebarWidth, child: sidebar),
                      _ResizeHandle(
                        axis: Axis.horizontal,
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
                      _ResizeHandle(
                        axis: Axis.horizontal,
                        onDragUpdate: (delta) {
                          setState(() {
                            _settingsSidebarWidth = _clampSettingsSidebarWidth(
                              _settingsSidebarWidth - delta,
                              maxWidth: settingsMaxWidth,
                            );
                          });
                        },
                      ),
                      SizedBox(
                        width: settingsSidebarWidth,
                        child: settingsSidebar,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _ResizeHandle(
                  axis: Axis.vertical,
                  onDragUpdate: (delta) {
                    setState(() {
                      _bottomSidebarHeight = _clampBottomSidebarHeight(
                        _bottomSidebarHeight - delta,
                        maxHeight: bottomSidebarMaxHeight,
                      );
                    });
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(height: bottomSidebarHeight, child: bottomSidebar),
              ],
            );
          }

          final bottomSidebarMaxHeight = _clampBottomSidebarHeight(
            constraints.maxHeight * 0.35,
          );
          final bottomSidebarHeight = _bottomSidebarHeight.clamp(
            _minBottomSidebarHeight,
            bottomSidebarMaxHeight,
          );
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
              const SizedBox(height: 8),
              _ResizeHandle(
                axis: Axis.vertical,
                onDragUpdate: (delta) {
                  setState(() {
                    _bottomSidebarHeight = _clampBottomSidebarHeight(
                      _bottomSidebarHeight - delta,
                      maxHeight: bottomSidebarMaxHeight,
                    );
                  });
                },
              ),
              const SizedBox(height: 8),
              SizedBox(height: bottomSidebarHeight, child: bottomSidebar),
            ],
          );
        },
      ),
    );
  }

  double _clampSidebarWidth(double width, {double? maxWidth}) {
    return width.clamp(_minSidebarWidth, maxWidth ?? _maxSidebarWidth);
  }

  double _clampSettingsSidebarWidth(double width, {double? maxWidth}) {
    return width.clamp(
      _minSettingsSidebarWidth,
      maxWidth ?? _maxSettingsSidebarWidth,
    );
  }

  double _clampBottomSidebarHeight(double height, {double? maxHeight}) {
    return height.clamp(
      _minBottomSidebarHeight,
      maxHeight ?? _maxBottomSidebarHeight,
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.axis, required this.onDragUpdate});

  final Axis axis;
  final ValueChanged<double> onDragUpdate;

  @override
  Widget build(BuildContext context) {
    final isHorizontal = axis == Axis.horizontal;
    return MouseRegion(
      cursor: isHorizontal
          ? SystemMouseCursors.resizeLeftRight
          : SystemMouseCursors.resizeUpDown,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: isHorizontal
            ? (details) => onDragUpdate(details.delta.dx)
            : null,
        onVerticalDragUpdate: isHorizontal
            ? null
            : (details) => onDragUpdate(details.delta.dy),
        child: isHorizontal
            ? const SizedBox(width: 8)
            : const SizedBox(height: 8),
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
    final appSettings = ref.watch(appSettingsProvider).asData?.value;
    final plan = ref.watch(currentOptimizationPlanProvider);
    final preview = ref.watch(currentPreviewProvider);
    final optimizedDisplay = ref.watch(currentOptimizedDisplayProvider);
    final displayMode = ref.watch(currentPreviewDisplayModeProvider);
    final difference = ref.watch(currentPreviewDifferenceProvider);
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
                        Text(
                          '${currentFile.metadata.width} x ${currentFile.metadata.height}',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: theme.colorScheme.mutedForeground,
                          ),
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
                          return difference.when(
                            data: (diff) {
                              if (diff == null) {
                                return const _PreviewUnavailable(
                                  message: 'Difference preview unavailable.',
                                );
                              }
                              return _PreviewCanvas(
                                fileName: fileName,
                                rawImage: diff,
                              );
                            },
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, _) => const _PreviewUnavailable(
                              message: 'Difference preview unavailable.',
                            ),
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
          // const Divider(),
          Expanded(
            child: Container(
              color: theme.colorScheme.background,
              padding: const EdgeInsets.all(14),
              child: _FolderCollage(
                files: folderFiles,
                onOpenFile: controller.showPath,
                onRevealFile: controller.showInFileManager,
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
    required this.fileName,
    this.path,
    this.encodedBytes,
    this.rawImage,
    this.unavailableMessage,
  });

  final String fileName;
  final String? path;
  final Uint8List? encodedBytes;
  final ui.Image? rawImage;
  final String? unavailableMessage;

  @override
  Widget build(BuildContext context) {
    final populated = [
      path != null,
      encodedBytes != null,
      rawImage != null,
    ].where((value) => value).length;
    assert(populated == 1);

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 6,
      child: Container(
        alignment: Alignment.center,
        child: path != null
            ? Image.file(
                File(path!),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return _ImageLoadError(fileName: fileName);
                },
              )
            : rawImage != null
            ? RawImage(image: rawImage, fit: BoxFit.contain)
            : Image.memory(
                encodedBytes!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return _PreviewUnavailable(
                    message: unavailableMessage ?? 'Unable to render preview.',
                  );
                },
              ),
      ),
    );
  }
}

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
    final difference = ref.watch(currentPreviewDifferenceProvider);
    final analyzeState = ref.watch(analyzeRunControllerProvider);
    final analyzeAvailability = ref.watch(analyzeAvailabilityProvider);
    final analyzeController = ref.read(analyzeRunControllerProvider.notifier);
    final settings = ref.watch(appSettingsProvider).asData?.value;
    final optimizedLoading = preview.isLoading && !hasOptimizedPreview;
    final differenceLoading =
        displayMode == PreviewDisplayMode.difference && difference.isLoading;
    final analyzeTooltip =
        !analyzeAvailability.isEnabled &&
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
                  child: const Text('Cancel Analyze'),
                )
              : OutlineButton(
                  alignment: Alignment.center,
                  onPressed: analyzeAvailability.isEnabled
                      ? analyzeController.startAnalyze
                      : null,
                  child: const Text('Analyze'),
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Text(
              'Files',
              style: TextStyle(
                color: theme.colorScheme.mutedForeground,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ).xSmall(),
          ),
          // const Divider(),
          Expanded(
            child: TreeView<_ExplorerEntry>(
              nodes: nodes,
              branchLine: BranchLine.none,
              expandIcon: false,
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
              builder: (context, node) {
                final entry = node.data;
                final item = TreeItemView(
                  key: ValueKey('explorer-item-${entry.path}'),
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
                final showInFileManagerLabel = _showInFileManagerLabel();
                if (showInFileManagerLabel == null) {
                  return item;
                }

                return ContextMenu(
                  items: [
                    MenuButton(
                      onPressed: (context) {
                        unawaited(controller.showInFileManager(entry.path));
                      },
                      child: Text(showInFileManagerLabel),
                    ),
                  ],
                  child: item,
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
    final fileController = ref.watch(fileOpenControllerProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final runState = ref.watch(optimizationRunControllerProvider);
    final analyzeState = ref.watch(analyzeRunControllerProvider);
    final controlsLocked = runState.isRunning || analyzeState.isRunning;
    final showAnalyzePanel =
        analyzeState.isRunning ||
        analyzeState.samples.isNotEmpty ||
        analyzeState.globalError != null;

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
                          onChanged: controlsLocked
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
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: settings.when(
                        data: (settings) {
                          final transparencyWarning = _transparencyWarningText(
                            settings: settings,
                            file: fileController.isFolderSelected
                                ? null
                                : fileController.currentFile,
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _SettingsModeSwitcher(
                                settings: settings,
                                controlsLocked: controlsLocked,
                                notifier: notifier,
                              ),
                              if (transparencyWarning case final warning?) ...[
                                const SizedBox(height: 12),
                                _SettingsWarningBlock(
                                  icon: LucideIcons.triangleAlert,
                                  message: warning,
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
                                    Text(
                                      _qualityValueLabel(settings),
                                    ).xSmall().medium().muted(),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Slider(
                                  value: SliderValue.single(
                                    settings.quality.toDouble(),
                                  ),
                                  min: 0,
                                  max: 100,
                                  divisions: 100,
                                  onChanged: controlsLocked
                                      ? null
                                      : (value) {
                                          notifier.setQuality(
                                            value.value.round(),
                                          );
                                        },
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (runState.globalError case final error?)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(error).xSmall().muted(),
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
                            child: const Text(
                              'Unable to load settings',
                            ).small().muted(),
                          );
                        },
                      ),
                    ),
                  ),
                  settings.when(
                    data: (settings) => Column(
                      children: [
                        const SizedBox(height: 12),
                        _StorageCollapsible(
                          settings: settings,
                          controlsLocked: controlsLocked,
                        ),
                      ],
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 12),
                  const _MetadataCollapsible(),
                  if (showAnalyzePanel) ...[
                    const SizedBox(height: 12),
                    Container(height: 1, color: theme.colorScheme.border),
                    const SizedBox(height: 12),
                    Expanded(child: _AnalyzePanel(state: analyzeState)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsModeSwitcher extends StatelessWidget {
  const _SettingsModeSwitcher({
    required this.settings,
    required this.controlsLocked,
    required this.notifier,
  });

  final AppSettings settings;
  final bool controlsLocked;
  final AppSettingsController notifier;

  @override
  Widget build(BuildContext context) {
    final activeKey = settings.advancedMode
        ? const ValueKey('advanced-settings-mode')
        : const ValueKey('basic-settings-mode');

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        reverseDuration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final isIncoming = child.key == activeKey;
          final enteringAdvanced = settings.advancedMode;
          final enterOffset = enteringAdvanced
              ? const Offset(0.04, 0)
              : const Offset(-0.04, 0);
          final exitOffset = enteringAdvanced
              ? const Offset(-0.04, 0)
              : const Offset(0.04, 0);
          final offsetAnimation = isIncoming
              ? Tween<Offset>(
                  begin: enterOffset,
                  end: Offset.zero,
                ).animate(animation)
              : Tween<Offset>(
                  begin: exitOffset,
                  end: Offset.zero,
                ).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: offsetAnimation, child: child),
          );
        },
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              ...previousChildren,
              // ignore: use_null_aware_elements
              if (currentChild != null) currentChild,
            ],
          );
        },
        child: settings.advancedMode
            ? _AdvancedSettingsModeSection(
                key: activeKey,
                settings: settings,
                controlsLocked: controlsLocked,
                notifier: notifier,
              )
            : _BasicSettingsModeSection(
                key: activeKey,
                settings: settings,
                controlsLocked: controlsLocked,
                notifier: notifier,
              ),
      ),
    );
  }
}

class _MetadataCollapsible extends ConsumerStatefulWidget {
  const _MetadataCollapsible();

  @override
  ConsumerState<_MetadataCollapsible> createState() =>
      _MetadataCollapsibleState();
}

class _MetadataCollapsibleState extends ConsumerState<_MetadataCollapsible> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider).asData?.value;
    final notifier = ref.read(appSettingsProvider.notifier);
    final runState = ref.watch(optimizationRunControllerProvider);
    final analyzeState = ref.watch(analyzeRunControllerProvider);
    final controlsLocked = runState.isRunning || analyzeState.isRunning;

    Widget option({
      required Key key,
      required String label,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Checkbox(
          key: key,
          state: value ? CheckboxState.checked : CheckboxState.unchecked,
          onChanged: controlsLocked
              ? null
              : (next) {
                  onChanged(next == CheckboxState.checked);
                },
          trailing: Expanded(
            child: Text(
              label,
              style: TextStyle(color: theme.colorScheme.mutedForeground),
            ).small(),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: const Text('Metadata').small().medium()),
                GhostButton(
                  key: const ValueKey('metadata-collapsible-toggle'),
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
                  child: settings == null
                      ? const SizedBox.shrink()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            option(
                              key: const ValueKey(
                                'metadata-preserve-original-date',
                              ),
                              label: 'Preserve original date',
                              value: settings.preserveOriginalDate,
                              onChanged: notifier.setPreserveOriginalDate,
                            ),
                            option(
                              key: const ValueKey(
                                'metadata-preserve-color-profile',
                              ),
                              label: 'Preserve color profile',
                              value: settings.preserveColorProfile,
                              onChanged: notifier.setPreserveColorProfile,
                            ),
                            option(
                              key: const ValueKey('metadata-preserve-exif'),
                              label: 'Preserve camera info (EXIF)',
                              value: settings.preserveExif,
                              onChanged: notifier.setPreserveExif,
                            ),
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

class _StorageCollapsible extends ConsumerStatefulWidget {
  const _StorageCollapsible({
    required this.settings,
    required this.controlsLocked,
  });

  final AppSettings settings;
  final bool controlsLocked;

  @override
  ConsumerState<_StorageCollapsible> createState() => _StorageCollapsibleState();
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
    final needsPicker =
        forcePicker ||
        currentPath == null ||
        currentPath.isEmpty ||
        widget.settings.storageDestinationMode !=
            StorageDestinationMode.differentLocation;
    if (!needsPicker) {
      return;
    }

    setState(() {
      _isPickingFolder = true;
    });
    final pickedPath = await ref
        .read(fileOpenControllerProvider)
        .pickStorageFolder();
    if (!mounted) {
      return;
    }
    setState(() {
      _isPickingFolder = false;
    });
    if (pickedPath == null || pickedPath.isEmpty) {
      return;
    }

    final notifier = ref.read(appSettingsProvider.notifier);
    await notifier.setDifferentLocationPath(pickedPath);
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                              onChanged: widget.controlsLocked
                                  ? null
                                  : (_) {},
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
                                      value:
                                          StorageDestinationMode
                                              .differentLocation,
                                      enabled:
                                          !widget.controlsLocked &&
                                          !_isPickingFolder,
                                      onTap: () =>
                                          _handleDifferentLocationSelection(
                                            forcePicker:
                                                widget.settings
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
                            ],
                          ),
                        ),
                      ],
                      if (widget.settings.storageDestinationMode ==
                          StorageDestinationMode.differentLocation) ...[
                        if (widget.settings.differentLocationPath case final path?)
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

class _AdvancedSettingsModeSection extends StatelessWidget {
  const _AdvancedSettingsModeSection({
    super.key,
    required this.settings,
    required this.controlsLocked,
    required this.notifier,
  });

  final AppSettings settings;
  final bool controlsLocked;
  final AppSettingsController notifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SettingsLabel('Codec'),
        const SizedBox(height: 8),
        RadioGroup<PreferredCodec>(
          value: settings.preferredCodec,
          onChanged: controlsLocked ? null : notifier.setPreferredCodec,
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
                          child: _ChoiceCard(title: codecLabel(codec)),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BasicSettingsModeSection extends StatelessWidget {
  const _BasicSettingsModeSection({
    super.key,
    required this.settings,
    required this.controlsLocked,
    required this.notifier,
  });

  final AppSettings settings;
  final bool controlsLocked;
  final AppSettingsController notifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SettingsLabel('Compression'),
        const SizedBox(height: 8),
        RadioGroup<CompressionMethod>(
          value: settings.compressionMethod,
          onChanged: controlsLocked ? null : notifier.setCompressionMethod,
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
          onChanged: controlsLocked ? null : notifier.setCompressionPriority,
          child: Row(
            children: [
              Expanded(
                child: RadioCard<CompressionPriority>(
                  value: CompressionPriority.compatibility,
                  child: const _ChoiceCard(title: 'Compatibility'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RadioCard<CompressionPriority>(
                  value: CompressionPriority.efficiency,
                  child: const _ChoiceCard(title: 'Efficiency'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnalyzePanel extends ConsumerWidget {
  const _AnalyzePanel({required this.state});

  final AnalyzeRunState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(analyzeRunControllerProvider.notifier);
    final displayMode = ref.watch(currentPreviewDisplayModeProvider);
    final currentFilePath = ref.watch(fileOpenControllerProvider).currentPath;
    final samples = [...state.samples]
      ..sort((a, b) => a.sizeBytes.compareTo(b.sizeBytes));
    final selectedSample = state.selectedSample;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.2),
        borderRadius: theme.borderRadiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Analyze',
                  style: TextStyle(
                    color: theme.colorScheme.mutedForeground,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ).xSmall(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (state.isRunning || samples.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  state.isRunning
                      ? 'Sampling ${state.completedCount} / ${state.totalCount}'
                      : '${samples.length} samples',
                ).xSmall().muted(),
                const Spacer(),
                if (state.currentQuality case final quality?)
                  Text('Q$quality').xSmall().muted(),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: samples.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _AnalyzeChart(
                      samples: samples,
                      selectedArtifactId: state.selectedArtifactId,
                      onSelectSample: (sample) {
                        controller.selectSample(sample);
                        if (currentFilePath != null) {
                          ref
                              .read(previewDisplaySelectionProvider.notifier)
                              .select(
                                filePath: currentFilePath,
                                mode: PreviewDisplayMode.optimized,
                              );
                        }
                        if (displayMode == PreviewDisplayMode.difference) {
                          ref
                              .read(previewDifferenceRequestProvider.notifier)
                              .requestForArtifact(sample.artifactId);
                        }
                      },
                    ),
            ),
            const SizedBox(height: 8),
            if (selectedSample != null)
              _AnalyzeSelectionSummary(sample: selectedSample),
          ],
          if (state.globalError case final error?) ...[
            const SizedBox(height: 8),
            Text(error).xSmall().muted(),
          ],
        ],
      ),
    );
  }
}

class _AnalyzeChart extends StatelessWidget {
  const _AnalyzeChart({
    required this.samples,
    required this.selectedArtifactId,
    required this.onSelectSample,
  });

  final List<AnalyzeSampleResult> samples;
  final String? selectedArtifactId;
  final ValueChanged<AnalyzeSampleResult> onSelectSample;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pixelMatchPoints = _metricPoints(
      samples,
      (sample) => sample.pixelMatch,
    );
    final ssimulacra2Points = _metricPoints(
      samples,
      (sample) => sample.ssimulacra2,
    );
    final maxX = samples.fold<double>(
      0,
      (current, sample) => math.max(current, sample.sizeBytes.toDouble()),
    );

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        minX: 0,
        maxX: maxX <= 0 ? 1 : maxX * 1.05,
        gridData: FlGridData(
          drawVerticalLine: true,
          horizontalInterval: 20,
          verticalInterval: maxX <= 0 ? 1 : maxX / 4,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: theme.colorScheme.border, strokeWidth: 1),
          getDrawingVerticalLine: (value) => FlLine(
            color: theme.colorScheme.border.withValues(alpha: 0.6),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 20,
              getTitlesWidget: (value, meta) =>
                  Text(value.toInt().toString()).xSmall().muted(),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: maxX <= 0 ? 1 : maxX / 4,
              getTitlesWidget: (value, meta) =>
                  Text(_formatBytes(value.round())).xSmall().muted(),
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: theme.colorScheme.border),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchCallback: (event, response) {
            final touchedSpots = response?.lineBarSpots;
            if (touchedSpots == null ||
                touchedSpots.isEmpty ||
                !event.isInterestedForInteractions) {
              return;
            }
            final touched = touchedSpots.first;
            final point = switch (touched.barIndex) {
              0 => pixelMatchPoints[touched.spotIndex],
              _ => ssimulacra2Points[touched.spotIndex],
            };
            onSelectSample(point.sample);
          },
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (spots) {
              return spots
                  .map((spot) {
                    final point = switch (spot.barIndex) {
                      0 => pixelMatchPoints[spot.spotIndex],
                      _ => ssimulacra2Points[spot.spotIndex],
                    };
                    final sample = point.sample;
                    return LineTooltipItem(
                      'Q${sample.quality}\n${_formatBytes(sample.sizeBytes.toInt())}\nPixel ${_formatNullableMetricPercent(sample.pixelMatch)}\nSSIM ${_formatNullableMetric(sample.ssimulacra2, digits: 1)}',
                      TextStyle(
                        color: theme.colorScheme.foreground,
                        fontSize: 10,
                      ),
                    );
                  })
                  .toList(growable: false);
            },
          ),
        ),
        lineBarsData: [
          _buildAnalyzeLine(
            points: pixelMatchPoints,
            color: const Color(0xFF2563EB),
            selectedArtifactId: selectedArtifactId,
          ),
          _buildAnalyzeLine(
            points: ssimulacra2Points,
            color: const Color(0xFF16A34A),
            selectedArtifactId: selectedArtifactId,
          ),
        ],
      ),
    );
  }
}

class _AnalyzeMetricPoint {
  const _AnalyzeMetricPoint({required this.sample, required this.spot});

  final AnalyzeSampleResult sample;
  final FlSpot spot;
}

List<_AnalyzeMetricPoint> _metricPoints(
  List<AnalyzeSampleResult> samples,
  double? Function(AnalyzeSampleResult sample) metric,
) {
  return samples
      .where((sample) => metric(sample) != null)
      .map(
        (sample) => _AnalyzeMetricPoint(
          sample: sample,
          spot: FlSpot(sample.sizeBytes.toDouble(), metric(sample)!),
        ),
      )
      .toList(growable: false);
}

LineChartBarData _buildAnalyzeLine({
  required List<_AnalyzeMetricPoint> points,
  required Color color,
  required String? selectedArtifactId,
}) {
  return LineChartBarData(
    spots: points.map((point) => point.spot).toList(growable: false),
    isCurved: false,
    color: color,
    barWidth: 2,
    dotData: FlDotData(
      show: true,
      getDotPainter: (spot, percent, barData, index) {
        final selected =
            selectedArtifactId != null &&
            points[index].sample.artifactId == selectedArtifactId;
        return FlDotCirclePainter(
          radius: selected ? 4 : 2.5,
          color: color,
          strokeWidth: selected ? 2 : 0,
          strokeColor: Colors.white,
        );
      },
    ),
  );
}

class _AnalyzeSelectionSummary extends StatelessWidget {
  const _AnalyzeSelectionSummary({required this.sample});

  final AnalyzeSampleResult sample;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Q${sample.quality}  ${_formatBytes(sample.sizeBytes.toInt())}',
          ).xSmall().medium(),
        ),
        Text(
          'Pixel ${_formatNullableMetricPercent(sample.pixelMatch)}  SSIM ${_formatNullableMetric(sample.ssimulacra2, digits: 1)}',
        ).xSmall().muted(),
      ],
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

    final previewState = ref.watch(currentPreviewProvider);
    final preview = previewState.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final plan = ref
        .watch(currentOptimizationPlanProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    final settings = ref
        .watch(appSettingsProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    final runState = ref.watch(optimizationRunControllerProvider);
    final analyzeState = ref.watch(analyzeRunControllerProvider);
    final runController = ref.read(optimizationRunControllerProvider.notifier);
    final selectedAnalyzeSample = ref.watch(selectedAnalyzeSampleProvider);
    final progressValue = runState.totalCount > 0
        ? (runState.completedCount / runState.totalCount).clamp(0.0, 1.0)
        : 0.0;
    final summary = _BottomSummaryViewModel.build(
      controller: controller,
      currentFile: currentFile,
      runState: runState,
      preview: preview,
      analyzeSample: selectedAnalyzeSample,
      isPreviewPending: previewState.isLoading,
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
                            child: _BottomQualitySection(
                              isFolderSelected: controller.isFolderSelected,
                            ),
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
                                  onPressed:
                                      analyzeState.isRunning ||
                                          analyzeState.isCancelRequested
                                      ? null
                                      : runController.optimizeAll,
                                  child: const Text(
                                    'Optimize',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 15),
                                  ),
                                ),
                        ),
                        if (runState.isRunning || analyzeState.isRunning) ...[
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: analyzeState.isRunning
                                ? (analyzeState.totalCount > 0
                                      ? (analyzeState.completedCount /
                                                analyzeState.totalCount)
                                            .clamp(0.0, 1.0)
                                      : 0.0)
                                : progressValue,
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
    final savingsDisplayMode = ref.watch(_savingsDisplayModeProvider);
    final isToggleable = stat.toggleable && !stat.loading;
    final displayedValue =
        stat.toggleable && savingsDisplayMode == _SavingsDisplayMode.ratio
        ? (stat.alternateValue ?? stat.value)
        : stat.value;

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
                color: stat.color,
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
            tooltip: (context) =>
                TooltipContainer(child: Text(stat.tooltip!)),
            child: tile,
          );

    if (!isToggleable) {
      return decoratedTile;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ref.read(_savingsDisplayModeProvider.notifier).toggle();
        },
        child: decoratedTile,
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

class _BottomInfoRow extends StatelessWidget {
  const _BottomInfoRow({required this.row});

  final _BottomInfoRowData row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${row.label} ').xSmall().medium().muted(),
        Expanded(
          child: row.loading
              ? const Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Text(
                  row.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ).xSmall().medium(),
        ),
      ],
    );
  }
}

class _BottomQualitySection extends ConsumerWidget {
  const _BottomQualitySection({required this.isFolderSelected});

  final bool isFolderSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider).asData?.value;
    final previewState = ref.watch(currentPreviewProvider);
    final previewPendingBeforeMetrics =
        previewState.isLoading && previewState.asData?.value == null;
    final colorCodingEnabled = settings?.qualityMetricColorsEnabled ?? false;
    final rows = isFolderSelected
        ? const <_BottomMetricRowState>[
            _BottomMetricRowState.text(label: 'Pixel Match', value: 'N/A'),
            _BottomMetricRowState.text(label: 'MS-SSIM', value: 'N/A'),
            _BottomMetricRowState.text(label: 'SSIMULACRA 2', value: 'N/A'),
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
              formatter: _formatNullableMetric,
              scoreMapper: (value) => value == null
                  ? null
                  : (value * 100).clamp(0, 100).toDouble(),
              previewPendingBeforeMetrics: previewPendingBeforeMetrics,
            ),
            _metricRowState(
              label: 'SSIMULACRA 2',
              metric: ref.watch(currentPreviewSsimulacra2Provider),
              formatter: (value) => _formatNullableMetric(value, digits: 1),
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
                child: GhostButton(
                  key: const ValueKey('quality-metric-colors-button'),
                  density: ButtonDensity.icon,
                  onPressed: settings == null
                      ? null
                      : () {
                          showDropdown(
                            context: context,
                            builder: (context) {
                              return DropdownMenu(
                                children: [
                                  MenuButton(
                                    key: const ValueKey(
                                      'quality-metric-colors-toggle',
                                    ),
                                    leading: Icon(
                                      colorCodingEnabled
                                          ? Icons.check
                                          : Icons.palette_outlined,
                                      size: 14,
                                    ),
                                    onPressed: (context) {
                                      unawaited(
                                        ref
                                            .read(appSettingsProvider.notifier)
                                            .setQualityMetricColorsEnabled(
                                              !colorCodingEnabled,
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
                  child: Icon(
                    Icons.settings,
                    size: 11,
                    color: theme.colorScheme.mutedForeground.withValues(
                      alpha: 0.55,
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
            ),
            if (index + 1 < rows.length) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
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

class _BottomMetricRow extends StatelessWidget {
  const _BottomMetricRow({
    required this.row,
    required this.colorCodingEnabled,
  });

  final _BottomMetricRowState row;
  final bool colorCodingEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelWidget = Text(row.label).xSmall().medium().muted();
    final help = _metricHelpFor(row.label);
    final valueColor =
        colorCodingEnabled && row.qualityScore != null
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
  final clampedScore = score.clamp(0, 100).toDouble();

  for (var index = 1; index < _qualityMetricColorStops.length; index++) {
    final lower = _qualityMetricColorStops[index - 1];
    final upper = _qualityMetricColorStops[index];
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

  return _qualityMetricColorStops.last.color;
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
    required AnalyzeSampleResult? analyzeSample,
    required bool isPreviewPending,
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
      analyzeSample: analyzeSample,
      isPreviewPending: isPreviewPending,
      plan: plan,
    );
  }

  static _BottomSummaryViewModel _buildFile({
    required OpenedImageFile file,
    required OptimizationRunState runState,
    required OptimizationPreview? preview,
    required AnalyzeSampleResult? analyzeSample,
    required bool isPreviewPending,
    required OptimizationPlan? plan,
  }) {
    final originalBytes = _originalFileSizeBytes(file);
    final hasSavedResult = file.lastResult != null;
    final isOptimizedPreviewPending =
        analyzeSample == null &&
        preview == null &&
        isPreviewPending &&
        !hasSavedResult;
    final newBytes =
        analyzeSample?.sizeBytes.toInt() ??
        preview?.result.sizeBytes.toInt() ??
        (isOptimizedPreviewPending ? null : _effectiveFileSizeBytes(file));
    final originalBpp = _bitsPerPixel(
      bytes: originalBytes,
      width: file.metadata.width,
      height: file.metadata.height,
    );
    final optimizedBpp = _bitsPerPixel(
      bytes: newBytes,
      width:
          analyzeSample?.width ??
          preview?.result.width ??
          file.lastResult?.width ??
          file.metadata.width,
      height:
          analyzeSample?.height ??
          preview?.result.height ??
          file.lastResult?.height ??
          file.metadata.height,
    );
    final savingsBytes = originalBytes != null && newBytes != null
        ? originalBytes - newBytes
        : null;
    final savingsPercent =
        originalBytes != null && originalBytes > 0 && savingsBytes != null
        ? (savingsBytes / originalBytes) * 100
        : null;
    final outputFormat =
        analyzeSample?.format ??
        file.lastResult?.format ??
        (plan == null ? null : codecIdOf(plan.targetCodec));
    final optimizedTimingTooltip = analyzeSample == null && preview != null
        ? _formatMetricTimingTooltip(preview.elapsedMilliseconds)
        : null;
    return _BottomSummaryViewModel(
      stats: [
        _BottomStatData(
          label: 'Original',
          value: _formatNullableBytes(originalBytes),
          color: const Color(0xFF6B7280),
        ),
        _BottomStatData(
          label: 'Optimized',
          value: _formatNullableBytes(newBytes),
          color: const Color(0xFF2563EB),
          loading: isOptimizedPreviewPending,
          tooltip: optimizedTimingTooltip,
        ),
        _BottomStatData(
          label: 'Savings',
          value: _formatNullablePercentValue(savingsPercent),
          alternateValue: _formatSavingsRatio(originalBytes, newBytes),
          color: const Color(0xFF16A34A),
          toggleable: true,
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
        _BottomInfoRowData(
          label: 'Bits Per Pixel',
          value: _formatNullableBpp(originalBpp),
        ),
      ],
      outputSectionTitle: 'Optimized',
      outputRows: [
        _BottomInfoRowData(
          label: 'Format',
          value: outputFormat == null ? '—' : formatLabel(outputFormat),
        ),
        _BottomInfoRowData(
          label: 'Bits Per Pixel',
          value: _formatNullableBpp(optimizedBpp),
          loading: isOptimizedPreviewPending,
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
    final originalBytes = _aggregateFolderBytes(files, useOriginalSizes: true);
    final newBytes = _aggregateFolderBytes(files, useOriginalSizes: false);
    final originalBpp = _aggregateFolderBpp(files, useOriginalSizes: true);
    final optimizedBpp = _aggregateFolderBpp(files, useOriginalSizes: false);
    final savingsBytes = originalBytes != null && newBytes != null
        ? originalBytes - newBytes
        : null;
    final savingsPercent =
        originalBytes != null && originalBytes > 0 && savingsBytes != null
        ? (savingsBytes / originalBytes) * 100
        : null;
    final completedCount = files
        .where(
          (file) => _isTerminalStatus(_statusForFile(file, runState).status),
        )
        .length;

    return _BottomSummaryViewModel(
      stats: [
        _BottomStatData(
          label: 'Original',
          value: _formatNullableBytes(originalBytes),
          color: const Color(0xFF6B7280),
        ),
        _BottomStatData(
          label: 'Optimized',
          value: _formatNullableBytes(newBytes),
          color: const Color(0xFF2563EB),
        ),
        _BottomStatData(
          label: 'Savings',
          value: _formatNullablePercentValue(savingsPercent),
          alternateValue: _formatSavingsRatio(originalBytes, newBytes),
          color: const Color(0xFF16A34A),
          toggleable: true,
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
          value:
              controller.selectedFolderName ??
              controller.selectedFolderPath ??
              'Unknown',
        ),
        _BottomInfoRowData(label: 'Images', value: '${files.length}'),
        const _BottomInfoRowData(label: 'Scope', value: 'Loaded'),
        _BottomInfoRowData(
          label: 'Bits Per Pixel',
          value: _formatNullableBpp(originalBpp),
        ),
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
        _BottomInfoRowData(
          label: 'Bits Per Pixel',
          value: _formatNullableBpp(optimizedBpp),
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
    this.alternateValue,
    this.loading = false,
    this.toggleable = false,
    this.tooltip,
  });

  final String label;
  final String value;
  final Color color;
  final String? alternateValue;
  final bool loading;
  final bool toggleable;
  final String? tooltip;
}

class _BottomInfoRowData {
  const _BottomInfoRowData({
    required this.label,
    required this.value,
    this.loading = false,
  });

  final String label;
  final String value;
  final bool loading;
}

int? _effectiveFileSizeBytes(OpenedImageFile file) {
  return file.lastResult?.newSize.toInt() ?? file.metadata.fileSize?.toInt();
}

int? _originalFileSizeBytes(OpenedImageFile file) {
  return file.lastResult?.originalSize.toInt() ??
      file.metadata.fileSize?.toInt();
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

double? _aggregateFolderBpp(
  List<OpenedImageFile> files, {
  required bool useOriginalSizes,
}) {
  var totalBytes = 0;
  var totalPixels = 0;

  for (final file in files) {
    final bytes = useOriginalSizes
        ? _originalFileSizeBytes(file)
        : _effectiveFileSizeBytes(file);
    final width = useOriginalSizes
        ? file.metadata.width
        : (file.lastResult?.width ?? file.metadata.width);
    final height = useOriginalSizes
        ? file.metadata.height
        : (file.lastResult?.height ?? file.metadata.height);
    if (bytes == null || width <= 0 || height <= 0) {
      continue;
    }

    totalBytes += bytes;
    totalPixels += width * height;
  }

  if (totalBytes <= 0 || totalPixels <= 0) {
    return null;
  }

  return (totalBytes * 8) / totalPixels;
}

double? _bitsPerPixel({
  required int? bytes,
  required int width,
  required int height,
}) {
  if (bytes == null || bytes <= 0 || width <= 0 || height <= 0) {
    return null;
  }

  return (bytes * 8) / (width * height);
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

String _formatNullableBpp(double? value) {
  if (value == null) {
    return '—';
  }

  return value >= 10 ? value.toStringAsFixed(1) : value.toStringAsFixed(2);
}

String _formatNullableMetric(double? value, {int digits = 3}) {
  if (value == null) {
    return 'N/A';
  }

  return value.toStringAsFixed(digits);
}

String _formatNullableMetricPercent(double? value) {
  return _formatNullablePercent(value) ?? 'N/A';
}

String _formatSavingsRatio(int? originalBytes, int? newBytes) {
  if (originalBytes == null ||
      newBytes == null ||
      originalBytes <= 0 ||
      newBytes <= 0) {
    return '—';
  }

  final ratio = originalBytes / newBytes;
  return '${ratio.toStringAsFixed(1)}x';
}

String _formatMetricTimingTooltip(int elapsedMilliseconds) {
  if (elapsedMilliseconds >= 1000) {
    final seconds = elapsedMilliseconds / 1000;
    return '${seconds.toStringAsFixed(1)} s';
  }

  return '$elapsedMilliseconds ms';
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

class _StorageDestinationCard extends StatelessWidget {
  const _StorageDestinationCard({
    required this.value,
    required this.enabled,
    required this.onTap,
    required this.child,
  });

  final StorageDestinationMode value;
  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: IgnorePointer(
        child: RadioCard<StorageDestinationMode>(
          value: value,
          enabled: enabled,
          child: child,
        ),
      ),
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

String? _showInFileManagerLabel() {
  if (Platform.isMacOS) {
    return 'Show in Finder';
  }
  if (Platform.isWindows) {
    return 'Show in File Explorer';
  }
  if (Platform.isLinux) {
    return 'Show in File Manager';
  }
  return null;
}

String _qualityValueLabel(AppSettings settings) {
  if (settings.quality == 100 && settings.qualitySupportsLosslessAtMax) {
    return 'Lossless';
  }

  return '${settings.quality}';
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  Future<void> _browseFiles(BuildContext context, WidgetRef ref) async {
    await ref.read(fileOpenControllerProvider).pickFilesAndOpen();
  }

  Future<void> _browseFolder(BuildContext context, WidgetRef ref) async {
    await ref.read(fileOpenControllerProvider).pickFolderAndOpen();
  }

  void _showBrowseMenu(BuildContext context, WidgetRef ref) {
    showDropdown(
      context: context,
      builder: (context) {
        return DropdownMenu(
          children: [
            MenuButton(
              key: const ValueKey('empty-state-open-files'),
              leading: const Icon(LucideIcons.images, size: 16),
              onPressed: (context) {
                unawaited(_browseFiles(context, ref));
              },
              child: const Text('Open Files…'),
            ),
            MenuButton(
              key: const ValueKey('empty-state-open-folder'),
              leading: const Icon(LucideIcons.folderOpen, size: 16),
              onPressed: (context) {
                unawaited(_browseFolder(context, ref));
              },
              child: const Text('Open Folder…'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 920;

              final hero = Container(
                decoration: BoxDecoration(
                  borderRadius: theme.borderRadiusXxl,
                  border: Border.all(
                    color: theme.colorScheme.border.withValues(alpha: 0.7),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.background,
                      theme.colorScheme.primary.withValues(alpha: 0.06),
                      theme.colorScheme.secondary.withValues(alpha: 0.42),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      blurRadius: 42,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -56,
                      right: -42,
                      child: Container(
                        width: 210,
                        height: 210,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -80,
                      left: -28,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.secondaryForeground
                              .withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Optimize your images easily',
                            style: TextStyle(
                              fontSize: 31,
                              height: 1.08,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.9,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'OIMG helps you choose the optimal image format and settings.',
                            style: TextStyle(
                              color: theme.colorScheme.mutedForeground,
                              fontSize: 13.6,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 26),
                          Row(
                            children: [
                              PrimaryButton(
                                key: const ValueKey(
                                  'empty-state-browse-button',
                                ),
                                onPressed: () => _showBrowseMenu(context, ref),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(LucideIcons.folderSearch, size: 16),
                                    SizedBox(width: 8),
                                    Text('Browse…'),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'or drop files and folders anywhere',
                                style: TextStyle(
                                  color: theme.colorScheme.mutedForeground,
                                ),
                              ).small(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              final supportCards = const [
                _EmptyStateFeatureCard(
                  icon: LucideIcons.sparkles,
                  title: 'Preview',
                  description:
                      'Inspect the optimized images before you hit save.',
                ),
                _EmptyStateFeatureCard(
                  icon: LucideIcons.badgePercent,
                  title: 'Compare',
                  description:
                      'See how different image formats compare in savings, quality, and compatibility.',
                ),
                _EmptyStateFeatureCard(
                  icon: LucideIcons.chartSpline,
                  title: 'Analyze',
                  description:
                      'Explore the balance between size and quality using state-of-the-art image quality analysis methods.',
                ),
              ];

              final support = wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: supportCards[0]),
                        const SizedBox(width: 14),
                        Expanded(child: supportCards[1]),
                        const SizedBox(width: 14),
                        Expanded(child: supportCards[2]),
                      ],
                    )
                  : Column(
                      children: [
                        supportCards[0],
                        const SizedBox(height: 14),
                        supportCards[1],
                        const SizedBox(height: 14),
                        supportCards[2],
                      ],
                    );

              return Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: theme.borderRadiusXxl,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.colorScheme.background,
                            theme.colorScheme.secondary.withValues(alpha: 0.32),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 28,
                    top: 24,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.05,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 54,
                    bottom: 20,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.secondaryForeground.withValues(
                          alpha: 0.04,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.8,
                          ),
                          child: hero,
                        ),
                        const SizedBox(height: 18),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.85,
                          ),
                          child: support,
                        ),
                        const SizedBox(height: 44),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 28,
                    bottom: 24,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlineButton(
                          key: const ValueKey('empty-state-github-button'),
                          onPressed: () async {
                            await launchUrl(
                              Uri.parse('https://github.com/yunho-c/oimg'),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(LucideIcons.github, size: 15),
                              SizedBox(width: 8),
                              Text('GitHub'),
                            ],
                          ),
                        ),
                        OutlineButton(
                          key: const ValueKey('empty-state-feedback-button'),
                          onPressed: () {},
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(LucideIcons.messageSquare, size: 15),
                              SizedBox(width: 8),
                              Text('Feedback'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

String? _transparencyWarningText({
  required AppSettings settings,
  required OpenedImageFile? file,
}) {
  if (file == null || !file.metadata.hasTransparency) {
    return null;
  }

  final codec = settings.effectiveCodec;
  if (codec.supportsTransparency) {
    return null;
  }

  return '${codecLabel(codec)} does not support transparency. Transparent areas will be flattened.';
}

class _SettingsWarningBlock extends StatelessWidget {
  const _SettingsWarningBlock({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const warningTint = Color(0xFFC75A5A);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          warningTint.withValues(alpha: 0.08),
          theme.colorScheme.background.withValues(alpha: 0.94),
        ),
        borderRadius: theme.borderRadiusLg,
        border: Border.all(
          color: Color.alphaBlend(
            warningTint.withValues(alpha: 0.18),
            theme.colorScheme.border.withValues(alpha: 0.92),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: warningTint),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: theme.colorScheme.mutedForeground,
                height: 1.4,
              ),
            ).small(),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateFeatureCard extends StatelessWidget {
  const _EmptyStateFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      borderRadius: theme.borderRadiusXl,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: theme.borderRadiusLg,
              ),
              child: Icon(icon, size: 18, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title).medium(),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      color: theme.colorScheme.mutedForeground,
                      height: 1.45,
                    ),
                  ).small(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
