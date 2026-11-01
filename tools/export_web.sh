#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$repo_root/build/web"
touch "$repo_root/build/.gdignore"
bash "$repo_root/tools/godot.sh" --headless --editor --import --quit
bash "$repo_root/tools/godot.sh" --headless --export-release Web "$repo_root/build/web/index.html"
