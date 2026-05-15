part of 'package:oimg/main.dart';

class DifferencePreview extends ConsumerStatefulWidget {
  const DifferencePreview({
    super.key,
    this.transformationController,
    required this.retentionScopeKey,
    required this.frame,
    required this.fileName,
    required this.showCoordinates,
    required this.useRgbSwatches,
    this.onShowCoordinatesChanged,
    this.onUseRgbSwatchesChanged,
    this.unavailableMessage = 'Unable to render preview.',
  });

  final TransformationController? transformationController;
  final String retentionScopeKey;
  final AsyncValue<PreviewDifferenceFrame?> frame;
  final String fileName;
  final bool showCoordinates;
  final bool useRgbSwatches;
  final ValueChanged<bool>? onShowCoordinatesChanged;
  final ValueChanged<bool>? onUseRgbSwatchesChanged;
  final String unavailableMessage;

  @override
  ConsumerState<DifferencePreview> createState() => _DifferencePreviewState();
}

class _DifferenceTooltipSample {
  const _DifferenceTooltipSample({
    required this.anchor,
    required this.pixelX,
    required this.pixelY,
    required this.red,
    required this.green,
    required this.blue,
  });

  final Offset anchor;
  final int pixelX;
  final int pixelY;
  final int red;
  final int green;
  final int blue;

  String get redLabel => red.toString().padLeft(3);
  String get greenLabel => green.toString().padLeft(3);
  String get blueLabel => blue.toString().padLeft(3);

  String get _rgbLabel => 'R $redLabel G $greenLabel B $blueLabel';

  String label({required bool showCoordinates}) {
    if (!showCoordinates) {
      return _rgbLabel;
    }
    return 'x $pixelX, y $pixelY\n$_rgbLabel';
  }
}

class _DifferencePreviewState extends ConsumerState<DifferencePreview> {
  static const _tooltipDelay = Duration(seconds: 1);
  static const _tooltipOffset = Offset(12, 12);
  static const _rgbSwatchSlotWidth = 34.0;

  ui.Image? _retainedSourceImage;
  ui.Image? _retainedImage;
  RawImageResult? _retainedRawImage;
  Offset? _hoverViewportOffset;
  _DifferenceTooltipSample? _tooltipSample;
  Timer? _tooltipTimer;
  late final TransformationController _ownedTransformationController;
  TransformationController get _transformationController =>
      widget.transformationController ?? _ownedTransformationController;

  bool get _supportsHover =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    _ownedTransformationController = TransformationController();
    _syncRetainedFrame();
  }

  @override
  void didUpdateWidget(covariant DifferencePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.retentionScopeKey != widget.retentionScopeKey) {
      _clearRetainedFrame();
      _transformationController.value = Matrix4.identity();
    }
    if (oldWidget.frame != widget.frame) {
      _resetTooltip(clearHover: false);
    }
    _syncRetainedFrame();
  }

  @override
  void dispose() {
    _tooltipTimer?.cancel();
    _ownedTransformationController.dispose();
    _clearRetainedFrame();
    super.dispose();
  }

  void _syncRetainedFrame() {
    final frame = widget.frame;
    if (frame case AsyncData(:final value)) {
      if (value == null) {
        _clearRetainedFrame();
        return;
      }
      if (!identical(value.image, _retainedSourceImage)) {
        _retainedImage?.dispose();
        _retainedSourceImage = value.image;
        _retainedImage = value.image.clone();
      }
      _retainedRawImage = value.rawImage;
    }
  }

  void _clearRetainedFrame() {
    _retainedSourceImage = null;
    _retainedImage?.dispose();
    _retainedImage = null;
    _retainedRawImage = null;
  }

  void _resetTooltip({bool clearHover = true}) {
    _tooltipTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      if (clearHover) {
        _hoverViewportOffset = null;
      }
      _tooltipSample = null;
    });
  }

  void _setHoverPosition(Offset position) {
    if (_hoverViewportOffset == position) {
      return;
    }
    _tooltipTimer?.cancel();
    setState(() {
      _hoverViewportOffset = position;
    });
  }

  void _scheduleTooltip({
    required Offset viewportOffset,
    required Size viewportSize,
    required RawImageResult rawImage,
  }) {
    _tooltipTimer?.cancel();
    _tooltipTimer = Timer(_tooltipDelay, () {
      if (!mounted || _hoverViewportOffset != viewportOffset) {
        return;
      }
      final sample = _sampleAtViewportOffset(
        viewportOffset: viewportOffset,
        viewportSize: viewportSize,
        rawImage: rawImage,
      );
      if (!mounted || sample == null) {
        return;
      }
      setState(() {
        _tooltipSample = sample;
      });
    });
  }

  void _handleHover({
    required Offset viewportOffset,
    required Size viewportSize,
    required RawImageResult rawImage,
  }) {
    if (!_supportsHover) {
      return;
    }
    final sample = _sampleAtViewportOffset(
      viewportOffset: viewportOffset,
      viewportSize: viewportSize,
      rawImage: rawImage,
    );
    if (sample == null) {
      _resetTooltip();
      return;
    }
    if (_hoverViewportOffset == viewportOffset) {
      return;
    }
    if (_tooltipSample != null) {
      _tooltipTimer?.cancel();
      setState(() {
        _hoverViewportOffset = viewportOffset;
        _tooltipSample = sample;
      });
      return;
    }
    _setHoverPosition(viewportOffset);
    _scheduleTooltip(
      viewportOffset: viewportOffset,
      viewportSize: viewportSize,
      rawImage: rawImage,
    );
  }

  _DifferenceTooltipSample? _sampleAtViewportOffset({
    required Offset viewportOffset,
    required Size viewportSize,
    required RawImageResult rawImage,
  }) {
    final sceneOffset = _transformationController.toScene(viewportOffset);
    final imageRect = _containedImageRect(
      viewportSize,
      Size(rawImage.width.toDouble(), rawImage.height.toDouble()),
    );
    if (!imageRect.contains(sceneOffset)) {
      return null;
    }

    final normalizedX = (sceneOffset.dx - imageRect.left) / imageRect.width;
    final normalizedY = (sceneOffset.dy - imageRect.top) / imageRect.height;
    final pixelX = math.min(
      math.max((normalizedX * rawImage.width).floor(), 0),
      rawImage.width - 1,
    );
    final pixelY = math.min(
      math.max((normalizedY * rawImage.height).floor(), 0),
      rawImage.height - 1,
    );
    final byteIndex = (pixelY * rawImage.width + pixelX) * 4;
    if (byteIndex + 2 >= rawImage.rgbaBytes.length) {
      return null;
    }

    return _DifferenceTooltipSample(
      anchor: viewportOffset,
      pixelX: pixelX,
      pixelY: pixelY,
      red: rawImage.rgbaBytes[byteIndex],
      green: rawImage.rgbaBytes[byteIndex + 1],
      blue: rawImage.rgbaBytes[byteIndex + 2],
    );
  }

  Rect _containedImageRect(Size viewportSize, Size imageSize) {
    if (viewportSize.isEmpty || imageSize.isEmpty) {
      return Rect.zero;
    }
    final scale = math.min(
      viewportSize.width / imageSize.width,
      viewportSize.height / imageSize.height,
    );
    final fittedSize = Size(imageSize.width * scale, imageSize.height * scale);
    final left = (viewportSize.width - fittedSize.width) / 2;
    final top = (viewportSize.height - fittedSize.height) / 2;
    return Rect.fromLTWH(left, top, fittedSize.width, fittedSize.height);
  }

  Size _tooltipSize(BuildContext context, String measurementText) {
    final theme = Theme.of(context);
    final scaling = theme.scaling;
    final densityGap = theme.density.baseGap * scaling;
    final densityContentPadding = theme.density.baseContentPadding * scaling;
    final textPainter = TextPainter(
      text: TextSpan(text: measurementText, style: theme.typography.xSmall),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final horizontalPadding = (densityContentPadding + densityGap) * 1.5;
    final verticalPadding = densityGap * 1.5;
    return Size(
      textPainter.width + horizontalPadding,
      textPainter.height + verticalPadding,
    );
  }

  String _formatDifferenceErrorStat(double value) => value.toStringAsFixed(1);

  Widget _buildDifferenceStatsCard(
    BuildContext context,
    DifferenceErrorStats stats,
  ) {
    final theme = Theme.of(context);

    Widget statRow(String label, String value) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: TextStyle(color: theme.colorScheme.mutedForeground),
            ).xSmall(),
          ),
          const SizedBox(width: 12),
          Text(value).xSmall().medium(),
        ],
      );
    }

    return SurfaceBlur(
      surfaceBlur: 8,
      borderRadius: theme.borderRadiusLg,
      child: Container(
        key: const ValueKey('difference-preview-stats-card'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.background.withValues(alpha: 0.72),
          borderRadius: theme.borderRadiusLg,
          border: Border.all(
            color: theme.colorScheme.border.withValues(alpha: 0.7),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            statRow('Mean', _formatDifferenceErrorStat(stats.mean)),
            const SizedBox(height: 4),
            statRow('Top 10%', _formatDifferenceErrorStat(stats.top10Percent)),
            const SizedBox(height: 4),
            statRow('Top 1%', _formatDifferenceErrorStat(stats.top1Percent)),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltipContent(
    BuildContext context,
    _DifferenceTooltipSample tooltip,
  ) {
    final numberStyle = TextStyle(
      fontFeatures: const [ui.FontFeature.tabularFigures()],
    );
    final rgbContent = widget.useRgbSwatches
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildRgbSwatchValue(
                key: const ValueKey('difference-preview-tooltip-r-swatch'),
                color: const Color(0xFFFF3B30),
                value: tooltip.redLabel,
                textStyle: numberStyle,
              ),
              const SizedBox(width: 8),
              _buildRgbSwatchValue(
                key: const ValueKey('difference-preview-tooltip-g-swatch'),
                color: const Color(0xFF34C759),
                value: tooltip.greenLabel,
                textStyle: numberStyle,
              ),
              const SizedBox(width: 8),
              _buildRgbSwatchValue(
                key: const ValueKey('difference-preview-tooltip-b-swatch'),
                color: const Color(0xFF0A84FF),
                value: tooltip.blueLabel,
                textStyle: numberStyle,
              ),
            ],
          )
        : Text(tooltip._rgbLabel, style: numberStyle);

    if (!widget.showCoordinates) {
      return KeyedSubtree(
        key: const ValueKey('difference-preview-tooltip'),
        child: rgbContent,
      );
    }

    return KeyedSubtree(
      key: const ValueKey('difference-preview-tooltip'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('x ${tooltip.pixelX}, y ${tooltip.pixelY}'),
          const SizedBox(height: 2),
          rgbContent,
        ],
      ),
    );
  }

  Widget _buildRgbSwatchValue({
    required Key key,
    required Color color,
    required String value,
    required TextStyle textStyle,
  }) {
    return SizedBox(
      key: key,
      width: _rgbSwatchSlotWidth,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 4),
          Text(value, style: textStyle),
        ],
      ),
    );
  }

  Widget _buildImageViewport({
    required ui.Image image,
    required RawImageResult rawImage,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        final imageRect = _containedImageRect(
          viewportSize,
          Size(rawImage.width.toDouble(), rawImage.height.toDouble()),
        );
        final tooltip = _tooltipSample;
        final errorStats = ref.watch(
          currentDifferenceErrorStatsProvider(rawImage),
        );
        final tooltipText = tooltip?.label(
          showCoordinates: widget.showCoordinates,
        );
        final tooltipMeasurementText = tooltip == null
            ? null
            : widget.useRgbSwatches
            ? widget.showCoordinates
                  ? 'x ${tooltip.pixelX}, y ${tooltip.pixelY}\n000 000 000'
                  : '000 000 000'
            : tooltipText;
        final tooltipSize = tooltipMeasurementText == null
            ? null
            : _tooltipSize(context, tooltipMeasurementText);
        final tooltipLeft = tooltip == null || tooltipSize == null
            ? null
            : ((tooltip.anchor.dx + _tooltipOffset.dx).clamp(
                0.0,
                math.max(viewportSize.width - tooltipSize.width, 0.0),
              )).toDouble();
        final tooltipTop = tooltip == null || tooltipSize == null
            ? null
            : ((tooltip.anchor.dy + _tooltipOffset.dy).clamp(
                0.0,
                math.max(viewportSize.height - tooltipSize.height, 0.0),
              )).toDouble();

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ContextMenu(
                items: [
                  MenuCheckbox(
                    key: const ValueKey(
                      'difference-tooltip-coordinates-toggle',
                    ),
                    value: widget.showCoordinates,
                    autoClose: false,
                    onChanged: widget.onShowCoordinatesChanged == null
                        ? null
                        : (context, value) {
                            widget.onShowCoordinatesChanged!(value);
                          },
                    child: const Text('Show coordinates'),
                  ),
                  MenuCheckbox(
                    key: const ValueKey('difference-tooltip-swatches-toggle'),
                    value: widget.useRgbSwatches,
                    autoClose: false,
                    onChanged: widget.onUseRgbSwatchesChanged == null
                        ? null
                        : (context, value) {
                            widget.onUseRgbSwatchesChanged!(value);
                          },
                    child: const Text('Use color swatches for RGB labels'),
                  ),
                ],
                child: Listener(
                  onPointerDown: (_) => _resetTooltip(),
                  onPointerSignal: (_) => _resetTooltip(),
                  child: MouseRegion(
                    key: const ValueKey('difference-preview-region'),
                    onHover: (event) => _handleHover(
                      viewportOffset: event.localPosition,
                      viewportSize: viewportSize,
                      rawImage: rawImage,
                    ),
                    onExit: (_) => _resetTooltip(),
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 0.5,
                      maxScale: 6,
                      onInteractionStart: (_) => _resetTooltip(),
                      onInteractionUpdate: (_) => _resetTooltip(),
                      child: SizedBox(
                        width: viewportSize.width,
                        height: viewportSize.height,
                        child: Center(
                          child: SizedBox(
                            width: imageRect.width,
                            height: imageRect.height,
                            child: RawImage(image: image, fit: BoxFit.fill),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (errorStats case AsyncData(:final value))
              Positioned(
                top: 8,
                right: 8,
                child: IgnorePointer(
                  child: _buildDifferenceStatsCard(context, value),
                ),
              ),
            if (tooltipText != null &&
                tooltipLeft != null &&
                tooltipTop != null)
              Positioned(
                left: tooltipLeft,
                top: tooltipTop,
                child: IgnorePointer(
                  child: TooltipContainer(
                    child: _buildTooltipContent(context, tooltip!),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final frame = widget.frame;
    return frame.when(
      data: (resolvedFrame) {
        if (resolvedFrame == null) {
          return _PreviewUnavailable(message: widget.unavailableMessage);
        }
        return KeyedSubtree(
          key: const ValueKey('difference-preview-ready'),
          child: _buildImageViewport(
            image: _retainedImage ?? resolvedFrame.image,
            rawImage: resolvedFrame.rawImage,
          ),
        );
      },
      loading: () {
        if (_retainedImage != null && _retainedRawImage != null) {
          return KeyedSubtree(
            key: const ValueKey('difference-preview-ready'),
            child: _buildImageViewport(
              image: _retainedImage!,
              rawImage: _retainedRawImage!,
            ),
          );
        }
        return const Center(
          key: ValueKey('difference-preview-loading'),
          child: CircularProgressIndicator(),
        );
      },
      error: (_, _) => _PreviewUnavailable(message: widget.unavailableMessage),
    );
  }
}
