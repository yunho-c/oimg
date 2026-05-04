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

## Current Platform: Windows

The Windows release workflow builds an unsigned x64 ZIP and a Microsoft Store MSIX.

Windows artifacts:

- `OIMG-<version>-windows-x64.zip`
- `OIMG-<version>-windows-x64.msix`

Windows verification checklist:

- Download the ZIP and MSIX from the draft release.
- Extract the ZIP on Windows.
- Launch `oimg.exe`.
- Expect Windows SmartScreen warnings while the app is unsigned.
- Open an image from OIMG.
- Use Windows Open with on an image file.
- Run a basic optimization.
- Submit the MSIX to Microsoft Store for signing and distribution.

## Future Platforms

Linux Debian packaging is not part of the current release workflow yet.

When it is added, extend this file with:

- Artifact name and extension.
- Required signing or packaging credentials.
- Target OS version assumptions.
- Manual smoke-test steps.
