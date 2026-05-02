# macOS CI/CD Setup

One-time setup required before the GitHub macOS release workflow can build signed and notarized DMGs.

## GitHub Secrets

Add these secrets in GitHub under **Settings > Secrets and variables > Actions > Repository secrets**.

| Secret | Purpose |
| --- | --- |
| `CI_REPO_TOKEN` | GitHub token with read access to `yunho-c/slimg`, `yunho-c/tjdistler-iqa-fork`, and `yunho-c/irondash`. |
| `APPLE_CERTIFICATE_P12_BASE64` | Base64-encoded Developer ID Application `.p12` certificate. |
| `APPLE_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12`. |
| `APPLE_SIGN_IDENTITY` | Exact signing identity, for example `Developer ID Application: Your Name (TEAMID)`. |
| `APPLE_ASC_KEY_ID` | App Store Connect API key ID. |
| `APPLE_ASC_ISSUER_ID` | App Store Connect issuer ID. |
| `APPLE_ASC_API_KEY_P8` | Full contents of the App Store Connect API private key file. |
| `KEYCHAIN_PASSWORD` | Random password used only for the temporary CI keychain. |

## GitHub Token

Create a fine-grained personal access token that can read the sibling repositories:

- `yunho-c/slimg`
- `yunho-c/tjdistler-iqa-fork`
- `yunho-c/irondash`

Give it read-only repository contents access, then save it as `CI_REPO_TOKEN`.

## Developer ID Certificate

Use an Apple Developer account that has a **Developer ID Application** certificate.

1. Open **Keychain Access** on the Mac that has the certificate and private key.
2. Select the **Developer ID Application** certificate and its private key.
3. Export them as a `.p12` file.
4. Set a strong export password.
5. Base64 encode the `.p12`:

   ```bash
   base64 -i DeveloperIDApplication.p12 -o DeveloperIDApplication.p12.base64
   ```

6. Save the base64 file contents as `APPLE_CERTIFICATE_P12_BASE64`.
7. Save the export password as `APPLE_CERTIFICATE_PASSWORD`.
8. Save the exact identity as `APPLE_SIGN_IDENTITY`.

To find the exact identity locally:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

## App Store Connect API Key

Create an App Store Connect API key that can be used for notarization.

1. In App Store Connect, open **Users and Access > Integrations > App Store Connect API**.
2. Create or select an API key with access suitable for Developer ID notarization.
3. Download the private key file. Apple only allows downloading it once.
4. Save the key ID as `APPLE_ASC_KEY_ID`.
5. Save the issuer ID as `APPLE_ASC_ISSUER_ID`.
6. Save the full `.p8` file contents as `APPLE_ASC_API_KEY_P8`.

Paste the `.p8` contents exactly, including:

```text
-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----
```

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

The workflow creates a draft GitHub Release and attaches the DMG.

Before publishing the draft:

1. Download the DMG from the draft release.
2. Open the DMG.
3. Launch OIMG.
4. Confirm macOS does not show signing or notarization warnings.
5. Open an image and run a basic optimization.
6. Publish the GitHub Release when the DMG looks correct.

## Notes

- The workflow currently checks out sibling repos from the branches used by this app: `slimg` from `feat/zenavif`, `tjdistler-iqa-fork` from `perf/simd-gaussian-vertical`, and `irondash` from `fix/macos-engine-context-race`.
- For more reproducible releases, later pin those sibling checkouts to tags or commit SHAs.
- The workflow uses GitHub-hosted `macos-14`; update that runner deliberately when changing Xcode/macOS build environments.
