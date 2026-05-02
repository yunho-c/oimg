# Release Instructions

Recurring release steps. Platform-specific packaging details live below the shared flow.

## Shared Release Flow

1. Start from a clean `main` branch:

   ```bash
   git switch main
   git pull --ff-only
   git status --short
   ```

2. Update the app version in `pubspec.yaml`.

   Use `version: <release>+<build>`, for example:

   ```yaml
   version: 1.0.1+2
   ```

3. Run the release checks:

   ```bash
   flutter analyze
   flutter test test/settings test/file_open_controller_test.dart test/file_open_channel_test.dart test/optimization
   env RUSTC_WRAPPER= CARGO_BUILD_RUSTC_WRAPPER= cargo test --manifest-path rust/Cargo.toml
   ```

4. Commit the version bump:

   ```bash
   git add pubspec.yaml pubspec.lock
   git commit -m "Bump version to 1.0.1"
   ```

5. Create and push the release tag.

   Tag names should match the public version from `pubspec.yaml`, without the build number.

   ```bash
   git tag v1.0.1
   git push origin main v1.0.1
   ```

6. Wait for release workflows to finish.

   Tagged workflows should attach platform artifacts to the GitHub Release.

7. Verify the draft release before publishing:

   - Confirm the GitHub Release exists for the tag.
   - Confirm every expected platform artifact is attached.
   - Download each artifact.
   - Install or unpack each artifact on its target platform.
   - Launch OIMG.
   - Open an image and run a basic optimization.

## Current Platform: macOS

The macOS release workflow should build, sign, notarize, staple, and upload a DMG.

macOS verification checklist:

- Download the DMG from the draft release.
- Open the DMG and launch OIMG.
- Check that macOS does not show a signing or notarization warning.
- Open an image and run a basic optimization.

## Current Platform: Linux Debian

The Linux Debian release workflow should build, validate, and upload an unsigned `amd64` `.deb`.

Linux verification checklist:

- Download the `.deb` from the draft release.
- Install it on Debian/Ubuntu/Pop!_OS:

  ```bash
  sudo dpkg -i oimg_*_amd64.deb
  sudo apt install -f
  ```

- Launch OIMG.
- Check image Open With metadata:

  ```bash
  gio mime image/png
  gio mime image/avif
  ```

- If testing Nautilus integration, restart Files and verify the context menu:

  ```bash
  nautilus -q
  ```

- Right-click a supported image in Nautilus and test:
  - `Compress image`
  - `Compress image (lossless)`
- Open an image and run a basic optimization in the app.

## Future Platforms

Windows packaging is not part of the current release workflow yet.

When it is added, extend this file with artifact naming, credentials, target OS assumptions, and manual smoke-test steps.
