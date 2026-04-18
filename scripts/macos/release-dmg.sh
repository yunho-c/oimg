#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Build a macOS release app and package it as a DMG.

Usage:
  scripts/macos/release-dmg.sh [--sign] [--notarize]

Behavior:
  - Prepares Flutter macOS release config
  - Builds an unsigned release app with `xcodebuild`
  - Always creates a DMG under `dist/macos/`
  - `--sign` signs the built app and DMG using `APPLE_SIGN_IDENTITY`
  - `--notarize` notarizes and staples the DMG using `APPLE_NOTARY_PROFILE`

Required environment variables:
  APPLE_SIGN_IDENTITY   Signing identity for `codesign` when `--sign` is used
  APPLE_NOTARY_PROFILE  Keychain profile for `xcrun notarytool` when `--notarize` is used

Optional environment variables:
  APP_NAME    Override app name (default: PRODUCT_NAME from macOS config, then OIMG)
  DMG_NAME    Override DMG filename prefix (default: APP_NAME)
  DIST_DIR    Override artifact output directory (default: dist/macos)
EOF
}

require_tool() {
  local tool="$1"
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool" >&2
    exit 1
  fi
}

require_env() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: $name" >&2
    exit 1
  fi
}

repo_root() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$script_dir/../.." && pwd
}

read_product_name() {
  local xcconfig="$1"
  if [[ -f "$xcconfig" ]]; then
    awk -F'= ' '/^PRODUCT_NAME = / { print $2; exit }' "$xcconfig"
  fi
}

read_build_name() {
  local pubspec="$1"
  awk '/^version:/ { split($2, parts, "+"); print parts[1]; exit }' "$pubspec"
}

build_release_app() {
  echo "==> Preparing Flutter macOS release config"
  flutter build macos --release --config-only

  echo "==> Building unsigned macOS release app"
  xcodebuild \
    -workspace "$ROOT/macos/Runner.xcworkspace" \
    -scheme Runner \
    -configuration Release \
    -derivedDataPath "$ROOT/build/macos" \
    -destination "generic/platform=macOS" \
    OBJROOT="$ROOT/build/macos/Build/Intermediates.noindex" \
    SYMROOT="$ROOT/build/macos/Build/Products" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    -quiet
}

sign_app_if_requested() {
  local app_path="$1"

  if [[ "$SIGN_ARTIFACTS" != "1" ]]; then
    echo "==> Skipping app signing"
    return
  fi

  echo "==> Signing app bundle"
  codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp \
    --sign "$APPLE_SIGN_IDENTITY" \
    "$app_path"
}

package_dmg() {
  local app_path="$1"
  local dmg_path="$2"
  local volume_name="$3"
  local staging_dir="$4"

  echo "==> Packaging DMG"
  rm -rf "$staging_dir"
  mkdir -p "$staging_dir"
  cp -R "$app_path" "$staging_dir/"
  ln -s /Applications "$staging_dir/Applications"

  rm -f "$dmg_path"
  hdiutil create \
    -volname "$volume_name" \
    -srcfolder "$staging_dir" \
    -ov \
    -format UDZO \
    "$dmg_path"

  rm -rf "$staging_dir"
}

sign_dmg_if_requested() {
  local dmg_path="$1"

  if [[ "$SIGN_ARTIFACTS" != "1" ]]; then
    echo "==> Skipping DMG signing"
    return
  fi

  echo "==> Signing DMG"
  codesign \
    --force \
    --timestamp \
    --sign "$APPLE_SIGN_IDENTITY" \
    "$dmg_path"
}

notarize_dmg_if_requested() {
  local dmg_path="$1"

  if [[ "$NOTARIZE_ARTIFACTS" != "1" ]]; then
    echo "==> Skipping notarization"
    return
  fi

  echo "==> Submitting DMG for notarization"
  xcrun notarytool submit "$dmg_path" --keychain-profile "$APPLE_NOTARY_PROFILE" --wait

  echo "==> Stapling notarization ticket"
  xcrun stapler staple "$dmg_path"
}

SIGN_ARTIFACTS=0
NOTARIZE_ARTIFACTS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sign)
      SIGN_ARTIFACTS=1
      ;;
    --notarize)
      SIGN_ARTIFACTS=1
      NOTARIZE_ARTIFACTS=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

ROOT="$(repo_root)"
PUBSPEC_PATH="$ROOT/pubspec.yaml"
APP_INFO_XCCONFIG="$ROOT/macos/Runner/Configs/AppInfo.xcconfig"

APP_NAME="${APP_NAME:-$(read_product_name "$APP_INFO_XCCONFIG")}"
APP_NAME="${APP_NAME:-OIMG}"
DMG_NAME="${DMG_NAME:-$APP_NAME}"
BUILD_NAME="$(read_build_name "$PUBSPEC_PATH")"
BUILD_NAME="${BUILD_NAME:-0.0.0}"
DIST_DIR="${DIST_DIR:-$ROOT/dist/macos}"
ARTIFACT_BASENAME="${DMG_NAME}-${BUILD_NAME}"
APP_PATH="$ROOT/build/macos/Build/Products/Release/${APP_NAME}.app"
DMG_PATH="$DIST_DIR/${ARTIFACT_BASENAME}.dmg"
STAGING_DIR="$ROOT/build/macos_dmg_staging/${ARTIFACT_BASENAME}"

require_tool flutter
require_tool xcodebuild
require_tool hdiutil

if [[ "$SIGN_ARTIFACTS" == "1" ]]; then
  require_tool codesign
  require_env APPLE_SIGN_IDENTITY
fi

if [[ "$NOTARIZE_ARTIFACTS" == "1" ]]; then
  require_tool xcrun
  require_env APPLE_NOTARY_PROFILE
fi

mkdir -p "$DIST_DIR"

cd "$ROOT"
build_release_app

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected built app not found: $APP_PATH" >&2
  exit 1
fi

sign_app_if_requested "$APP_PATH"
package_dmg "$APP_PATH" "$DMG_PATH" "$APP_NAME" "$STAGING_DIR"
sign_dmg_if_requested "$DMG_PATH"
notarize_dmg_if_requested "$DMG_PATH"

echo
echo "Created artifact:"
echo "  $DMG_PATH"
if [[ "$NOTARIZE_ARTIFACTS" == "1" ]]; then
  echo "Notarization and stapling completed."
elif [[ "$SIGN_ARTIFACTS" == "1" ]]; then
  echo "Artifact is signed but not notarized."
else
  echo "Artifact is unsigned."
fi
