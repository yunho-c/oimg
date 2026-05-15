part of 'package:oimg/main.dart';

class _HomeAcrylicSurface extends StatelessWidget {
  const _HomeAcrylicSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.blurSigma = 20,
    this.baseColor,
    this.backgroundAlpha = 0.52,
    this.tintAlpha = 0.12,
    this.tintColor,
    this.borderAlpha = 0.62,
    this.shadowColor,
    this.shadowAlpha = 0.07,
  });

  final Widget child;
  final BorderRadiusGeometry borderRadius;
  final double blurSigma;
  final Color? baseColor;
  final double backgroundAlpha;
  final double tintAlpha;
  final Color? tintColor;
  final double borderAlpha;
  final Color? shadowColor;
  final double shadowAlpha;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedRadius = borderRadius.resolve(Directionality.of(context));
    final effectiveBaseColor = baseColor ?? theme.colorScheme.background;
    final effectiveTintColor = tintColor ?? theme.colorScheme.secondary;
    final effectiveMidTintColor = tintColor ?? theme.colorScheme.primary;
    final effectiveShadowColor = shadowColor ?? theme.colorScheme.foreground;

    return ClipRRect(
      borderRadius: resolvedRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: theme.colorScheme.border.withValues(alpha: borderAlpha),
            ),
            color: effectiveBaseColor.withValues(alpha: backgroundAlpha),
            gradient: tintAlpha <= 0
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      effectiveBaseColor.withValues(alpha: backgroundAlpha),
                      effectiveMidTintColor.withValues(alpha: tintAlpha * 0.55),
                      effectiveTintColor.withValues(alpha: tintAlpha),
                    ],
                  ),
            boxShadow: [
              BoxShadow(
                color: effectiveShadowColor.withValues(alpha: shadowAlpha),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
