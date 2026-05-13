# Windows CI/CD Setup

One-time setup required before the GitHub Windows release workflow can build ZIP releases, Inno Setup installers, and Microsoft Store MSIX packages.

## GitHub Secrets

Add this secret in GitHub under **Settings > Secrets and variables > Actions > Repository secrets**.

| Secret | Purpose |
| --- | --- |
| `CI_REPO_TOKEN` | GitHub token with read access to `yunho-c/slimg`, `yunho-c/tjdistler-iqa-fork`, and `yunho-c/irondash`. |

## GitHub Token

Create a fine-grained personal access token that can read the sibling repositories:

- `yunho-c/slimg`
- `yunho-c/tjdistler-iqa-fork`
- `yunho-c/irondash`

Give it read-only repository contents access, then save it as `CI_REPO_TOKEN`.

## Build Environment

The workflow runs on GitHub-hosted Windows and installs the native tools needed by the Windows build:

- Flutter stable
- Rust `stable-x86_64-pc-windows-msvc`
- NASM
- LLVM
- Inno Setup 6.3 or newer

The workflow uses `scripts/windows/build_windows.ps1` so Rust and Cargokit use the x64 MSVC toolchain consistently.

The workflow uses Inno Setup to package the existing release build as a per-user x64-compatible installer. The installer creates a Start Menu shortcut, offers an optional desktop shortcut, and registers OIMG in Windows Open with for supported image files.

For local installer packaging after a release build, run:

```powershell
just windows-installer
```

The workflow then uses `dart run msix:create` to package the existing release build for Microsoft Store submission. The MSIX package is intentionally unsigned because Microsoft Store signs packages after submission.

## Release Workflow

The workflow runs for tags named `v*` and can also be retried manually from the GitHub Actions UI.

Normal release flow:

```bash
git switch main
git pull --ff-only
```

Update `pubspec.yaml`:

```yaml
version: 1.0.1+2
```

Run local checks:

```bash
flutter analyze
flutter test test/settings test/file_open_controller_test.dart test/file_open_channel_test.dart test/optimization
env RUSTC_WRAPPER= CARGO_BUILD_RUSTC_WRAPPER= cargo test --manifest-path rust/Cargo.toml
```

Commit and tag:

```bash
git add pubspec.yaml pubspec.lock
git commit -m "Bump version to 1.0.1"
git tag v1.0.1
git push origin main v1.0.1
```

The tag version must match the public version in `pubspec.yaml`. For example, `v1.0.1` matches `version: 1.0.1+2`.

## After the Workflow Finishes

The workflow creates a draft GitHub Release and attaches:

- `OIMG-<version>-windows-x64.zip`
- `OIMG-<version>-windows-x64.zip.sha256`
- `OIMG-<version>-windows-x64-setup.exe`
- `OIMG-<version>-windows-x64-setup.exe.sha256`
- `OIMG-<version>-windows-x64.msix`
- `OIMG-<version>-windows-x64.msix.sha256`

Before publishing the draft:

1. Download the ZIP, setup EXE, and MSIX from the draft release.
2. Extract the ZIP on Windows.
3. Launch `oimg.exe`.
4. Run the setup EXE.
5. Launch OIMG from the Start Menu.
6. Confirm any SmartScreen warning is only the expected unsigned-app warning.
7. Open an image from OIMG.
8. Use Windows Open with on an image file.
9. Uninstall OIMG from Windows Settings.
10. Run a basic optimization.
11. Submit the MSIX to Microsoft Store.
12. Publish the GitHub Release when the ZIP, installer, and Store package look correct.

## Microsoft Store

The MSIX configuration uses the Partner Center identity for OIMG:

- Publisher display name: `Yunho Cho`
- Identity name: `YunhoCho.OIMG`
- Publisher: `CN=5FD6739C-65DE-4602-8C56-90200FC1D6DC`

The MSIX manifest declares the same supported image file extensions as the native Windows runner.

The workflow passes the release tag version to MSIX as `<version>.0`. For example, tag `v1.0.1` becomes MSIX version `1.0.1.0`.

## Future Signing

The Windows ZIP and setup EXE are unsigned until a code-signing certificate is available in CI. The Microsoft Store MSIX is also unsigned before submission because Store distribution signs the package.

When signing is added, the workflow should:

- Import the certificate into a temporary CI certificate store.
- Sign `oimg.exe` and bundled DLLs before packaging.
- Sign the setup EXE after Inno Setup packaging.
- Verify signatures before uploading artifacts.

Expected future secrets:

- `WINDOWS_CERTIFICATE_PFX_BASE64`
- `WINDOWS_CERTIFICATE_PASSWORD`

## Notes

- The workflow currently checks out sibling repos from the branches used by this app: `slimg` from `feat/zenavif`, `tjdistler-iqa-fork` from `perf/simd-gaussian-vertical`, and `irondash` from `fix/macos-engine-context-race`.
- For more reproducible releases, later pin those sibling checkouts to tags or commit SHAs.
- The workflow uses GitHub-hosted `windows-2025`; update that runner deliberately when changing the Windows build environment.
