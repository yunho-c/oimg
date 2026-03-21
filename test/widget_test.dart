import 'package:flutter_test/flutter_test.dart';
import 'package:oimg/main.dart';
import 'package:oimg/src/rust/frb_generated.dart';

void main() {
  RustLib.initMock(api: _FakeRustApi());

  testWidgets('renders Rust greeting', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Flutter + Rust Bridge'), findsOneWidget);
    expect(find.text('Hello, oimg!'), findsOneWidget);
  });
}

class _FakeRustApi extends RustLibApi {
  @override
  String crateApiSimpleGreet({required String name}) => 'Hello, $name!';

  @override
  Future<void> crateApiSimpleInitApp() async {}
}
