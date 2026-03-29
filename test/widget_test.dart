import 'package:flutter_test/flutter_test.dart';
import 'package:oimg/main.dart';
import 'package:oimg/src/file_open/file_open_channel.dart';
import 'package:oimg/src/file_open/file_open_controller.dart';

void main() {
  testWidgets('renders empty state with no startup files', (tester) async {
    final controller = FileOpenController(channel: _FakeFileOpenChannel());
    await controller.initialize();

    await tester.pumpWidget(MyApp(controller: controller));

    expect(find.text('Open an image with OIMG'), findsOneWidget);
    expect(find.text('Previous'), findsNothing);
  });

  testWidgets('renders startup session and navigation', (tester) async {
    final controller = FileOpenController(
      channel: _FakeFileOpenChannel(),
      initialPaths: const ['/tmp/first.png', '/tmp/second.jpg'],
    );
    await controller.initialize();

    await tester.pumpWidget(MyApp(controller: controller));

    expect(find.text('Files'), findsOneWidget);
    expect(find.text('first.png'), findsNWidgets(2));
    expect(find.text('second.jpg'), findsOneWidget);
    expect(find.text('Previous'), findsNothing);
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.text('second.jpg'));
    await tester.pump();

    expect(find.text('second.jpg'), findsNWidgets(2));
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('later openFiles event replaces the session', (tester) async {
    final channel = _FakeFileOpenChannel();
    final controller = FileOpenController(
      channel: channel,
      initialPaths: const ['/tmp/original.png'],
    );
    await controller.initialize();

    await tester.pumpWidget(MyApp(controller: controller));

    expect(find.text('original.png'), findsNWidgets(2));

    await channel.emit(const ['/tmp/new-one.webp', '/tmp/new-two.bmp']);
    await tester.pump();

    expect(find.text('new-one.webp'), findsNWidgets(2));
    expect(find.text('new-two.bmp'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
  });
}

class _FakeFileOpenChannel implements FileOpenChannel {
  OpenFilesHandler? _handler;

  @override
  Future<void> bind(OpenFilesHandler onOpenFiles) async {
    _handler = onOpenFiles;
  }

  Future<void> emit(List<String> paths) async {
    await _handler?.call(paths);
  }
}
