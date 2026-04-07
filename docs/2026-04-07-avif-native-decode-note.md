## AVIF Native Decode Note

### Summary

For now, we are tentatively dropping native AVIF decode support from the Rust image stack used by OIMG.

This is a temporary decision to unblock macOS universal/profile builds. We should revisit it later and decide whether to restore native AVIF decode with a cleaner dependency/setup story.

### Triggering Issue

On Apple Silicon macOS, profile builds for the app compile Rust for both:

- `aarch64-apple-darwin`
- `x86_64-apple-darwin`

The current dependency graph pulls in `dav1d-sys` through the `image` crate's `avif-native` feature. During the `x86_64-apple-darwin` half of the build, `dav1d-sys` attempts to build `dav1d` from source and then discover it through `pkg-config`.

The observed failure is:

- `pkg-config has not been configured to support cross-compilation`

The build log also indicates a deeper problem: the `dav1d` Meson build is detecting the host as `aarch64` and compiling arm64 sources even during the `x86_64-apple-darwin` target build. That means this is not just a one-line `pkg-config` environment issue; it is also an architecture/cross-build configuration issue.

### Current Dependency Path

At the time of writing, the relevant path is:

- `slimg-core` enables `image` with `features = ["avif-native"]`
- `slimg-core` AVIF decode uses `image::load_from_memory_with_format(..., ImageFormat::Avif)`
- `image`'s `avif-native` feature pulls in `mp4parse` and `dav1d`
- `dav1d` pulls in `dav1d-sys`

### Why We Are Dropping It For Now

Solving this properly would likely require one of:

- a robust Meson cross-build configuration for `x86_64-apple-darwin`
- target-specific compiler and `pkg-config` configuration for `dav1d-sys`
- patching or forking `dav1d-sys`

That is heavier and more brittle than we want right now for OIMG.

### Temporary Direction

The near-term plan is:

- remove the `image` crate's `avif-native` dependency path from `slimg-core`
- accept that native AVIF decode support is temporarily unavailable
- keep the rest of the image pipeline/build working cleanly

### Revisit Options

When we return to this, the main options are:

1. Restore AVIF decode with a different decoder path that does not rely on `dav1d-sys`.
2. Keep using `dav1d`, but patch the build story so universal macOS builds work reliably.
3. Make native AVIF decode conditional by target/platform/build mode.

### Recommendation For Future Revisit

Prefer a code-side dependency simplification over a fragile environment workaround.

If we can restore AVIF decode without depending on `dav1d-sys` for universal macOS builds, that is likely the cleanest long-term solution.
