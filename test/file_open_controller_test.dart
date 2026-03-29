import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oimg/src/file_open/file_open_channel.dart';
import 'package:oimg/src/file_open/file_open_controller.dart';
import 'package:oimg/src/rust/slimg_api.dart';
import 'package:oimg/src/rust/types.dart';

void main() {
  group('FileOpenController', () {
    test('accepts files that slimg can inspect', () async {
      final controller = FileOpenController(
        channel: _FakeFileOpenChannel(),
        slimg: _FakeSlimgApi(
          inspectResults: {
            'photo.JPG': _metadata('jpeg'),
            'scan.TIFF': _metadata('png'),
          },
        ),
        initialPaths: const ['photo.JPG', 'notes.txt', 'scan.TIFF'],
      );

      await controller.initialize();

      expect(controller.sessionPaths, ['photo.JPG', 'scan.TIFF']);
      expect(controller.currentIndex, 0);
    });

    test(
      'keeps current session and emits notice when all files fail inspection',
      () async {
        final controller = FileOpenController(
          channel: _FakeFileOpenChannel(),
          slimg: _FakeSlimgApi(
            inspectResults: {'cover.png': _metadata('png')},
          ),
          initialPaths: const ['cover.png'],
        );

        await controller.initialize();
        await controller.openPaths(const ['readme.md']);

        expect(controller.sessionPaths, ['cover.png']);
        expect(controller.takePendingNotice(), 'Some files could not be opened.');
      },
    );

    test('replaces the session and resets the current index', () async {
      final controller = FileOpenController(
        channel: _FakeFileOpenChannel(),
        slimg: _FakeSlimgApi(
          inspectResults: {
            'first.png': _metadata('png'),
            'second.png': _metadata('png'),
            'new-a.webp': _metadata('webp'),
            'new-b.bmp': _metadata('jpeg'),
          },
        ),
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
        slimg: _FakeSlimgApi(
          inspectResults: {
            '1.png': _metadata('png'),
            '2.png': _metadata('png'),
          },
        ),
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

    test('can select a file directly by path', () async {
      final controller = FileOpenController(
        channel: _FakeFileOpenChannel(),
        slimg: _FakeSlimgApi(
          inspectResults: {
            '1.png': _metadata('png'),
            '2.png': _metadata('png'),
            '3.png': _metadata('png'),
          },
        ),
        initialPaths: const ['1.png', '2.png', '3.png'],
      );

      await controller.initialize();
      controller.showPath('3.png');

      expect(controller.currentIndex, 2);
      expect(controller.currentPath, '3.png');

      controller.showPath('missing.png');
      expect(controller.currentIndex, 2);
    });
  });
}

ImageMetadata _metadata(String format) {
  return ImageMetadata(
    width: 48,
    height: 32,
    format: format,
    fileSize: BigInt.from(1024),
  );
}

class _FakeFileOpenChannel implements FileOpenChannel {
  @override
  Future<void> bind(OpenFilesHandler onOpenFiles) async {}
}

class _FakeSlimgApi implements SlimgApi {
  _FakeSlimgApi({required this.inspectResults});

  final Map<String, ImageMetadata> inspectResults;

  @override
  Future<ImageMetadata> inspectFile({required String inputPath}) async {
    final value = inspectResults[inputPath];
    if (value == null) {
      throw StateError('unsupported');
    }
    return value;
  }

  @override
  Future<PreviewResult> previewFile({required PreviewFileRequest request}) async {
    return PreviewResult(
      encodedBytes: Uint8List(0),
      format: 'png',
      width: 48,
      height: 32,
      sizeBytes: BigInt.from(512),
    );
  }

  @override
  Future<ProcessResult> processFile({required ProcessFileRequest request}) {
    throw UnimplementedError();
  }

  @override
  Future<List<BatchItemResult>> processFileBatch({
    required ProcessFileBatchRequest request,
  }) {
    throw UnimplementedError();
  }
}
