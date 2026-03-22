# macOS Compression Actions Plan

## Goal

Add two Finder-invokable macOS actions for OIMG:

- `Compress image`
- `Compress image (keep original)`

These should operate on one or more selected image files and reuse the existing `slimg-core` optimize pipeline already exposed through the local Rust bridge crate.

## Chosen Implementation

Implement the macOS integration as app-provided `NSServices`, not as a Flutter plugin and not as a Finder Sync extension.

Reasons:

- The image-processing logic already exists in the bundled Rust library.
- Finder Sync is the wrong abstraction for arbitrary file compression actions.
- A Flutter plugin does not meaningfully simplify Finder integration on macOS.
- Services are much lighter than adding a separate extension target and are a good fit for selected-file actions originating in Finder.

## Architecture

### 1. Native macOS entrypoints

Add two service entries to `macos/Runner/Info.plist`:

- `Compress image`
- `Compress image (keep original)`

They should:

- be scoped to Finder via `NSRequiredContext`
- accept file inputs
- route both actions to a single service-provider object with different `NSUserData` values

### 2. Service provider in Swift

Add a native service provider object in the macOS runner that:

- registers itself through `NSApp.servicesProvider`
- reads selected file URLs from the service pasteboard
- filters to OIMG-supported image extensions
- converts the service action into a native compression request
- calls into Rust synchronously
- reports service errors through the standard Services error pointer

Action mapping:

- `Compress image` => overwrite original
- `Compress image (keep original)` => write sibling output

### 3. Rust service FFI

Add a very small C ABI layer in the Rust crate for the service path.

This is separate from FRB and exists only so the native macOS runner can call into the already-linked Rust code without going through Flutter.

The FFI layer should:

- accept a JSON request string
- invoke the existing optimize pipeline with a fixed preset
- return a JSON response string
- avoid introducing a second compression implementation

### 4. Compression preset

Use a single preset for this pass:

- operation: `Optimize`
- quality: `80`
- `write_only_if_smaller: true`

Behavior:

- overwrite mode updates the original file only when the optimized payload is smaller
- keep-original mode writes `name.optimized.ext`

### 5. Packaging and registration

Register services during app launch and trigger `NSUpdateDynamicServices()` to make development iteration less painful.

This still depends on normal macOS service discovery behavior, so practical testing should assume the app is installed in an `Applications` location or otherwise built as a proper `.app` bundle.

## Notes / Non-goals

- This pass is for macOS only.
- This pass does not add a full Finder Action extension target.
- This pass does not attempt a separate “lossless” semantic mode.
- This pass does not build a general-purpose native plugin API around Finder services.

## Validation

- Rust tests for the new service request/response path
- `cargo test --manifest-path rust/Cargo.toml`
- `flutter analyze`
- `flutter test`
- `flutter build macos --debug`
- manual Finder verification after service registration refresh
