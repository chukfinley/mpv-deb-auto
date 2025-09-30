#!/usr/bin/env bash
set -euo pipefail

# Workspace layout (CI expects this):
#   $GITHUB_WORKSPACE/
#     mpv-build/        # cloned here
#     build/            # temp build dir (created by us)
#     out/              # final artifacts (we create)
#
# Produces:
#   out/mpv_<version>_<arch>.deb
#   out/BuildLog.txt
#   out/hashes.txt

ROOT="$(pwd)"
LOG="$ROOT/out/BuildLog.txt"

mkdir -p out build
rm -f out/* || true

echo "[*] Cloning mpv-build..."
git clone --depth=1 https://github.com/mpv-player/mpv-build.git
cd mpv-build

echo "[*] Syncing subprojects..."
./update

# Optional: ffmpeg extra options (uncomment to enable encoders)
# {
#   printf "%s\n" --enable-libx264
#   printf "%s\n" --enable-libmp3lame
#   printf "%s\n" --enable-libfdk-aac
#   printf "%s\n" --enable-nonfree
# } >> ffmpeg_options

# Record upstream hashes for change detection and release notes
echo "[*] Capturing upstream hashes..."
bash "$ROOT/scripts/get_upstream_hashes.sh" "$ROOT/out/hashes.txt"

echo "[*] Installing packaging helpers..."
sudo apt-get update
sudo apt-get install -y devscripts equivs

echo "[*] Resolving build-deps via mk-build-deps..."
mk-build-deps -s sudo -i

echo "[*] Building Debian package (dpkg-buildpackage)..."
# Use all cores
CORES=$(nproc || echo 2)

# The dpkg-buildpackage invocations and the underlying build can be noisy; capture the log.
# We still echo key milestones to stdout for CI.
{
  echo "===== dpkg-buildpackage starting at $(date -u) ====="
  dpkg-buildpackage -uc -us -b -j"$CORES"
  echo "===== dpkg-buildpackage finished at $(date -u) ====="
} | tee "$LOG"

cd ..

# Determine artifact info
ARCH="$(dpkg --print-architecture)"
DEB="$(ls -1 mpv_*_"$ARCH".deb | head -n1 || true)"

if [[ -z "$DEB" ]]; then
  echo "ERROR: No .deb produced. See $LOG"
  exit 2
fi

# Extract version from the changelog in the source dir
VERSION="$(dpkg-parsechangelog -S Version -l mpv-build/debian/changelog)"

echo "[*] Built package: $DEB (version $VERSION, arch $ARCH)"
mv "$DEB" out/

# Emit small machine-readable summary for the workflow
echo "VERSION=$VERSION" >> "$GITHUB_OUTPUT"
echo "ARCH=$ARCH"       >> "$GITHUB_OUTPUT"
echo "DEB=out/$DEB"     >> "$GITHUB_OUTPUT"
