part of 'package:oimg/main.dart';

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
    final appSettings = ref.watch(appSettingsProvider).asData?.value;
    final secondaryTextColor = _homeSecondaryTextColor(theme);
    final homeAcrylicPanelEnabled =
        appSettings?.homeAcrylicPanelEnabled ??
        AppSettings.defaults.homeAcrylicPanelEnabled;

    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = math.min(
          1180.0,
          math.max(0.0, constraints.maxWidth - 56),
        );
        final wide = contentWidth >= 920;
        final wideHero = contentWidth >= 760;

        final hero = _EmptyStateHeroPanel(
          acrylicEnabled: homeAcrylicPanelEnabled,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 30, 28, 28),
            child: LayoutBuilder(
              builder: (context, heroConstraints) {
                final useHeroGrid = wideHero && heroConstraints.maxWidth >= 620;
                final titleGroup = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Optimize images easily',
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
                        color: secondaryTextColor,
                        fontSize: 13.6,
                        height: 1.5,
                      ),
                    ),
                  ],
                );
                final actionGroup = Align(
                  alignment: useHeroGrid
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: useHeroGrid
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (buttonContext) {
                          return PrimaryButton(
                            key: const ValueKey('empty-state-browse-button'),
                            size: ButtonSize.large,
                            density: ButtonDensity.normal,
                            onPressed: () =>
                                _showBrowseMenu(buttonContext, ref),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(LucideIcons.folderSearch, size: 18),
                                SizedBox(width: 10),
                                Text(
                                  'Open images',
                                  textScaler: TextScaler.linear(0.7),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'or drop files and folders anywhere',
                        textAlign: useHeroGrid
                            ? TextAlign.right
                            : TextAlign.left,
                        style: TextStyle(color: secondaryTextColor),
                      ).small(),
                    ],
                  ),
                );

                if (useHeroGrid) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 3, child: titleGroup),
                      const SizedBox(width: 28),
                      Expanded(flex: 2, child: actionGroup),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    titleGroup,
                    const SizedBox(height: 26),
                    actionGroup,
                  ],
                );
              },
            ),
          ),
        );

        final supportCards = const [
          _EmptyStateFeatureCard(
            cardKey: ValueKey('empty-state-feature-preview'),
            icon: LucideIcons.sparkles,
            title: 'Preview',
            description: 'Inspect optimized images before you hit save.',
            previewVideoUrl: 'https://media.oimg.org/videos/preview_demo.mp4',
          ),
          _EmptyStateFeatureCard(
            cardKey: ValueKey('empty-state-feature-compare'),
            icon: LucideIcons.badgePercent,
            title: 'Compare',
            description:
                'See how different image formats compare in savings, quality, and compatibility.',
            previewVideoUrl: 'https://media.oimg.org/videos/compare_demo.mp4',
          ),
          _EmptyStateFeatureCard(
            cardKey: ValueKey('empty-state-feature-analyze'),
            icon: LucideIcons.chartSpline,
            title: 'Analyze',
            description:
                'Explore the balance between size and quality using image quality analysis methods.',
            previewVideoUrl: 'https://media.oimg.org/videos/analyze_demo.mp4',
          ),
        ];

        final support = wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: supportCards[0]),
                  const SizedBox(width: 10),
                  Expanded(child: supportCards[1]),
                  const SizedBox(width: 10),
                  Expanded(child: supportCards[2]),
                ],
              )
            : Column(
                children: [
                  supportCards[0],
                  const SizedBox(height: 10),
                  supportCards[1],
                  const SizedBox(height: 10),
                  supportCards[2],
                ],
              );

        return Stack(
          children: [
            Positioned.fill(
              child: _HomeShaderBackdrop(
                borderRadius: BorderRadius.zero,
                speed:
                    appSettings?.homeShaderSpeed ??
                    AppSettings.defaultHomeShaderSpeed,
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: contentWidth * 0.8,
                          ),
                          child: hero,
                        ),
                        const SizedBox(height: 18),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: contentWidth * 0.8,
                          ),
                          child: support,
                        ),
                        const SizedBox(height: 44),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(left: 20, bottom: 19, child: _EmptyStateCredit()),
            Positioned(
              right: 28,
              bottom: 24,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.end,
                children: [
                  _EmptyStateFooterButton(
                    key: const ValueKey('empty-state-github-button'),
                    hoverColor: const Color(0xFF7B4BDA),
                    icon: LucideIcons.github,
                    label: 'GitHub',
                    onPressed: () async {
                      await launchUrl(
                        Uri.parse('https://github.com/yunho-c/oimg'),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                  _EmptyStateFooterButton(
                    key: const ValueKey('empty-state-feedback-button'),
                    hoverColor: const Color(0xFFE9822E),
                    icon: LucideIcons.messageSquare,
                    label: 'Feedback',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyStateHeroPanel extends StatelessWidget {
  const _EmptyStateHeroPanel({
    required this.acrylicEnabled,
    required this.child,
  });

  final bool acrylicEnabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = theme.borderRadiusXxl.resolve(
      Directionality.of(context),
    );

    if (acrylicEnabled) {
      final darkMode = theme.brightness == ui.Brightness.dark;
      final baseColor = darkMode
          ? const Color(0xFFF8FAFC).withValues(alpha: 0.126)
          : Color.lerp(
              theme.colorScheme.background,
              Colors.white,
              0.45,
            )!.withValues(alpha: 0.612);
      final borderColor = darkMode
          ? Colors.white.withValues(alpha: 0.18)
          : Colors.white.withValues(alpha: 0.58);

      return DecoratedBox(
        key: const ValueKey('empty-state-hero-acrylic-panel'),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: darkMode ? 0.18 : 0.08),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(color: borderColor),
                color: baseColor,
              ),
              child: child,
            ),
          ),
        ),
      );
    }

    return Container(
      key: const ValueKey('empty-state-hero-gradient-panel'),
      decoration: BoxDecoration(
        borderRadius: borderRadius,
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
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
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
                color: theme.colorScheme.secondaryForeground.withValues(
                  alpha: 0.05,
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _EmptyStateCredit extends StatelessWidget {
  const _EmptyStateCredit();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.mutedForeground.withValues(
      alpha: theme.brightness == ui.Brightness.dark ? 0.86 : 0.80,
    );
    final style = TextStyle(color: color, fontSize: 11.5, height: 1.2);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Built with care by ', style: style),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              await launchUrl(
                Uri.parse('https://yunhocho.com/'),
                mode: LaunchMode.externalApplication,
              );
            },
            child: Text(
              'Yunho Cho',
              style: style.copyWith(
                decoration: TextDecoration.underline,
                decorationColor: color.withValues(alpha: 0.75),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyStateFooterButton extends StatelessWidget {
  const _EmptyStateFooterButton({
    super.key,
    required this.hoverColor,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Color hoverColor;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      variance: ButtonVariance.outline.copyWith(
        decoration: (context, states, decoration) {
          if (decoration is BoxDecoration &&
              states.contains(WidgetState.hovered)) {
            return decoration.copyWith(
              color: hoverColor,
              border: Border.all(color: hoverColor),
            );
          }
          return decoration;
        },
        textStyle: (context, states, textStyle) {
          if (states.contains(WidgetState.hovered)) {
            return textStyle.copyWith(color: const Color(0xFFFFFFFF));
          }
          return textStyle;
        },
        iconTheme: (context, states, iconTheme) {
          if (states.contains(WidgetState.hovered)) {
            return iconTheme.copyWith(color: const Color(0xFFFFFFFF));
          }
          return iconTheme;
        },
      ),
    );

    return Button(
      style: style,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 15), const SizedBox(width: 8), Text(label)],
      ),
    );
  }
}
