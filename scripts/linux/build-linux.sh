#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/../.." && pwd)"
deps_root="${OIMG_DEPS_ROOT:-$(cd -- "$repo_root/.." && pwd)}"

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

require_file "$repo_root/pubspec.yaml" "run this script from the oimg checkout"
require_file "$deps_root/irondash/engine_context/dart/pubspec.yaml" \
  "missing $deps_root/irondash/engine_context/dart; clone irondash next to oimg or set OIMG_DEPS_ROOT"
require_file "$deps_root/slimg/crates/slimg-core/Cargo.toml" \
  "missing $deps_root/slimg/crates/slimg-core; clone slimg next to oimg or set OIMG_DEPS_ROOT"
require_file "$deps_root/slimg/crates/slimg-exec/Cargo.toml" \
  "missing $deps_root/slimg/crates/slimg-exec; use the slimg support/oimg branch"
require_file "$deps_root/slimg/crates/libjxl-sys/libjxl/CMakeLists.txt" \
  "missing slimg libjxl submodule; run 'git submodule update --init --recursive' in $deps_root/slimg"
require_file "$deps_root/tjdistler-iqa-fork/Cargo.toml" \
  "missing $deps_root/tjdistler-iqa-fork; clone tjdistler-iqa-fork next to oimg or set OIMG_DEPS_ROOT"

if command -v fvm >/dev/null 2>&1; then
  flutter_cmd=(fvm flutter)
elif command -v flutter >/dev/null 2>&1; then
  flutter_cmd=(flutter)
else
  die "missing Flutter; install Flutter or FVM"
fi

apply_clang_gcc_paths_if_needed() {
  command -v clang++ >/dev/null 2>&1 || return 0
  command -v g++ >/dev/null 2>&1 || return 0
  command -v gcc >/dev/null 2>&1 || return 0

  local tmp_src tmp_bin
  tmp_src="$(mktemp "${TMPDIR:-/tmp}/oimg-clang-check.XXXXXX.cc")"
  tmp_bin="$(mktemp "${TMPDIR:-/tmp}/oimg-clang-check.XXXXXX")"
  printf '#include <type_traits>\nint main() { return std::is_same_v<int, int> ? 0 : 1; }\n' > "$tmp_src"

  if clang++ "$tmp_src" -std=c++17 -o "$tmp_bin" >/dev/null 2>&1; then
    rm -f "$tmp_src" "$tmp_bin"
    return 0
  fi

  rm -f "$tmp_src" "$tmp_bin"

  local gcc_major gcc_target include_dir target_include_dir lib_dir
  gcc_major="$(g++ -dumpfullversion -dumpversion | cut -d. -f1)"
  gcc_target="$(gcc -dumpmachine)"
  include_dir="/usr/include/c++/$gcc_major"
  target_include_dir="/usr/include/$gcc_target/c++/$gcc_major"
  lib_dir="/usr/lib/gcc/$gcc_target/$gcc_major"

  [[ -d "$include_dir" ]] || die "clang++ cannot find C++ headers and $include_dir does not exist"
  [[ -d "$target_include_dir" ]] || die "clang++ cannot find target C++ headers and $target_include_dir does not exist"
  [[ -d "$lib_dir" ]] || die "clang++ cannot find libstdc++ and $lib_dir does not exist"

  export CXXFLAGS="${CXXFLAGS:-} -isystem $include_dir -isystem $target_include_dir"
  export LDFLAGS="${LDFLAGS:-} -L$lib_dir"
  note "using GCC $gcc_major C++ headers/libs for clang++"
}

apply_clang_gcc_paths_if_needed

cd "$repo_root"
exec "${flutter_cmd[@]}" build linux "$@"
