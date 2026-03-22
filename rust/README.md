# OIMG FRB Bridge

This crate exposes a desktop-focused `flutter_rust_bridge` API on top of `slimg-core`.

## Surface

- `version`
- `supported_formats`
- `inspect_file`
- `inspect_bytes`
- `preview_file`
- `process_file`
- `process_bytes`
- `process_files`

The bridge keeps request validation and image pipeline behavior in Rust. Dart receives typed request/result models and encoded image bytes only.

## Output Rules

- `Convert` with no `output_path` changes the extension to the target format.
- `Optimize` with `overwrite=false` writes `name.optimized.ext`.
- `Resize`, `Crop`, and `Extend` keep the source format unless `target_format` is set.
- When an auto-derived non-overwrite path would collide with the input file, the bridge writes a suffixed sibling such as `name.resized.ext`.
- `write_only_if_smaller` keeps the original file untouched when the optimized payload is not smaller.

## Flutter Usage

```dart
import 'package:oimg/src/rust/slimg_bridge.dart';

final bridge = SlimgBridge();

final result = await bridge.processFile(
  request: ProcessFileRequest(
    inputPath: '/tmp/photo.jpg',
    overwrite: false,
    operation: ImageOperation.convert(
      ConvertOptions(targetFormat: 'webp', quality: 80),
    ),
  ),
);
```

## Desktop Packaging

- macOS: the generated `oimg_rust.framework` or dylib must be bundled with the app runner.
- Windows: copy the generated Rust DLL next to `Runner.exe`.
- Linux: ship the generated `.so` with the runner bundle and ensure the loader can resolve it.

The repo already uses `rust_builder/` and Cargokit for native artifact integration.
