part of 'package:oimg/main.dart';

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Basic(title: Text(title).small().medium());
  }
}

class _StorageDestinationCard extends StatelessWidget {
  const _StorageDestinationCard({
    required this.value,
    required this.enabled,
    required this.onTap,
    required this.child,
  });

  final StorageDestinationMode value;
  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('storage-destination-${value.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: IgnorePointer(
        child: RadioCard<StorageDestinationMode>(
          value: value,
          enabled: enabled,
          child: child,
        ),
      ),
    );
  }
}

extension on Widget {
  Widget mediumIf(bool condition) {
    if (!condition) {
      return this;
    }
    return medium();
  }
}
