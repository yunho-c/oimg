# oimg

Flutter desktop app scaffolded with `flutter_rust_bridge`.

## Structure

- Flutter app: `lib/`
- Rust crate: `rust/`
- Native build helper plugin: `rust_builder/`
- FRB config: `flutter_rust_bridge.yaml`

## Development

Run the app:

```bash
flutter run -d macos
```

Regenerate FRB bindings after changing Rust APIs:

```bash
flutter_rust_bridge_codegen generate
```

Check the Rust crate directly:

```bash
cargo check --manifest-path rust/Cargo.toml
```

## Linux Debian package

Build a local `.deb` for install testing:

```bash
scripts/linux/package-deb.sh
```

Install the generated package:

```bash
sudo dpkg -i debian/packages/*.deb
```

Check GNOME image association metadata after installing:

```bash
gio mime image/png
gio mime image/avif
gio launch /usr/share/applications/oimg.desktop /path/to/image.png
```
