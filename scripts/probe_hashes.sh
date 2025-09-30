#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
mkdir -p out
rm -f out/hashes.txt || true

# fresh probe clone
rm -rf mpv-build
git clone --depth=1 https://github.com/mpv-player/mpv-build.git
cd mpv-build

# Fetch upstream source repos & submodules
./update

# Record hashes to the repo's ./out/hashes.txt
bash "$ROOT/scripts/get_upstream_hashes.sh" "$ROOT/out/hashes.txt"
