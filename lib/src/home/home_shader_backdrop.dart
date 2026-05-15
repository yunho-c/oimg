part of 'package:oimg/main.dart';

class _HomeShaderBackdrop extends StatefulWidget {
  const _HomeShaderBackdrop({required this.borderRadius, required this.speed});

  static const _lightShaderAsset = 'assets/shaders/home_wavy_background.frag';
  static const _darkShaderAsset =
      'assets/shaders/home_wavy_background_dark.frag';

  static final _lightProgramFuture = ui.FragmentProgram.fromAsset(
    _lightShaderAsset,
  );
  static final _darkProgramFuture = ui.FragmentProgram.fromAsset(
    _darkShaderAsset,
  );

  final BorderRadiusGeometry borderRadius;
  final double speed;

  @override
  State<_HomeShaderBackdrop> createState() => _HomeShaderBackdropState();
}

class _HomeShaderBackdropState extends State<_HomeShaderBackdrop>
    with SingleTickerProviderStateMixin {
  Ticker? _shaderTicker;
  Duration _shaderElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (_shouldAnimateHomeShader) {
      _shaderTicker = createTicker((elapsed) {
        setState(() {
          _shaderElapsed = elapsed;
        });
      })..start();
    }
  }

  @override
  void dispose() {
    _shaderTicker?.dispose();
    super.dispose();
  }

  bool get _shouldAnimateHomeShader {
    var isWidgetTest = false;
    assert(() {
      isWidgetTest = WidgetsBinding.instance.runtimeType.toString().contains(
        'TestWidgetsFlutterBinding',
      );
      return true;
    }());
    return !isWidgetTest;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final darkMode = theme.brightness == ui.Brightness.dark;
    final shaderAsset = darkMode
        ? _HomeShaderBackdrop._darkShaderAsset
        : _HomeShaderBackdrop._lightShaderAsset;
    final programFuture = darkMode
        ? _HomeShaderBackdrop._darkProgramFuture
        : _HomeShaderBackdrop._lightProgramFuture;
    final fallback = _HomeShaderFallback(borderRadius: widget.borderRadius);
    return FutureBuilder<ui.FragmentProgram>(
      key: ValueKey(shaderAsset),
      future: programFuture,
      builder: (context, snapshot) {
        final program = snapshot.data;
        if (program == null) {
          return fallback;
        }

        return ClipRRect(
          borderRadius: widget.borderRadius.resolve(Directionality.of(context)),
          child: CustomPaint(
            painter: _HomeShaderPainter(
              program: program,
              time:
                  _shaderElapsed.inMicroseconds /
                  Duration.microsecondsPerSecond *
                  widget.speed,
            ),
          ),
        );
      },
    );
  }
}

class _HomeShaderFallback extends StatelessWidget {
  const _HomeShaderFallback({required this.borderRadius});

  final BorderRadiusGeometry borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.background,
            theme.colorScheme.secondary.withValues(alpha: 0.32),
          ],
        ),
      ),
    );
  }
}

class _HomeShaderPainter extends CustomPainter {
  const _HomeShaderPainter({required this.program, required this.time});

  final ui.FragmentProgram program;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final shader = program.fragmentShader()
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _HomeShaderPainter oldDelegate) {
    return oldDelegate.program != program || oldDelegate.time != time;
  }
}
