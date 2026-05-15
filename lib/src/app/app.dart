part of 'package:oimg/main.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseTypography = const Typography.geist().scale(_uiScale);
    final settings = ref.watch(appSettingsProvider).asData?.value;
    final colorSchemePreference =
        settings?.colorSchemePreference ??
        AppSettings.defaults.colorSchemePreference;

    return ShadcnApp(
      title: 'OIMG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: _lightColorScheme(colorSchemePreference),
        radius: _uiRadius,
        scaling: _uiScale,
        typography: baseTypography,
        surfaceOpacity: 0.92,
        surfaceBlur: 8,
      ),
      darkTheme: ThemeData.dark(
        colorScheme: _darkColorScheme(colorSchemePreference),
        radius: _uiRadius,
        scaling: _uiScale,
        typography: baseTypography,
        surfaceOpacity: 0.88,
        surfaceBlur: 12,
      ),
      themeMode: settings?.themePreference.themeMode ?? ThemeMode.system,
      home: const OimgHomePage(),
    );
  }
}

ColorScheme _lightColorScheme(AppColorSchemePreference preference) {
  return switch (preference) {
    AppColorSchemePreference.slate => ColorSchemes.lightSlate,
    AppColorSchemePreference.zinc => ColorSchemes.lightZinc,
    AppColorSchemePreference.stone => ColorSchemes.lightStone,
    AppColorSchemePreference.neutral => ColorSchemes.lightNeutral,
    AppColorSchemePreference.gray => ColorSchemes.lightGray,
  };
}

ColorScheme _darkColorScheme(AppColorSchemePreference preference) {
  return switch (preference) {
    AppColorSchemePreference.slate => ColorSchemes.darkSlate,
    AppColorSchemePreference.zinc => ColorSchemes.darkZinc,
    AppColorSchemePreference.stone => ColorSchemes.darkStone,
    AppColorSchemePreference.neutral => ColorSchemes.darkNeutral,
    AppColorSchemePreference.gray => ColorSchemes.darkGray,
  };
}
