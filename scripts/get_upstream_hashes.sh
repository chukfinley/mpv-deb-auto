#!/usr/bin/env bash
set -euo pipefail

# Run from the mpv-build working directory (the one that contains ./mpv ./ffmpeg ./libass ./libplacebo)
# Outputs a "hashes.txt" file at the path passed as $1 (defaults to ./hashes.txt).

out="${1:-hashes.txt}"
: > "$out"

for d in mpv ffmpeg libass libplacebo; do
  if [[ -d "$d/.git" ]]; then
    pushd "$d" >/dev/null
    h=$(git rev-parse HEAD)
    url=$(git remote get-url origin || echo "unknown")
    # Write directly to the absolute/relative 'out' path (DON'T prefix with ../)
    echo "$d:$h:$url" | tee -a "$out"
    popd >/dev/null
  else
    echo "$d:missing:missing" | tee -a "$out"
  fi
done
