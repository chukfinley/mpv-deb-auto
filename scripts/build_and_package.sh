#!/usr/bin/env bash
set -euo pipefail

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
# Ship libmpv (you removed distro libmpv2, so no conflict)
printf "%s\n" -Dlibmpv=true > mpv_options
# Enable scripting backend (needed for osc/stats)
printf "%s\n" -Dlua=luajit >> mpv_options

# ---- Debian packaging tweaks ----
mkdir -p debian

# 1) Install osc.lua + stats.lua + TOOLS lua helpers into system scripts dir
cat > debian/mpv.install <<'EOF'
mpv/player/lua/*.lua usr/share/mpv/scripts/
mpv/TOOLS/lua/*      usr/share/mpv/scripts/
EOF

# 2) System-wide defaults to auto-load osc + stats so users get UI/`i` out of the box
mkdir -p debian/tmp
cat > debian/tmp/mpv.conf <<'EOF'
# Auto-load UI and stats scripts system-wide
script=/usr/share/mpv/scripts/osc.lua
script=/usr/share/mpv/scripts/stats.lua
EOF
# Tell debhelper where to place it
# (we use debian/install to copy our prepared file)
cat > debian/install <<'EOF'
tmp/mpv.conf etc/mpv/
EOF
# ---------------------------------

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

ARCH="$(dpkg --print-architecture)"
DEB="$(ls -1 mpv_*_"$ARCH".deb | head -n1 || true)"
if [[ -z "$DEB" ]]; then
  echo "ERROR: No .deb produced. See $LOG"
  exit 2
fi

VERSION="$(dpkg-parsechangelog -S Version -l mpv-build/debian/changelog)"
VERSION_SAFE="$(printf '%s' "$VERSION" | tr -c 'A-Za-z0-9._-' '-' | tr -s '-')"
VERSION_SAFE="${VERSION_SAFE##-}"; VERSION_SAFE="${VERSION_SAFE%%-}"

echo "[*] Built package: $DEB (version $VERSION, arch $ARCH)"
mv "$DEB" out/

{
  echo "VERSION=$VERSION"
  echo "VERSION_SAFE=$VERSION_SAFE"
  echo "ARCH=$ARCH"
  echo "DEB=out/$DEB"
} >> "$GITHUB_OUTPUT"
