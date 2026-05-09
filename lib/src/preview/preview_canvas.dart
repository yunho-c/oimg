part of 'package:oimg/main.dart';

class _PreviewCanvas extends StatelessWidget {
  const _PreviewCanvas({
    required this.fileName,
    this.path,
    this.encodedBytes,
    this.unavailableMessage,
  });

  final String fileName;
  final String? path;
  final Uint8List? encodedBytes;
  final String? unavailableMessage;

  @override
  Widget build(BuildContext context) {
    final populated = [
      path != null,
      encodedBytes != null,
    ].where((value) => value).length;
    assert(populated == 1);

    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 6,
      child: Container(
        alignment: Alignment.center,
        child: path != null
            ? Image.file(
                File(path!),
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) {
                  return _ImageLoadError(fileName: fileName);
                },
              )
            : Image.memory(
                encodedBytes!,
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) {
                  return _PreviewUnavailable(
                    message: unavailableMessage ?? 'Unable to render preview.',
                  );
                },
              ),
      ),
    );
  }
}
