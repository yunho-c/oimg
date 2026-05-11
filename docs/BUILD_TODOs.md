# Build TODOs

## Linux desktop entry source of truth

The Linux build currently has two desktop entry templates:

- `linux/oimg.desktop.in` for the Flutter/CMake bundle.
- `debian/gui/oimg.desktop.in` for `flutter_to_debian` packaging.

This duplication exists because `flutter_to_debian` appends its own `Exec=/opt/oimg/oimg ...` and `TryExec=...` lines when building the final package. Including `Exec=` in the Debian template produces duplicate `Exec` keys and fails `desktop-file-validate`.

Follow-up: make `scripts/linux/package-deb.sh` derive the generated Debian desktop entry from `linux/oimg.desktop.in`, stripping or replacing only the fields that `flutter_to_debian` must own. Keep `linux/oimg.desktop.in` as the single source of truth for shared metadata such as name, MIME types, categories, and startup class.

## Windows release signing

The Windows release workflow currently produces unsigned ZIP and Inno Setup installer artifacts. It also produces an unsigned Microsoft Store MSIX because Store distribution signs submitted packages.

Follow-up: add Authenticode signing before ZIP and installer packaging once a Windows code-signing certificate is available in CI. The workflow should sign `oimg.exe`, bundled DLLs, and the setup EXE, verify the signatures, then upload the signed artifacts.

## Linux release hardening

- Add Linux `arm64` release support with either a native ARM runner or a deliberate cross-build path.
- Add Debian package signing and apt repository metadata if OIMG is distributed through an apt source instead of GitHub Release downloads.

## Release dependency pinning

The release workflows currently checkout sibling repositories from the branches used by this app.

Follow-up: pin `slimg`, `tjdistler-iqa-fork`, and `irondash` to release tags or commit SHAs before publishing stable releases, so release rebuilds do not silently pick up branch changes.
