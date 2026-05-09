part of 'package:oimg/main.dart';

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
    final theme = Theme.of(context);
    final controller = ref.watch(fileOpenControllerProvider);
    final runState = ref.watch(optimizationRunControllerProvider);
    final appSettings = ref.watch(appSettingsProvider).asData?.value;
    final showCaptionButtons = _shouldShowTitleBarCaptionButtons(appSettings);
    final title =
        controller.currentDisplayTitle ?? 'Open images from your desktop';
    final homeScreen = !controller.hasSession;
    final prominentHomeTitle =
        homeScreen && theme.brightness == ui.Brightness.light;

    return Scaffold(
      floatingHeader: homeScreen,
      headers: [
        AppBar(
          height: _titleBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          surfaceOpacity: homeScreen ? 0.10 : null,
          surfaceBlur: homeScreen ? 4 : null,
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
                        color: prominentHomeTitle
                            ? theme.colorScheme.foreground.withValues(
                                alpha: 0.60,
                              )
                            : theme.colorScheme.mutedForeground,
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DeveloperButton(
                      onPressed: () {
                        unawaited(_openDeveloperDialog());
                      },
                    ),
                    if (controller.hasSession) ...[
                      const SizedBox(width: 6),
                      _TitleBarHomeButton(
                        onPressed: runState.isRunning
                            ? null
                            : controller.clearSession,
                      ),
                    ],
                    const SizedBox(width: 6),
                    const _TitleBarSettingsButton(),
                    if (showCaptionButtons) ...[
                      const SizedBox(width: 6),
                      const _TitleBarCaptionControls(),
                    ],
                  ],
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
