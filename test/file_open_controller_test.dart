import 'package:flutter_test/flutter_test.dart';
import 'package:oimg/src/file_open/file_open_channel.dart';
import 'package:oimg/src/file_open/file_open_controller.dart';

void main() {
  group('FileOpenController', () {
    test('accepts supported image extensions case-insensitively', () async {
      final controller = FileOpenController(
        channel: _FakeFileOpenChannel(),
        initialPaths: const ['photo.JPG', 'notes.txt', 'scan.TIFF'],
      );

      await controller.initialize();

      expect(controller.sessionPaths, ['photo.JPG', 'scan.TIFF']);
      expect(controller.currentIndex, 0);
    });

    test(
      'keeps current session and emits notice when all files are unsupported',
      () async {
        final controller = FileOpenController(
          channel: _FakeFileOpenChannel(),
          initialPaths: const ['cover.png'],
        );

        await controller.initialize();
        await controller.openPaths(const ['readme.md']);

        expect(controller.sessionPaths, ['cover.png']);
        expect(
          controller.takePendingNotice(),
          'OIMG can only open PNG, JPEG, GIF, BMP, WebP, and TIFF files.',
        );
      },
    );

    test('replaces the session and resets the current index', () async {
      final controller = FileOpenController(
        channel: _FakeFileOpenChannel(),
        initialPaths: const ['first.png', 'second.png'],
      );

      await controller.initialize();
      controller.showNext();

      await controller.openPaths(const ['new-a.webp', 'new-b.bmp']);

      expect(controller.sessionPaths, ['new-a.webp', 'new-b.bmp']);
      expect(controller.currentIndex, 0);
    });

    test('supports bounded multi-file navigation', () async {
      final controller = FileOpenController(
        channel: _FakeFileOpenChannel(),
        initialPaths: const ['1.png', '2.png'],
      );

      await controller.initialize();

      expect(controller.canGoPrevious, isFalse);
      expect(controller.canGoNext, isTrue);

      controller.showPrevious();
      expect(controller.currentIndex, 0);

      controller.showNext();
      expect(controller.currentIndex, 1);
      expect(controller.canGoNext, isFalse);

      controller.showNext();
      expect(controller.currentIndex, 1);
    });
  });
}

class _FakeFileOpenChannel implements FileOpenChannel {
  @override
  Future<void> bind(OpenFilesHandler onOpenFiles) async {}
}
