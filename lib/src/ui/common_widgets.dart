part of 'package:oimg/main.dart';

class _SettingsLabel extends StatelessWidget {
  const _SettingsLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label).xSmall().medium().muted();
  }
}
