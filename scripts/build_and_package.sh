#!/usr/bin/env bash
set -euo pipefail

# Workspace layout (CI expects this):
#   $GITHUB_WORKSPACE/
#     mpv-build/        # cloned here
#     out/              # final artifacts (we create)
#
# Produces:
#   out/mpv_<version>_<arch>.deb
#   out/BuildLog.txt
#   out/hashes.txt

ROOT="$(pwd)"
LOG="$ROOT/out/BuildLog.txt"

mkdir -p out
rm -f out/* || true

echo "[*] Cloning mpv-build..."
git clone --depth=1 https://github.com/mpv-player/mpv-build.git
cd mpv-build

echo "[*] Syncing subprojects..."
./update

echo "[*] Applying mpv configure options..."
# Avoid dpkg conflict with Ubuntu's libmpv2 package by not shipping libmpv.so
printf "%s\n" -Dlibmpv=false > mpv_options
# Ensure scripting backend is built (OSC + stats use Lua scripts)
printf "%s\n" -Dlua=luajit >> mpv_options

# Ensure the OSC/stats and extra Lua tools are installed into the .deb
# (Debian packaging in mpv-build doesn't install these by default.)
mkdir -p debian
cat > debian/mpv.install <<'EOF'
mpv/player/lua/*.lua usr/share/mpv/scripts/
mpv/TOOLS/lua/*      usr/share/mpv/scripts/
EOF

# Optional: ffmpeg encoders (uncomment if you want these)
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
CORES=$(nproc || echo 2)
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

# Extract Debian version (may include epoch, e.g. 2:2025.09.30.x)
VERSION="$(dpkg-parsechangelog -S Version -l mpv-build/debian/changelog)"

# Create a filesystem/tag-safe variant (GitHub disallows ':' etc.)
# Replace any char not in [A-Za-z0-9._-] with '-' and collapse runs.
VERSION_SAFE="$(printf '%s' "$VERSION" | tr -c 'A-Za-z0-9._-' '-' | tr -s '-')"
# Trim leading/trailing '-'
VERSION_SAFE="${VERSION_SAFE##-}"; VERSION_SAFE="${VERSION_SAFE%%-}"

echo "[*] Built package: $DEB (version $VERSION, arch $ARCH)"
mv "$DEB" out/

# Emit outputs for the workflow
{
  echo "VERSION=$VERSION"
  echo "VERSION_SAFE=$VERSION_SAFE"
  echo "ARCH=$ARCH"
  echo "DEB=out/$DEB"
} >> "$GITHUB_OUTPUT"
