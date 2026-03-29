import 'dart:async';
import 'dart:io';

import 'package:oimg/src/file_open/file_open_channel.dart';
import 'package:oimg/src/file_open/file_open_controller.dart';
import 'package:oimg/src/rust/frb_generated.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureWindow();
  await RustLib.init();

  final controller = FileOpenController(
    channel: MethodChannelFileOpenChannel(),
    initialPaths: args,
  );
  await controller.initialize();

  runApp(MyApp(controller: controller));
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
    return ShadcnApp(
      title: 'OIMG',
      debugShowCheckedModeBanner: false,
      theme: const ThemeData(
        colorScheme: ColorSchemes.lightSlate,
        radius: 0.9,
        surfaceOpacity: 0.92,
        surfaceBlur: 8,
      ),
      darkTheme: const ThemeData.dark(
        colorScheme: ColorSchemes.darkSlate,
        radius: 0.9,
        surfaceOpacity: 0.88,
        surfaceBlur: 12,
      ),
      themeMode: ThemeMode.system,
      home: OimgHomePage(controller: controller),
    );
  }
}

class OimgHomePage extends StatefulWidget {
  const OimgHomePage({super.key, required this.controller});

  final FileOpenController controller;

  @override
  State<OimgHomePage> createState() => _OimgHomePageState();
}

class _OimgHomePageState extends State<OimgHomePage> {
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
              title: const DragToMoveArea(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('OIMG'),
                ),
              ),
              trailing: [
                if (widget.controller.currentPositionLabel case final position?)
                  Card(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Text(position),
                  ),
              ],
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

class _ImageSessionView extends StatelessWidget {
  const _ImageSessionView({required this.controller, required this.title});

  final FileOpenController controller;
  final String title;

  @override
  Widget build(BuildContext context) {
    final currentPath = controller.currentPath;
    final currentFileName = controller.currentFileName;
    if (currentPath == null || currentFileName == null) {
      return const _EmptyState();
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wideLayout = constraints.maxWidth >= 980;
          final sidebar = _SessionSidebar(controller: controller);
          final stage = _ImageStage(
            title: title,
            currentPath: currentPath,
            currentFileName: currentFileName,
          );

          if (wideLayout) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 5, child: stage),
                const SizedBox(width: 20),
                SizedBox(width: 320, child: sidebar),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: stage),
              const SizedBox(height: 20),
              sidebar,
            ],
          );
        },
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
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  currentPath,
                  style: TextStyle(color: theme.colorScheme.mutedForeground),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: Container(
              color: theme.colorScheme.background,
              padding: const EdgeInsets.all(20),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 6,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.border),
                    borderRadius: theme.borderRadiusLg,
                    color: theme.colorScheme.card,
                  ),
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

class _SessionSidebar extends StatelessWidget {
  const _SessionSidebar({required this.controller});

  final FileOpenController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentPath = controller.currentPath ?? '';
    final fileType = currentPath.contains('.')
        ? currentPath.split('.').last.toUpperCase()
        : 'IMAGE';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Session',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _MetaRow(
                label: 'Current file',
                value: controller.currentFileName ?? '',
              ),
              const SizedBox(height: 10),
              _MetaRow(label: 'Format', value: fileType),
              const SizedBox(height: 10),
              _MetaRow(
                label: 'Session size',
                value:
                    '${controller.sessionLength} image${controller.sessionLength == 1 ? '' : 's'}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Navigation',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                onPressed: controller.canGoNext ? controller.showNext : null,
                leading: const Icon(LucideIcons.arrowRight),
                child: const Text('Next'),
              ),
              const SizedBox(height: 10),
              GhostButton(
                onPressed: controller.canGoPrevious
                    ? controller.showPrevious
                    : null,
                leading: const Icon(LucideIcons.arrowLeft),
                alignment: Alignment.centerLeft,
                child: const Text('Previous'),
              ),
              if (controller.currentPositionLabel case final position?) ...[
                const SizedBox(height: 12),
                Text(
                  position,
                  style: TextStyle(color: theme.colorScheme.mutedForeground),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: theme.colorScheme.mutedForeground)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
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
                          fontSize: 28,
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
