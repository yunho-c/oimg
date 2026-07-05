#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Build and export a Mac App Store archive.

Usage:
  scripts/macos/archive-mas.sh [--upload]

Behavior:
  - Prepares Flutter macOS release config
  - Archives the macOS app with Xcode automatic or manual signing
  - Exports the archive with method app-store-connect
  - With --upload, asks xcodebuild to upload to App Store Connect
  - Writes archive, export output, and diagnostics under dist/macos-mas/

Optional environment variables:
  APPLE_TEAM_ID               Developer team ID for signing/export (required)
  APPLE_MAS_SIGNING_STYLE     automatic or manual (default: automatic)
  APPLE_MAS_APP_CERTIFICATE   Manual signing app certificate selector/name
  APPLE_MAS_INSTALLER_CERTIFICATE
                              Manual signing installer certificate selector/name
  APPLE_MAS_PROFILE_NAME      Manual signing provisioning profile name or UUID
  APPLE_MAS_PROFILE_PATH      Optional local provisioning profile to install
  APPLE_ASC_KEY_ID            App Store Connect API key ID
  APPLE_ASC_ISSUER_ID         App Store Connect issuer ID
  APPLE_ASC_API_KEY_PATH      Path to AuthKey_<key-id>.p8
  APPLE_ASC_API_KEY_P8        Private key contents; written to a temporary file
  APP_NAME                    Override app name (default: PRODUCT_NAME, then OIMG)
  DIST_DIR                    Override output directory (default: dist/macos-mas)
EOF
}

require_tool() {
  local tool="$1"
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool" >&2
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

read_bundle_identifier() {
  local xcconfig="$1"
  if [[ -f "$xcconfig" ]]; then
    awk -F'= ' '/^PRODUCT_BUNDLE_IDENTIFIER = / { print $2; exit }' "$xcconfig"
  fi
}

read_build_name() {
  local pubspec="$1"
  awk '/^version:/ { split($2, parts, "+"); print parts[1]; exit }' "$pubspec"
}

absolute_path() {
  local path="$1"
  local dir
  local base

  if [[ "$path" == /* ]]; then
    printf '%s\n' "$path"
    return
  fi

  dir="$(dirname "$path")"
  base="$(basename "$path")"
  if [[ ! -d "$dir" ]]; then
    return 1
  fi

  (cd "$dir" && printf '%s/%s\n' "$(pwd -P)" "$base")
}

cleanup() {
  if [[ -n "${TEMP_API_KEY_PATH:-}" && -f "$TEMP_API_KEY_PATH" ]]; then
    rm -f "$TEMP_API_KEY_PATH"
  fi
  if [[ -n "${TEMP_PROFILE_PLIST:-}" && -f "$TEMP_PROFILE_PLIST" ]]; then
    rm -f "$TEMP_PROFILE_PLIST"
  fi
}

require_team_id() {
  if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
    cat >&2 <<'EOF'
APPLE_TEAM_ID is required for Mac App Store archives.

Set it to your Apple Developer Team ID, for example:
  export APPLE_TEAM_ID=ABCDE12345
EOF
    exit 1
  fi
}

prepare_api_key() {
  XCODE_AUTH_ARGS=()

  if [[ -n "${APPLE_ASC_API_KEY_P8:-}" ]]; then
    if [[ -z "${APPLE_ASC_KEY_ID:-}" ]]; then
      echo "APPLE_ASC_KEY_ID is required when APPLE_ASC_API_KEY_P8 is set." >&2
      exit 1
    fi

    local private_keys_dir
    private_keys_dir="${TMPDIR:-/tmp}/oimg-mas-private-keys"
    mkdir -p "$private_keys_dir"
    TEMP_API_KEY_PATH="$private_keys_dir/AuthKey_${APPLE_ASC_KEY_ID}.p8"
    printf '%s\n' "$APPLE_ASC_API_KEY_P8" > "$TEMP_API_KEY_PATH"
    chmod 600 "$TEMP_API_KEY_PATH"
    APPLE_ASC_API_KEY_PATH="$TEMP_API_KEY_PATH"
  fi

  if [[ -n "${APPLE_ASC_API_KEY_PATH:-}" || -n "${APPLE_ASC_KEY_ID:-}" || -n "${APPLE_ASC_ISSUER_ID:-}" ]]; then
    for name in APPLE_ASC_API_KEY_PATH APPLE_ASC_KEY_ID APPLE_ASC_ISSUER_ID; do
      if [[ -z "${!name:-}" ]]; then
        echo "$name is required when using App Store Connect API authentication." >&2
        exit 1
      fi
    done

    if ! APPLE_ASC_API_KEY_PATH="$(absolute_path "$APPLE_ASC_API_KEY_PATH")"; then
      echo "APPLE_ASC_API_KEY_PATH must point to an existing directory: $APPLE_ASC_API_KEY_PATH" >&2
      exit 1
    fi
    if [[ ! -f "$APPLE_ASC_API_KEY_PATH" ]]; then
      echo "APPLE_ASC_API_KEY_PATH must be an absolute path to an existing file: $APPLE_ASC_API_KEY_PATH" >&2
      exit 1
    fi

    XCODE_AUTH_ARGS=(
      -authenticationKeyPath "$APPLE_ASC_API_KEY_PATH"
      -authenticationKeyID "$APPLE_ASC_KEY_ID"
      -authenticationKeyIssuerID "$APPLE_ASC_ISSUER_ID"
    )
  fi
}

decode_provisioning_profile() {
  local profile_path="$1"
  local output_path="$2"

  if security cms -D -i "$profile_path" > "$output_path" 2>/dev/null; then
    return
  fi

  openssl cms -inform DER -verify -noverify -in "$profile_path" > "$output_path"
}

install_manual_provisioning_profile() {
  if [[ "$APPLE_MAS_SIGNING_STYLE" != "manual" || -z "${APPLE_MAS_PROFILE_PATH:-}" ]]; then
    return
  fi

  if ! APPLE_MAS_PROFILE_PATH="$(absolute_path "$APPLE_MAS_PROFILE_PATH")"; then
    echo "APPLE_MAS_PROFILE_PATH must point to an existing directory: $APPLE_MAS_PROFILE_PATH" >&2
    exit 1
  fi
  if [[ ! -f "$APPLE_MAS_PROFILE_PATH" ]]; then
    echo "APPLE_MAS_PROFILE_PATH must point to an existing provisioning profile: $APPLE_MAS_PROFILE_PATH" >&2
    exit 1
  fi

  TEMP_PROFILE_PLIST="$(mktemp)"
  decode_provisioning_profile "$APPLE_MAS_PROFILE_PATH" "$TEMP_PROFILE_PLIST"

  local profile_uuid
  profile_uuid="$(plutil -extract UUID raw -o - "$TEMP_PROFILE_PLIST")"
  if [[ -z "$profile_uuid" ]]; then
    echo "Could not read UUID from APPLE_MAS_PROFILE_PATH: $APPLE_MAS_PROFILE_PATH" >&2
    exit 1
  fi

  local profiles_dir
  profiles_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
  mkdir -p "$profiles_dir"
  cp "$APPLE_MAS_PROFILE_PATH" "$profiles_dir/$profile_uuid.provisionprofile"
}

prepare_signing() {
  APPLE_MAS_SIGNING_STYLE="${APPLE_MAS_SIGNING_STYLE:-automatic}"

  case "$APPLE_MAS_SIGNING_STYLE" in
    automatic|manual)
      ;;
    *)
      echo "APPLE_MAS_SIGNING_STYLE must be automatic or manual." >&2
      exit 1
      ;;
  esac

  if [[ "$APPLE_MAS_SIGNING_STYLE" == "automatic" ]]; then
    return
  fi

  if [[ -z "${APPLE_MAS_APP_CERTIFICATE:-}" && -n "${APPLE_MAS_SIGNING_CERTIFICATE:-}" ]]; then
    APPLE_MAS_APP_CERTIFICATE="$APPLE_MAS_SIGNING_CERTIFICATE"
  fi

  for name in APPLE_MAS_APP_CERTIFICATE APPLE_MAS_INSTALLER_CERTIFICATE APPLE_MAS_PROFILE_NAME; do
    if [[ -z "${!name:-}" ]]; then
      echo "$name is required when APPLE_MAS_SIGNING_STYLE=manual." >&2
      exit 1
    fi
  done

  if [[ -z "$PRODUCT_BUNDLE_IDENTIFIER" ]]; then
    echo "Could not determine PRODUCT_BUNDLE_IDENTIFIER from $APP_INFO_XCCONFIG." >&2
    exit 1
  fi

  install_manual_provisioning_profile
}

write_export_options() {
  local path="$1"
  local destination="$2"

  cat > "$path" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>destination</key>
	<string>$destination</string>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
	<key>method</key>
	<string>app-store-connect</string>
	<key>signingStyle</key>
	<string>$APPLE_MAS_SIGNING_STYLE</string>
	<key>stripSwiftSymbols</key>
	<true/>
EOF

  if [[ -n "${APPLE_TEAM_ID:-}" ]]; then
    cat >> "$path" <<EOF
	<key>teamID</key>
	<string>$APPLE_TEAM_ID</string>
EOF
  fi

  if [[ "$APPLE_MAS_SIGNING_STYLE" == "manual" ]]; then
    cat >> "$path" <<EOF
	<key>installerSigningCertificate</key>
	<string>$APPLE_MAS_INSTALLER_CERTIFICATE</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>$PRODUCT_BUNDLE_IDENTIFIER</key>
		<string>$APPLE_MAS_PROFILE_NAME</string>
	</dict>
	<key>signingCertificate</key>
	<string>$APPLE_MAS_APP_CERTIFICATE</string>
EOF
  fi

  cat >> "$path" <<EOF
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
EOF
}

build_flutter_config() {
  echo "==> Preparing Flutter macOS release config"
  flutter build macos --release --config-only
}

archive_app() {
  echo "==> Archiving Mac App Store app"

  local build_settings=()
  build_settings+=(
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID"
  )

  if [[ "$APPLE_MAS_SIGNING_STYLE" == "manual" ]]; then
    build_settings+=(
      CODE_SIGN_STYLE=Manual
      CODE_SIGN_IDENTITY="$APPLE_MAS_APP_CERTIFICATE"
      PROVISIONING_PROFILE_SPECIFIER="$APPLE_MAS_PROFILE_NAME"
    )
  else
    build_settings+=(
      CODE_SIGN_STYLE=Automatic
    )
  fi

  rm -rf "$ARCHIVE_PATH"
  xcodebuild archive \
    -workspace "$ROOT/macos/Runner.xcworkspace" \
    -scheme Runner \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE_PATH" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -allowProvisioningUpdates \
    "${XCODE_AUTH_ARGS[@]}" \
    "${build_settings[@]}" \
    -quiet
}

export_archive() {
  echo "==> Exporting Mac App Store archive"
  rm -rf "$EXPORT_DIR"
  mkdir -p "$EXPORT_DIR"

  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS_PATH" \
    -exportPath "$EXPORT_DIR" \
    -allowProvisioningUpdates \
    "${XCODE_AUTH_ARGS[@]}" \
    -quiet
}

archive_app_path() {
  find "$ARCHIVE_PATH/Products/Applications" -maxdepth 1 -type d -name '*.app' | sort | head -n 1
}

exported_app_path() {
  find "$EXPORT_DIR" -maxdepth 2 -type d -name '*.app' | sort | head -n 1
}

exported_pkg_path() {
  find "$EXPORT_DIR" -maxdepth 2 -type f -name '*.pkg' | sort | head -n 1
}

write_signing_diagnostics() {
  local app_path="$1"
  local prefix="$2"

  echo "==> Writing signing diagnostics for $prefix"
  codesign -dv "$app_path" > "$DIAGNOSTICS_DIR/${prefix}-codesign.txt" 2>&1 || true
  codesign -d --entitlements :- "$app_path" > "$DIAGNOSTICS_DIR/${prefix}-entitlements.plist" 2> "$DIAGNOSTICS_DIR/${prefix}-entitlements.stderr"
}

verify_mas_entitlements() {
  local entitlements_path="$1"

  if ! grep -q 'com.apple.security.app-sandbox' "$entitlements_path"; then
    echo "Missing App Sandbox entitlement in $entitlements_path" >&2
    exit 1
  fi

  if grep -q 'com.apple.security.get-task-allow' "$entitlements_path"; then
    echo "Found get-task-allow in $entitlements_path; this is not suitable for App Store distribution." >&2
    exit 1
  fi
}

verify_distribution_signature() {
  local codesign_path="$1"

  if grep -q 'Signature=adhoc' "$codesign_path"; then
    echo "Archive was ad-hoc signed. Check APPLE_TEAM_ID and automatic signing credentials." >&2
    exit 1
  fi

  if grep -q 'TeamIdentifier=not set' "$codesign_path"; then
    echo "Archive has no TeamIdentifier. Check APPLE_TEAM_ID and signing credentials." >&2
    exit 1
  fi
}

UPLOAD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --upload)
      UPLOAD=1
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

trap cleanup EXIT

ROOT="$(repo_root)"
PUBSPEC_PATH="$ROOT/pubspec.yaml"
APP_INFO_XCCONFIG="$ROOT/macos/Runner/Configs/AppInfo.xcconfig"

declare -a XCODE_AUTH_ARGS=()
APP_NAME="${APP_NAME:-$(read_product_name "$APP_INFO_XCCONFIG")}"
APP_NAME="${APP_NAME:-OIMG}"
BUILD_NAME="$(read_build_name "$PUBSPEC_PATH")"
BUILD_NAME="${BUILD_NAME:-0.0.0}"
DIST_DIR="${DIST_DIR:-$ROOT/dist/macos-mas}"
ARCHIVE_DIR="$DIST_DIR/archive"
EXPORT_DIR="$DIST_DIR/export"
DIAGNOSTICS_DIR="$DIST_DIR/diagnostics"
DERIVED_DATA_PATH="$ROOT/build/macos-mas"
ARTIFACT_BASENAME="${APP_NAME}-${BUILD_NAME}-mas"
ARCHIVE_PATH="$ARCHIVE_DIR/${ARTIFACT_BASENAME}.xcarchive"
EXPORT_OPTIONS_PATH="$DIST_DIR/ExportOptions-mas.plist"
EXPORT_DESTINATION="export"

if [[ "$UPLOAD" == "1" ]]; then
  EXPORT_DESTINATION="upload"
fi

require_tool flutter
require_tool xcodebuild
require_tool codesign
require_tool find
require_tool grep
require_tool openssl
require_tool plutil

mkdir -p "$ARCHIVE_DIR" "$DIAGNOSTICS_DIR"
require_team_id
PRODUCT_BUNDLE_IDENTIFIER="$(read_bundle_identifier "$APP_INFO_XCCONFIG")"
prepare_signing
prepare_api_key
write_export_options "$EXPORT_OPTIONS_PATH" "$EXPORT_DESTINATION"
plutil -lint "$EXPORT_OPTIONS_PATH" >/dev/null

cd "$ROOT"
build_flutter_config
archive_app

APP_PATH="$(archive_app_path)"
if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Expected archived app not found under $ARCHIVE_PATH/Products/Applications" >&2
  exit 1
fi

write_signing_diagnostics "$APP_PATH" "archive"
verify_distribution_signature "$DIAGNOSTICS_DIR/archive-codesign.txt"
verify_mas_entitlements "$DIAGNOSTICS_DIR/archive-entitlements.plist"
export_archive

EXPORTED_APP_PATH="$(exported_app_path)"
if [[ -n "$EXPORTED_APP_PATH" && -d "$EXPORTED_APP_PATH" ]]; then
  write_signing_diagnostics "$EXPORTED_APP_PATH" "export"
  verify_distribution_signature "$DIAGNOSTICS_DIR/export-codesign.txt"
  verify_mas_entitlements "$DIAGNOSTICS_DIR/export-entitlements.plist"
fi

EXPORTED_PKG_PATH="$(exported_pkg_path)"

echo
echo "Created Mac App Store archive:"
echo "  $ARCHIVE_PATH"
echo "Export output:"
echo "  $EXPORT_DIR"
if [[ -n "$EXPORTED_PKG_PATH" ]]; then
  echo "Exported package:"
  echo "  $EXPORTED_PKG_PATH"
fi
echo "Diagnostics:"
echo "  $DIAGNOSTICS_DIR"
if [[ "$UPLOAD" == "1" ]]; then
  echo "Upload requested through xcodebuild export destination=upload."
else
  echo "Upload was not requested. Use --upload after validating the exported build."
fi
