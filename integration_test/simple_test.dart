import 'package:flutter_test/flutter_test.dart';
import 'package:oimg/main.dart';
import 'package:oimg/src/file_open/file_open_channel.dart';
import 'package:oimg/src/file_open/file_open_controller.dart';
import 'package:oimg/src/rust/frb_generated.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  testWidgets('Shows the empty state without opened files', (
    WidgetTester tester,
  ) async {
    final controller = FileOpenController(channel: _NoopFileOpenChannel());
    await controller.initialize();

    await tester.pumpWidget(MyApp(controller: controller));
    expect(find.text('Open an image with OIMG'), findsOneWidget);
  });
}

class _NoopFileOpenChannel implements FileOpenChannel {
  @override
  Future<void> bind(OpenFilesHandler onOpenFiles) async {}
}
