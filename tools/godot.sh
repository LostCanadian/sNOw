#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
# Keep Godot's editor data and cache writable in isolated cloud tasks.
# Local machines retain their normal Godot locations and template installation.
if [[ "$repo_root" == /workspace/* ]]; then
  export XDG_DATA_HOME="${XDG_DATA_HOME:-/workspace/.snow-tools/data}"
  export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/workspace/.snow-tools/config}"
  export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/workspace/.snow-tools/cache}"
  mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
fi
godot_bin="${SNOW_GODOT_BIN:-godot}"
godot_version="$("$godot_bin" --version)"
if [[ "$godot_version" != 4.6.3.stable.* ]]; then
  echo "Use Godot 4.6.3 stable and matching export templates (found: $godot_version)." >&2
  exit 1
fi
exec "$godot_bin" --path "$repo_root" "$@"
