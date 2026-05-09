part of 'package:oimg/main.dart';

class _HoverValueSlider extends StatefulWidget {
  const _HoverValueSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.hoverEnabled,
    this.hoverOpacityKey = const ValueKey('quality-slider-hover-opacity'),
    this.hoverValueKey = const ValueKey('quality-slider-hover-value'),
    this.onChanged,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final bool hoverEnabled;
  final Key hoverOpacityKey;
  final Key hoverValueKey;
  final ValueChanged<double>? onChanged;

  @override
  State<_HoverValueSlider> createState() => _HoverValueSliderState();
}

class _HoverValueSliderState extends State<_HoverValueSlider> {
  static const _labelGap = 6.0;
  static const _showDelay = Duration(milliseconds: 500);
  static const _showDuration = Duration(milliseconds: 200);

  double? _hoverDx;
  bool _dragging = false;
  bool _labelVisible = false;
  Timer? _showLabelTimer;

  bool get _supportsHover =>
      widget.hoverEnabled &&
      widget.onChanged != null &&
      (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  ValueChanged<SliderValue>? get _sliderOnChanged {
    final onChanged = widget.onChanged;
    if (onChanged == null) {
      return null;
    }
    return (value) => onChanged(value.value);
  }

  @override
  Widget build(BuildContext context) {
    if (!_supportsHover) {
      return Slider(
        value: SliderValue.single(widget.value),
        min: widget.min,
        max: widget.max,
        divisions: widget.divisions,
        onChanged: _sliderOnChanged,
      );
    }

    final theme = Theme.of(context);
    final scaling = theme.scaling;
    final trackInset = theme.density.baseGap * scaling * 0.5;
    final sliderHeight = 16 * scaling;
    final reservedLabelHeight = _hoverLabelSize(
      context,
      widget.value.round().toString(),
    ).height;

    return SizedBox(
      height: sliderHeight + _labelGap + reservedLabelHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final range = math.max(widget.max - widget.min, 0.0001);
          final trackWidth = math.max(
            constraints.maxWidth - trackInset * 2,
            1.0,
          );
          final activeValue = _dragging
              ? widget.value
              : _hoverDx == null
              ? null
              : _valueFromDx(
                  _hoverDx!,
                  trackInset: trackInset,
                  range: range,
                  trackWidth: trackWidth,
                );
          final labelCenterX = _dragging
              ? _dxForValue(
                  widget.value,
                  trackInset: trackInset,
                  range: range,
                  trackWidth: trackWidth,
                )
              : _hoverDx;
          final showLabel = activeValue != null && (_dragging || _labelVisible);
          final labelText = activeValue?.round().toString();
          final labelSize = labelText == null
              ? null
              : _hoverLabelSize(context, labelText);
          final labelWidth = labelSize?.width;
          final labelLeft = labelCenterX == null
              ? null
              : ((labelCenterX - labelWidth! / 2).clamp(
                  0.0,
                  math.max(constraints.maxWidth - labelWidth, 0.0),
                )).toDouble();

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                bottom: reservedLabelHeight + _labelGap,
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerHover: (event) =>
                      _setHoverDx(event.localPosition.dx),
                  onPointerMove: (event) {
                    if (!_dragging) {
                      return;
                    }
                    _setHoverDx(event.localPosition.dx);
                  },
                  onPointerDown: (event) => _setHoverDx(event.localPosition.dx),
                  onPointerUp: (_) {
                    if (!_dragging) {
                      return;
                    }
                    _setDragging(false);
                  },
                  onPointerCancel: (_) {
                    if (!_dragging) {
                      return;
                    }
                    _resetHoverState();
                  },
                  child: MouseRegion(
                    onExit: (_) {
                      if (_dragging) {
                        return;
                      }
                      _clearHoverDx();
                    },
                    child: Slider(
                      value: SliderValue.single(widget.value),
                      min: widget.min,
                      max: widget.max,
                      divisions: widget.divisions,
                      onChangeStart: (_) => _setDragging(true),
                      onChangeEnd: (_) => _setDragging(false),
                      onChanged: _sliderOnChanged,
                    ),
                  ),
                ),
              ),
              if (labelText != null && labelLeft != null && labelSize != null)
                Positioned(
                  left: labelLeft,
                  top: sliderHeight + _labelGap,
                  child: IgnorePointer(
                    child: AnimatedSlide(
                      duration: _showDuration,
                      curve: Curves.easeOutCubic,
                      offset: showLabel ? Offset.zero : const Offset(0, -0.12),
                      child: AnimatedOpacity(
                        key: widget.hoverOpacityKey,
                        duration: _showDuration,
                        curve: Curves.easeOutCubic,
                        opacity: showLabel ? 1 : 0,
                        child: TooltipContainer(
                          child: Text(labelText, key: widget.hoverValueKey),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _showLabelTimer?.cancel();
    super.dispose();
  }

  double _dxForValue(
    double value, {
    required double trackInset,
    required double range,
    required double trackWidth,
  }) {
    final normalized = ((value - widget.min) / range).clamp(0.0, 1.0);
    return trackInset + normalized * trackWidth;
  }

  void _setHoverDx(double dx) {
    if (_hoverDx == dx) {
      return;
    }
    setState(() {
      _hoverDx = dx;
    });
    if (_dragging) {
      _setLabelVisible(true);
      return;
    }
    _scheduleLabelShow();
  }

  void _clearHoverDx() {
    _showLabelTimer?.cancel();
    if (_hoverDx == null) {
      _setLabelVisible(false);
      return;
    }
    setState(() {
      _hoverDx = null;
      _labelVisible = false;
    });
  }

  void _setDragging(bool dragging) {
    _showLabelTimer?.cancel();
    if (_dragging == dragging) {
      if (dragging) {
        _setLabelVisible(true);
      }
      return;
    }
    setState(() {
      _dragging = dragging;
      if (dragging) {
        _labelVisible = true;
      }
    });
  }

  void _resetHoverState() {
    _showLabelTimer?.cancel();
    if (!_dragging && _hoverDx == null) {
      return;
    }
    setState(() {
      _dragging = false;
      _hoverDx = null;
      _labelVisible = false;
    });
  }

  void _scheduleLabelShow() {
    if (_labelVisible) {
      return;
    }
    _showLabelTimer?.cancel();
    _showLabelTimer = Timer(_showDelay, () {
      if (!mounted || _dragging || _hoverDx == null) {
        return;
      }
      _setLabelVisible(true);
    });
  }

  void _setLabelVisible(bool visible) {
    if (_labelVisible == visible) {
      return;
    }
    setState(() {
      _labelVisible = visible;
    });
  }

  Size _hoverLabelSize(BuildContext context, String text) {
    final theme = Theme.of(context);
    final scaling = theme.scaling;
    final densityGap = theme.density.baseGap * scaling;
    final densityContentPadding = theme.density.baseContentPadding * scaling;
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: theme.typography.xSmall),
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

  double _valueFromDx(
    double dx, {
    required double trackInset,
    required double range,
    required double trackWidth,
  }) {
    final normalized = ((dx - trackInset) / trackWidth).clamp(0.0, 1.0);
    if (widget.divisions == null || widget.divisions! <= 0) {
      return widget.min + normalized * range;
    }
    final snapped =
        (normalized * widget.divisions!).round() / widget.divisions!;
    return widget.min + snapped * range;
  }
}
