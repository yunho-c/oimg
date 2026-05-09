part of 'package:oimg/main.dart';

class _EmptyStateFeatureCard extends StatelessWidget {
  const _EmptyStateFeatureCard({
    required this.cardKey,
    required this.icon,
    required this.title,
    required this.description,
    this.previewVideoUrl,
  });

  final Key cardKey;
  final IconData icon;
  final String title;
  final String description;
  final String? previewVideoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryTextColor = _homeSecondaryTextColor(theme);
    final darkMode = theme.brightness == ui.Brightness.dark;

    final card = _HomeAcrylicSurface(
      key: cardKey,
      borderRadius: theme.borderRadiusXl,
      blurSigma: 8,
      baseColor: darkMode ? null : Colors.white,
      backgroundAlpha: 0.24,
      tintAlpha: darkMode ? 0.06 : 0.12,
      tintColor: darkMode ? null : Colors.white,
      borderAlpha: darkMode ? 0.62 : 0.40,
      shadowColor: darkMode ? null : Colors.white,
      shadowAlpha: darkMode ? 0.07 : 0.25,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 20, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title).medium(),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(color: secondaryTextColor, height: 1.45),
                  ).small(),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return HoverCard(
      wait: const Duration(milliseconds: 250),
      debounce: const Duration(milliseconds: 120),
      anchorAlignment: Alignment.topCenter,
      popoverAlignment: Alignment.bottomCenter,
      popoverOffset: const Offset(0, -10),
      hoverBuilder: (context) {
        return _EmptyStateFeaturePreview(videoUrl: previewVideoUrl);
      },
      child: card,
    );
  }
}

Color _homeSecondaryTextColor(ThemeData theme) {
  return theme.brightness == ui.Brightness.dark
      ? theme.colorScheme.foreground.withValues(alpha: 0.70)
      : theme.colorScheme.foreground.withValues(alpha: 0.60);
}

class _EmptyStateFeaturePreview extends StatelessWidget {
  const _EmptyStateFeaturePreview({this.videoUrl});

  final String? videoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewportSize = MediaQuery.sizeOf(context);
    const aspectRatio = 16 / 9;
    final maxPreviewWidth = math.max(0.0, viewportSize.width - 96);
    final maxPreviewHeight = math.max(0.0, viewportSize.height - 180);
    var previewWidth = math.min(760.0, maxPreviewWidth);
    var previewHeight = previewWidth / aspectRatio;
    if (previewHeight > maxPreviewHeight) {
      previewHeight = maxPreviewHeight;
      previewWidth = previewHeight * aspectRatio;
    }

    return ClipRRect(
      key: const ValueKey('empty-state-feature-preview-panel'),
      borderRadius: theme.borderRadiusXl.resolve(Directionality.of(context)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: theme.borderRadiusXl,
            border: Border.all(
              color: theme.colorScheme.border.withValues(alpha: 0.72),
            ),
            color: theme.colorScheme.popover.withValues(alpha: 0.82),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.foreground.withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: SizedBox(
            width: previewWidth,
            height: previewHeight,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: videoUrl == null
                  ? const _EmptyStateFeaturePreviewFrame()
                  : _EmptyStateFeaturePreviewVideo(url: videoUrl!),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyStateFeaturePreviewVideo extends StatefulWidget {
  const _EmptyStateFeaturePreviewVideo({required this.url});

  final String url;

  @override
  State<_EmptyStateFeaturePreviewVideo> createState() =>
      _EmptyStateFeaturePreviewVideoState();
}

class _EmptyStateFeaturePreviewVideoState
    extends State<_EmptyStateFeaturePreviewVideo> {
  late final VideoPlayerController _controller;
  late final Future<void> _initializeFuture;
  var _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initializeFuture = _controller
        .initialize()
        .then((_) async {
          await _controller.setLooping(true);
          await _controller.setVolume(0);
          await _controller.play();
        })
        .catchError((Object _) {
          if (mounted) {
            setState(() {
              _loadFailed = true;
            });
          }
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: theme.borderRadiusLg.resolve(Directionality.of(context)),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: FutureBuilder<void>(
          future: _initializeFuture,
          builder: (context, snapshot) {
            if (_loadFailed ||
                snapshot.connectionState != ConnectionState.done ||
                !_controller.value.isInitialized) {
              return const _EmptyStateFeaturePreviewFrame();
            }

            return FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyStateFeaturePreviewFrame extends StatelessWidget {
  const _EmptyStateFeaturePreviewFrame();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: theme.borderRadiusLg,
        border: Border.all(
          color: theme.colorScheme.border.withValues(alpha: 0.65),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.14),
            theme.colorScheme.secondary.withValues(alpha: 0.12),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: _EmptyStateFeaturePreviewBlock(
                color: theme.colorScheme.primary.withValues(alpha: 0.34),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _EmptyStateFeaturePreviewBlock(
                color: theme.colorScheme.secondaryForeground.withValues(
                  alpha: 0.18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateFeaturePreviewBlock extends StatelessWidget {
  const _EmptyStateFeaturePreviewBlock({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: theme.borderRadiusSm,
      ),
    );
  }
}
