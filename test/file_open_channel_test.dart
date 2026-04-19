import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oimg/src/file_open/file_open_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('oimg/file_open');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('pickFiles parses path lists from the native channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'pickFiles');
          return <String>['/tmp/a.png', '/tmp/b.jpg'];
        });

    final fileOpenChannel = MethodChannelFileOpenChannel(channel: channel);

    final paths = await fileOpenChannel.pickFiles();

    expect(paths, ['/tmp/a.png', '/tmp/b.jpg']);
  });

  test('pickFolder parses path lists from the native channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'pickFolder');
          return <String>['/tmp/folder'];
        });

    final fileOpenChannel = MethodChannelFileOpenChannel(channel: channel);

    final paths = await fileOpenChannel.pickFolder();

    expect(paths, ['/tmp/folder']);
  });
}
