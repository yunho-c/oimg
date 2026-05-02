## AVIF Native Decode Note

### Summary

AVIF decode support has been restored in the Rust image stack used by OIMG through `zenavif`.

The restored path avoids the deprecated `image`/`dav1d-sys` decode dependency that blocked macOS universal/profile builds.

### Triggering Issue

On Apple Silicon macOS, profile builds for the app compile Rust for both:

- `aarch64-apple-darwin`
- `x86_64-apple-darwin`

The current dependency graph pulls in `dav1d-sys` through the `image` crate's `avif-native` feature. During the `x86_64-apple-darwin` half of the build, `dav1d-sys` attempts to build `dav1d` from source and then discover it through `pkg-config`.

The observed failure is:

- `pkg-config has not been configured to support cross-compilation`

The build log also indicates a deeper problem: the `dav1d` Meson build is detecting the host as `aarch64` and compiling arm64 sources even during the `x86_64-apple-darwin` target build. That means this is not just a one-line `pkg-config` environment issue; it is also an architecture/cross-build configuration issue.

### Previous Dependency Path

The removed dependency path was:

- `slimg-core` enables `image` with `features = ["avif-native"]`
- `slimg-core` AVIF decode uses `image::load_from_memory_with_format(..., ImageFormat::Avif)`
- `image`'s `avif-native` feature pulls in `mp4parse` and `dav1d`
- `dav1d` pulls in `dav1d-sys`

### Replacement Direction

`slimg-core` now decodes AVIF via `zenavif`, then converts the decoded pixels into the 8-bit RGBA `ImageData` representation expected by OIMG.

This means AVIF previews should include decoded RGBA bytes, so preview metrics and difference images can run for AVIF outputs instead of treating native decode as unavailable.

### Build Impact

The OIMG macOS build no longer needs the old `dav1d-sys` environment workaround for local Debug builds. Any future AVIF decode build issue should be investigated through the `zenavif` dependency path first, not by restoring the old `dav1d-sys` setup.

### Recommendation For Future Revisit

Keep AVIF decode on a code-side dependency path that avoids fragile target-specific environment setup for universal macOS builds.
