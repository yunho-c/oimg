#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

note() {
  printf '%s\n' "$*" >&2
}

require_file() {
  local path="$1"
  local message="$2"

  [[ -f "$path" ]] || die "$message"
}

if command -v fvm >/dev/null 2>&1; then
  flutter_cmd=(fvm flutter)
  dart_cmd=(fvm dart)
elif command -v flutter >/dev/null 2>&1 && command -v dart >/dev/null 2>&1; then
  flutter_cmd=(flutter)
  dart_cmd=(dart)
else
  die "missing Flutter/Dart; install Flutter or FVM"
fi

detect_debian_arch() {
  if command -v dpkg >/dev/null 2>&1; then
    dpkg --print-architecture
    return
  fi

  case "$(uname -m)" in
    x86_64) printf 'amd64\n' ;;
    aarch64 | arm64) printf 'arm64\n' ;;
    *) die "cannot detect Debian architecture; install dpkg or run on amd64/arm64" ;;
  esac
}

flutter_arch_for_debian_arch() {
  case "$1" in
    amd64) printf 'x64\n' ;;
    arm64) printf 'arm64\n' ;;
    *) die "unsupported Debian architecture for local packaging: $1" ;;
  esac
}

render_template() {
  local input="$1"
  local output="$2"

  sed \
    -e "s/@VERSION@/$version/g" \
    -e "s/@DEBIAN_ARCH@/$debian_arch/g" \
    -e "s/@FLUTTER_ARCH@/$flutter_arch/g" \
    -e "s/@DEPENDS@/$runtime_depends/g" \
    "$input" >"$output"
}

patch_deb_control_depends() {
  local deb_path="$1"
  local tmp_dir root_dir control_file

  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/oimg-deb.XXXXXX")"
  root_dir="$tmp_dir/root"

  dpkg-deb -R "$deb_path" "$root_dir"
  control_file="$root_dir/DEBIAN/control"
  require_file "$control_file" "missing DEBIAN/control in $deb_path"

  awk -v depends="$runtime_depends" '
    /^Depends:/ {
      print "Depends: " depends
      found = 1
      next
    }
    { print }
    END {
      if (!found) {
        print "Depends: " depends
      }
    }
  ' "$control_file" >"$control_file.tmp"
  mv "$control_file.tmp" "$control_file"

  dpkg-deb --build "$root_dir" "$deb_path" >/dev/null
  rm -rf "$tmp_dir"
}

cd "$repo_root"

require_file "$repo_root/pubspec.yaml" "run this script from the oimg checkout"
require_file "$repo_root/debian/debian.yaml.in" "missing debian/debian.yaml.in"
require_file "$repo_root/debian/gui/oimg.desktop.in" "missing debian/gui/oimg.desktop.in"
require_file "$repo_root/assets/icon/icon-256.png" "missing assets/icon/icon-256.png"

version="$(awk '/^version:/ { print $2; exit }' pubspec.yaml)"
[[ -n "$version" ]] || die "could not read version from pubspec.yaml"

runtime_depends="libgtk-3-0, libstdc++6, libc6, libglib2.0-0, libx11-6, libblkid1, liblzma5"
debian_arch="$(detect_debian_arch)"
flutter_arch="$(flutter_arch_for_debian_arch "$debian_arch")"
bundle_dir="$repo_root/build/linux/$flutter_arch/release/bundle"
deb_path="$repo_root/debian/packages/oimg_${version}_${debian_arch}.deb"

note "building OIMG Linux release bundle for $debian_arch ($flutter_arch)"
"$repo_root/scripts/linux/build-linux.sh" --release "$@"

require_file "$bundle_dir/oimg" "missing $bundle_dir/oimg after build"

mkdir -p "$repo_root/debian/gui" "$repo_root/debian/packages"
render_template "$repo_root/debian/debian.yaml.in" "$repo_root/debian/debian.yaml"
cp "$repo_root/debian/gui/oimg.desktop.in" "$repo_root/debian/gui/oimg.desktop"
cp "$repo_root/assets/icon/icon-256.png" "$repo_root/debian/gui/oimg.png"

note "creating Debian package"
"${dart_cmd[@]}" run flutter_to_debian build
require_file "$deb_path" "missing $deb_path after flutter_to_debian build"
patch_deb_control_depends "$deb_path"

note "package output:"
find "$repo_root/debian/packages" -maxdepth 1 -type f -name '*.deb' -print | sort
