import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oimg/src/build/distribution.dart';
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
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:window_manager/window_manager.dart';

part 'src/app/window.dart';
part 'src/app/app.dart';
part 'src/session/session_page.dart';
part 'src/session/drop_surface.dart';
part 'src/session/session_layout.dart';
part 'src/preview/image_stage.dart';
part 'src/preview/folder_stage.dart';
part 'src/preview/preview_canvas.dart';
part 'src/preview/difference_preview.dart';
part 'src/preview/preview_components.dart';
part 'src/explorer/explorer_sidebar.dart';
part 'src/settings_ui/settings_sidebar.dart';
part 'src/settings_ui/hover_value_slider.dart';
part 'src/settings_ui/metadata_section.dart';
part 'src/settings_ui/storage_section.dart';
part 'src/settings_ui/settings_modes.dart';
part 'src/analyze_ui/analyze_panel.dart';
part 'src/app/title_bar.dart';
part 'src/bottom_bar/bottom_sidebar.dart';
part 'src/bottom_bar/bottom_stats.dart';
part 'src/bottom_bar/bottom_quality.dart';
part 'src/bottom_bar/bottom_summary.dart';
part 'src/ui/common_widgets.dart';
part 'src/settings_ui/optimization_section.dart';
part 'src/ui/choice_widgets.dart';
part 'src/ui/formatters.dart';
part 'src/home/home_empty_state.dart';
part 'src/home/home_shader_backdrop.dart';
part 'src/ui/warnings.dart';
part 'src/home/home_acrylic_surface.dart';
part 'src/home/home_feature_preview.dart';

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
const _settingsBottomSectionsFoldThreshold = 650.0;
const List<({double value, Color color})> _qualityMetricColorStops = [
  (value: 0, color: Color(0xFFFF0000)),
  (value: 20, color: Color(0xFFAA0000)),
  (value: 40, color: Color(0xFFDE602E)),
  (value: 60, color: Color(0xFFDBDE25)),
  (value: 80, color: Color(0xFF34C759)),
  (value: 100, color: Color(0xFF0094D9)),
];

const List<({double value, Color color})> _savingsMetricColorStops = [
  ..._qualityMetricColorStops,
  (value: 200, color: Color(0xFFA21BB7)),
  (value: 400, color: Color(0xFFE31C76)),
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

final _packageVersionProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return packageInfo.version;
});

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
