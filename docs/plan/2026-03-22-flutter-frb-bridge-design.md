# Flutter FRB Bridge Design

## Overview

Add a Flutter-specific Rust bridge crate for desktop platforms only, built with `flutter_rust_bridge` (FRB), that exposes a small, stable, high-level API over `slimg-core`.

This crate is not a wrapper over `slimg-ffi`.
It depends directly on `slimg-core` and presents a Flutter-friendly interface optimized for desktop app usage.

Target platforms:
- macOS (Apple Silicon, Intel)
- Linux (x86_64, aarch64 if the Flutter app targets it)
- Windows (x86_64)

Non-goals:
- Android support
- iOS support
- Reusing UniFFI-generated bindings
- Exposing every low-level `slimg-core` type 1:1 into Dart
- Returning large decoded RGBA buffers to Dart by default

## Why A Separate FRB Crate

`slimg-core` is already the clean architectural center of the repo. It contains the real image pipeline and has a small API surface.

A dedicated FRB crate is preferred over reusing `slimg-ffi` because:
- FRB has its own code generation and type conventions
- Flutter needs a more opinionated API than the generic UniFFI layer
- Desktop app usage benefits from file-oriented operations and async execution helpers
- The Flutter surface should be able to evolve without affecting Python/Kotlin bindings

Recommended crate name:
- Rust crate: `slimg-frb`
- Flutter package name: `slimg_flutter_bridge` or `slimg_native`

## Goals

1. Expose the most useful image operations to Flutter with minimal Dart-side ceremony.
2. Keep the pipeline in Rust so Dart does not orchestrate decode/transform/encode steps manually.
3. Support both file-oriented and byte-oriented workflows.
4. Keep the public FRB API small enough to remain stable.
5. Avoid unnecessary memory copies and avoid raw RGBA transfer unless explicitly requested.
6. Make desktop packaging predictable.

## Design Principles

### 1. High-level API first

The FRB layer should expose operations that match actual app workflows:
- load metadata
- generate preview
- process one file
- process many files
- process raw bytes

Do not expose the entire `slimg-core` surface unless there is a concrete Flutter use case.

### 2. File-oriented by default

Desktop Flutter apps commonly work with file paths. The FRB bridge should treat file operations as the primary path and bytes as a secondary path.

### 3. Stable typed requests

Use request structs with explicit fields instead of many positional parameters. This keeps the Dart side ergonomic and gives room for backward-compatible additions.

### 4. Rust owns correctness

Validation should happen in Rust, not Dart. Dart can do light UI validation, but Rust is the source of truth for:
- required field combinations
- path behavior
- format parsing
- crop/resize/extend mode semantics
- file overwrite rules

### 5. Small semantic gap from `slimg-core`

The bridge should preserve `slimg-core` behavior, not invent a separate pipeline model.

## Proposed Project Structure

```text
crates/
├── slimg-core/
├── slimg-ffi/
├── libjxl-sys/
└── slimg-frb/
    ├── Cargo.toml
    └── src/
        ├── lib.rs
        ├── api.rs
        ├── types.rs
        ├── convert.rs
        ├── fs.rs
        ├── preview.rs
        ├── error.rs
        └── codec.rs

flutter/
└── slimg_flutter_bridge/
    ├── pubspec.yaml
    ├── lib/
    │   ├── slimg_flutter_bridge.dart
    │   └── src/
    │       ├── api.dart
    │       ├── models.dart
    │       └── errors.dart
    ├── rust_builder/
    └── README.md
```

If the Flutter package lives in a separate repository, the Rust crate should still live in this repo and be consumed from that package.

## Workspace Changes

Add the crate to the workspace:

```toml
[workspace]
members = [
  "crates/slimg-core",
  "crates/slimg-ffi",
  "crates/libjxl-sys",
  "crates/slimg-frb",
  "cli",
]
```

No existing crate should depend on `slimg-frb`.
It is a leaf integration crate.

## Public API Shape

The FRB API should be organized around a service-like namespace, not free functions scattered across files.

Recommended top-level FRB surface:

```rust
pub struct SlimgBridge;

impl SlimgBridge {
    pub fn version() -> String;
    pub fn supported_formats() -> Vec<FormatInfo>;

    pub fn inspect_file(input_path: String) -> Result<ImageMetadata, SlimgBridgeError>;
    pub fn inspect_bytes(data: Vec<u8>) -> Result<ImageMetadata, SlimgBridgeError>;

    pub fn preview_file(request: PreviewFileRequest) -> Result<PreviewResult, SlimgBridgeError>;
    pub fn process_file(request: ProcessFileRequest) -> Result<ProcessResult, SlimgBridgeError>;
    pub fn process_bytes(request: ProcessBytesRequest) -> Result<EncodedImageResult, SlimgBridgeError>;

    pub fn process_files(request: BatchProcessRequest) -> Result<Vec<BatchItemResult>, SlimgBridgeError>;
}
```

If FRB prefers top-level functions in implementation, keep the generated Dart API grouped behind a single Dart facade.

## Core Types

### FormatInfo

```rust
pub struct FormatInfo {
    pub id: String,          // "jpeg", "png", "webp", "avif", "jxl", "qoi"
    pub extension: String,   // canonical extension
    pub can_encode: bool,
}
```

### ImageMetadata

```rust
pub struct ImageMetadata {
    pub width: u32,
    pub height: u32,
    pub format: String,
    pub file_size: Option<u64>,
}
```

`file_size` is `Some` for file inspection and `None` for bytes inspection.

### PreviewResult

```rust
pub struct PreviewResult {
    pub encoded_bytes: Vec<u8>,
    pub format: String,
    pub width: u32,
    pub height: u32,
    pub size_bytes: u64,
}
```

Preview should return encoded bytes directly.
Dart can display them using `MemoryImage`.

No base64 should be used in the FRB layer.
Desktop Flutter does not benefit from it.

### EncodedImageResult

```rust
pub struct EncodedImageResult {
    pub encoded_bytes: Vec<u8>,
    pub format: String,
    pub width: u32,
    pub height: u32,
    pub size_bytes: u64,
}
```

### ProcessResult

```rust
pub struct ProcessResult {
    pub output_path: String,
    pub format: String,
    pub width: u32,
    pub height: u32,
    pub original_size: u64,
    pub new_size: u64,
}
```

### BatchItemResult

```rust
pub struct BatchItemResult {
    pub input_path: String,
    pub success: bool,
    pub result: Option<ProcessResult>,
    pub error: Option<SlimgBridgeError>,
}
```

Batch mode should not fail all items because one file fails.
A whole-batch error should be reserved for invalid request-level issues only.

## Request Types

### Shared Operation Model

Use a single operation enum so all entrypoints share one semantic model.

```rust
pub enum ImageOperation {
    Convert(ConvertOptions),
    Optimize(OptimizeOptions),
    Resize(ResizeOptions),
    Crop(CropOptions),
    Extend(ExtendOptions),
    Pipeline(PipelineSpec),
}
```

`Pipeline` is optional in v1.
If implementation scope must stay tight, omit it initially and keep one-operation requests only.

Because `slimg-core` already supports crop + extend + resize in a single `PipelineOptions`, v2 should expose a real multi-step pipeline rather than force Dart to chain multiple calls.

### ProcessFileRequest

```rust
pub struct ProcessFileRequest {
    pub input_path: String,
    pub output_path: Option<String>,
    pub overwrite: bool,
    pub operation: ImageOperation,
}
```

Semantics:
- `output_path = None` means derive output path from input and operation target format
- `overwrite = true` means write atomically to the input path or explicit output path if applicable
- For `Optimize`, if the result is larger and `overwrite = false`, behavior must be explicit; see Output Rules

### ProcessBytesRequest

```rust
pub struct ProcessBytesRequest {
    pub data: Vec<u8>,
    pub operation: ImageOperation,
}
```

### BatchProcessRequest

```rust
pub struct BatchProcessRequest {
    pub input_paths: Vec<String>,
    pub output_dir: Option<String>,
    pub overwrite: bool,
    pub operation: ImageOperation,
    pub continue_on_error: bool,
}
```

### PreviewFileRequest

```rust
pub struct PreviewFileRequest {
    pub input_path: String,
    pub operation: ImageOperation,
}
```

Preview should perform the full operation but must not write files.

## Operation Option Types

### ConvertOptions

```rust
pub struct ConvertOptions {
    pub target_format: String,
    pub quality: u8,
}
```

### OptimizeOptions

```rust
pub struct OptimizeOptions {
    pub quality: u8,
    pub write_only_if_smaller: bool,
}
```

### ResizeOptions

```rust
pub enum ResizeSpec {
    Width { value: u32 },
    Height { value: u32 },
    Exact { width: u32, height: u32 },
    Fit { max_width: u32, max_height: u32 },
    Scale { factor: f64 },
}

pub struct ResizeOptions {
    pub resize: ResizeSpec,
    pub target_format: Option<String>,
    pub quality: u8,
}
```

### CropOptions

```rust
pub enum CropSpec {
    Region { x: u32, y: u32, width: u32, height: u32 },
    AspectRatio { width: u32, height: u32 },
}

pub struct CropOptions {
    pub crop: CropSpec,
    pub target_format: Option<String>,
    pub quality: u8,
}
```

### ExtendOptions

```rust
pub enum ExtendSpec {
    AspectRatio { width: u32, height: u32 },
    Size { width: u32, height: u32 },
}

pub enum FillSpec {
    Solid { r: u8, g: u8, b: u8, a: u8 },
    Transparent,
}

pub struct ExtendOptions {
    pub extend: ExtendSpec,
    pub fill: Option<FillSpec>,
    pub target_format: Option<String>,
    pub quality: u8,
}
```

### PipelineSpec

This is optional for v1, but recommended for the end state.

```rust
pub struct PipelineSpec {
    pub target_format: String,
    pub quality: u8,
    pub crop: Option<CropSpec>,
    pub extend: Option<ExtendSpec>,
    pub fill: Option<FillSpec>,
    pub resize: Option<ResizeSpec>,
}
```

Pipeline order must match `slimg-core`:
- crop
- extend
- resize
- encode

## Output Rules

These rules must be explicit so the Flutter app does not guess.

### `process_file`

- `Convert`: if `output_path` is absent, derive by changing extension to target format
- `Resize`, `Crop`, `Extend`: if `target_format` is absent, keep source format and derive output path from source extension; if present, derive new extension from target format
- `Optimize`: if `output_path` is absent and `overwrite = false`, derive a sibling output path using the same extension

Recommended optimize naming when not overwriting:
- `photo.jpg` -> `photo.optimized.jpg`

Do not reuse `slimg-core::output_path` blindly for all modes if it causes `optimize` to map back to the same input path.

### `process_files`

- If `output_dir` is set, place all outputs under it using derived file names
- If `output_dir` is absent and `overwrite = false`, place outputs next to originals
- If `overwrite = true`, write atomically to original paths

## Error Model

Define a dedicated FRB-visible error enum rather than leaking `slimg_core::Error` directly.

```rust
pub enum SlimgBridgeError {
    InvalidRequest { message: String },
    InvalidPath { path: String, message: String },
    UnsupportedFormat { format: String },
    UnknownFormat { detail: String },
    Decode { message: String },
    Encode { message: String },
    Resize { message: String },
    Crop { message: String },
    Extend { message: String },
    Io { message: String },
    Internal { message: String },
}
```

Mapping rules:
- invalid combinations of request fields -> `InvalidRequest`
- unknown target format string -> `UnsupportedFormat`
- missing file -> `InvalidPath` or `Io`
- `slimg_core::Error::*` maps to the corresponding domain error
- panics or impossible states must be caught and returned as `Internal` where practical

Batch behavior:
- per-file failures should be embedded in `BatchItemResult`
- only malformed batch-level input should fail the entire batch call

## Rust Implementation Plan

### `types.rs`

Contains all FRB-visible structs/enums.
Must remain small and explicit.

### `error.rs`

Contains:
- `SlimgBridgeError`
- `type Result<T> = std::result::Result<T, SlimgBridgeError>`
- conversions from `slimg_core::Error`, `std::io::Error`, and internal validation failures

### `codec.rs`

Contains format parsing helpers:
- `parse_format(&str) -> Result<slimg_core::Format>`
- `format_to_string(slimg_core::Format) -> String`
- `format_info() -> Vec<FormatInfo>`

Use lowercase format ids in the FRB API:
- `jpeg`
- `png`
- `webp`
- `avif`
- `jxl`
- `qoi`

### `convert.rs`

Contains mapping logic from FRB request types into `slimg_core::PipelineOptions` and execution helpers for:
- bytes processing
- file processing
- preview processing

### `fs.rs`

Contains path and write helpers:
- derive output path
- generate optimized sibling name
- safe atomic write
- optional collision handling

Reuse the CLI's `safe_write` ideas, but do not copy the CLI API unchanged.

### `preview.rs`

Contains preview-specific execution.
Preview should never touch disk.

### `api.rs`

Contains FRB-exported functions or methods and should stay thin.
It should delegate all real logic to helper modules.

### `lib.rs`

Wires modules together and exposes the FRB surface.

## Path Handling Rules

Normalize behavior across platforms:
- accept UTF-8 strings from Dart
- use `PathBuf` internally
- return output paths as strings via `to_string_lossy()` only at the API boundary

Do not expose `PathBuf` directly through FRB.

## Concurrency Model

Desktop-only means the bridge can lean on native threads, but the API should still be predictable.

Recommended rules:
- single-item methods may run synchronously in Rust and asynchronously from Dart via FRB
- batch methods should process files in parallel using Rayon or a bounded thread pool
- batch result ordering must match input ordering

Recommended batch implementation:
- preserve input order with indexed work items
- do not stream progress in v1 unless there is a concrete UI requirement
- if progress is needed later, add a separate streaming/event design rather than complicating the v1 contract

Because another agent will implement this, v1 should prefer:
- `process_files(...) -> Vec<BatchItemResult>`
- no progress callbacks in the initial version

This keeps FRB integration simpler and makes correctness easier to verify.

## Memory Model

### Preferred data flows

- File in -> Rust decode/process/encode -> file out
- Bytes in -> Rust decode/process/encode -> encoded bytes out

### Avoid by default

- File in -> decode to RGBA -> return RGBA to Dart
- Large image buffers crossing the FFI boundary unnecessarily

If a decoded-raw-image API is ever needed, it should be a separate, explicitly labeled advanced path.

## Format Support

Desktop scope means the FRB crate may expose the same format set as `slimg-core`.

Target v1 support:
- JPEG
- PNG
- WebP
- AVIF
- QOI
- JXL

However, implementation should isolate format parsing and capability reporting so formats can be disabled later if packaging problems arise.

## Desktop Packaging Notes

The FRB crate must not assume Flutter packaging will magically discover native dependencies.
Implementation handoff should include:
- macOS dynamic library placement
- Windows DLL placement
- Linux shared library placement or bundling rules

The Rust side should produce a standard dynamic library suitable for Flutter desktop embedding.
The Flutter package should document how the generated native library is copied into each desktop runner.

## Cargo Configuration

### `crates/slimg-frb/Cargo.toml`

Expected dependencies:

```toml
[package]
name = "slimg-frb"
version = "0.1.0"
edition = "2024"
license = "MIT"
publish = false

[lib]
crate-type = ["cdylib", "staticlib", "rlib"]

[dependencies]
slimg-core = { path = "../slimg-core" }
flutter_rust_bridge = "..."
thiserror = "2"
rayon = "1"
anyhow = "1"
```

Exact FRB version can be chosen at implementation time.
The crate should not pull in UI- or Flutter-specific Rust dependencies beyond FRB.

## Flutter Package Expectations

The Flutter package should provide:
- generated FRB bindings
- a thin Dart facade wrapping generated code
- simple model classes or direct reuse of generated types
- no business logic duplication

Recommended Dart API style:

```dart
final bridge = SlimgBridge();

final info = await bridge.inspectFile(inputPath: path);

final result = await bridge.processFile(
  request: ProcessFileRequest(
    inputPath: path,
    overwrite: false,
    operation: ImageOperation.convert(
      ConvertOptions(targetFormat: 'webp', quality: 80),
    ),
  ),
);
```

The Dart facade may add convenience helpers, but must not reinterpret semantics differently from Rust.

## Validation Rules

The Rust bridge must validate:
- quality in `0..=100`
- resize factors > 0
- required target format for `Convert`
- exactly one resize mode variant
- exactly one crop mode variant
- exactly one extend mode variant
- no empty input path
- batch requests have at least one file

Validation should happen before any expensive processing.

## Testing Strategy

### Rust unit tests

Add focused tests for:
- format parsing
- request validation
- output path derivation
- optimize naming rules
- error mapping
- batch ordering

### Rust integration tests

Add end-to-end tests for:
- `inspect_bytes`
- `process_bytes` convert to PNG/WebP/JPEG
- `process_file` resize/crop/extend/optimize
- overwrite vs non-overwrite behavior
- batch partial failure behavior

Reuse existing generated test images similar to `slimg-core/tests/integration.rs`.

### Flutter smoke tests

At minimum, the implementation handoff should include a manual verification matrix:
- macOS: inspect, preview, process one file
- Windows: inspect, process one file
- Linux: inspect, process one file

If automated Flutter integration tests are feasible, add one smoke test that calls the bridge and validates output bytes are non-empty.

## Documentation Deliverables

Implementation is not complete unless the following docs exist:
- crate-level README for `crates/slimg-frb`
- Flutter package README with setup instructions
- desktop packaging notes for macOS, Windows, Linux
- one end-to-end usage example from Flutter

## Incremental Delivery Plan

### Phase 1

- create `slimg-frb` crate
- wire FRB generation
- expose `version`, `supported_formats`, `inspect_file`, `inspect_bytes`

### Phase 2

- expose `process_bytes`
- expose `process_file`
- support `Convert`, `Optimize`, `Resize`, `Crop`, `Extend`

### Phase 3

- add `preview_file`
- add `process_files`
- add batch tests and packaging docs

### Phase 4

- optional multi-step `Pipeline` API
- optional progress/event model if a real Flutter UI requires it

## Acceptance Criteria

The bridge is considered complete when:

1. A Flutter desktop app can call Rust through FRB on macOS, Windows, and Linux.
2. Single-file inspect/process operations work for file and bytes inputs.
3. Batch processing returns ordered per-item results without failing the whole batch on one bad file.
4. Output path behavior is documented and tested.
5. No base64 is used in the FRB layer.
6. The FRB API does not expose raw RGBA buffers by default.
7. The bridge depends directly on `slimg-core`, not `slimg-ffi`.
8. The semantic model for resize/crop/extend is explicit and not stringly typed internally.
9. The crate includes Rust tests for validation, path derivation, and end-to-end processing.
10. A short Flutter example is included in docs.

## Explicit Decisions For The Implementing Agent

These decisions are already made and should not be reopened unless implementation proves them unworkable:
- desktop only
- direct dependency on `slimg-core`
- separate crate from `slimg-ffi`
- file-oriented API first
- bytes API second
- no base64 in FRB
- no raw RGBA API in v1
- batch returns collected results, not live progress events
- per-file batch failures are embedded in results
- request structs and enums, not loose string maps

## Open Questions Left Intentionally Small

The implementing agent may choose these details during implementation:
- exact FRB version
- exact Rust module boundaries
- final Flutter package name
- whether v1 includes the optional `Pipeline` operation
- whether Linux ARM64 is shipped in the initial verification matrix

These choices must not change the higher-level API direction above.
