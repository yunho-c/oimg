#!/usr/bin/env bash
set -euo pipefail

repo_url="https://apt.oimg.org"
keyring_path="/usr/share/keyrings/oimg-archive-keyring.gpg"
source_path="/etc/apt/sources.list.d/oimg.list"

if [[ "$(id -u)" -eq 0 ]]; then
  sudo_cmd=()
else
  sudo_cmd=(sudo)
fi

require_tool() {
  local tool="$1"

  command -v "$tool" >/dev/null 2>&1 || {
    printf 'error: missing required tool: %s\n' "$tool" >&2
    exit 1
  }
}

require_tool curl
require_tool gpg
require_tool tee
require_tool apt-get
require_tool dpkg

arch="$(dpkg --print-architecture)"
if [[ "$arch" != "amd64" ]]; then
  printf 'error: unsupported architecture: %s\n' "$arch" >&2
  exit 1
fi

curl -fsSL "$repo_url/oimg-archive-keyring.gpg" \
  | "${sudo_cmd[@]}" tee "$keyring_path" >/dev/null

printf 'deb [arch=amd64 signed-by=%s] %s stable main\n' "$keyring_path" "$repo_url" \
  | "${sudo_cmd[@]}" tee "$source_path" >/dev/null

"${sudo_cmd[@]}" apt-get update
"${sudo_cmd[@]}" apt-get install -y oimg
