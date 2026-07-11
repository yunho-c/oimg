part of 'package:oimg/main.dart';

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

bool _shouldShowTitleBarCaptionButtons(AppSettings? settings) {
  if (Platform.isWindows || Platform.isLinux) {
    return true;
  }

  return !isStoreBuild &&
      Platform.isMacOS &&
      settings?.developerModeEnabled == true &&
      settings?.macOsCaptionButtonsEnabled == true;
}
