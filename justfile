set shell := ["bash", "-euo", "pipefail", "-c"]
set windows-shell := ["powershell.exe", "-NoLogo", "-ExecutionPolicy", "Bypass", "-Command"]

default:
  @just --list

test-rust:
  cargo test --manifest-path rust/Cargo.toml

check-rust:
  cargo check --manifest-path rust/Cargo.toml

frb:
  flutter_rust_bridge_codegen generate

release-dmg:
  ./scripts/macos/release-dmg.sh

release-dmg-sign:
  ./scripts/macos/release-dmg.sh --sign

release-dmg-notarize:
  ./scripts/macos/release-dmg.sh --notarize

windows-build mode="debug":
    powershell -ExecutionPolicy Bypass -File scripts/windows/build_windows.ps1 -Command build -Mode {{mode}}

windows-run mode="debug":
    powershell -ExecutionPolicy Bypass -File scripts/windows/build_windows.ps1 -Command run -Mode {{mode}}
