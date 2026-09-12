#!/usr/bin/env bash
# Build (once, on fast host or native Pi) a local binary pacman repo for AUR-optional
# Pi packages so target Pis never compile. Then install from it in chroot.
#
# Build:  AUR_CACHE=/var/cache/omarchy-pi-aur ALLOW_AUR=1 aur-cache.sh --build
# Install: ROOT=/mnt/pi-root AUR_CACHE=/var/cache/omarchy-pi-aur packages-pi.sh
#   (packages-pi.sh auto-uses $AUR_CACHE/repo if present, else falls back to yay-bin build)
#
# Repo layout: $AUR_CACHE/{*.pkg.tar.zst, pi-aur.db.tar.gz}
# Requires: base-devel, git, yay-bin (bootstrapped as aurbuild), repo-add (pacman), qemu-aarch64-static for x86_64 hosts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUR_OPT="$SCRIPT_DIR/lists/omarchy-pi-aur-optional.packages"
AUR_CACHE="${AUR_CACHE:-/var/cache/omarchy-pi-aur}"
MODE="build"
REPO_NAME="pi-aur"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build) MODE="build"; shift ;;
    --clean) MODE="clean"; shift ;;
    --cache) AUR_CACHE="$2"; shift 2 ;;
    *) echo "Unknown: $1 (usage: aur-cache.sh [--build|--clean] [--cache DIR])" >&2; exit 2 ;;
  esac
done

aur_names() {
  while IFS= read -r line; do
    line="${line%%#*}"; line="$(echo "$line" | xargs || true)"
    [[ -z "$line" ]] && continue
    [[ "$line" == OPTIONAL:* ]] && echo "${line#OPTIONAL:}"
  done < "$AUR_OPT"
}

if [[ "$MODE" == "clean" ]]; then
  rm -rf "$AUR_CACHE"
  echo "[OK] cleaned $AUR_CACHE"
  exit 0
fi

# --- build mode ---
mkdir -p "$AUR_CACHE"
cd "$AUR_CACHE"

if [[ "$(uname -m)" != "aarch64" ]] && ! command -v qemu-aarch64-static >/dev/null; then
  echo "[WARN] cross-building AUR for aarch64 from $(uname -m) without qemu-aarch64-static; makepkg may fail." >&2
fi

# Ensure unprivileged builder (makepkg refuses root)
if [[ "$EUID" -eq 0 ]]; then
  id aurbuild >/dev/null 2>&1 || useradd -m aurbuild
  echo 'aurbuild ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/aurbuild
  chown -R aurbuild:aurbuild "$AUR_CACHE"
  BUILD_USER="aurbuild"
else
  BUILD_USER="$(whoami)"
fi

built=0; skipped=0
while read -r pkg; do
  [[ -z "$pkg" ]] && continue
  if compgen -G "$AUR_CACHE/$pkg-*.pkg.tar.zst" > /dev/null; then
    echo "[SKIP] $pkg already cached"
    skipped=$((skipped+1)); continue
  fi
  echo "[BUILD] $pkg"
  if [[ "$EUID" -eq 0 ]]; then
    sudo -u "$BUILD_USER" env PKG="$pkg" CACHE="$AUR_CACHE" bash -c '
      set -e
      rm -rf "/tmp/aur-build-$PKG" && mkdir -p "/tmp/aur-build-$PKG" && cd "/tmp/aur-build-$PKG"
      git clone --depth 1 "https://aur.archlinux.org/$PKG.git"
      cd "$PKG"
      # Prefer existing -bin; skip source builds with no aarch64 arch (needs porting)
      if [[ -f PKGBUILD ]] && grep -q "arch=.*x86_64" PKGBUILD && ! grep -q "aarch64" PKGBUILD && [[ "$PKG" != *-bin ]]; then
        echo "[SKIP] $PKG has no aarch64 arch (needs porting)" >&2; exit 3
      fi
      makepkg -s --noconfirm --clean
      cp ./*.pkg.tar.zst "$CACHE/"
    ' || { echo "[WARN] $pkg build failed/skipped (see above)"; continue; }
  else
    ( rm -rf "/tmp/aur-build-$pkg" && mkdir -p "/tmp/aur-build-$pkg" && cd "/tmp/aur-build-$pkg" \
      && git clone --depth 1 "https://aur.archlinux.org/$pkg.git" && cd "$pkg" \
      && makepkg -s --noconfirm --clean && cp ./*.pkg.tar.zst "$AUR_CACHE/" ) \
      || { echo "[WARN] $pkg build failed/skipped"; continue; }
  fi
  built=$((built+1))
done < <(aur_names)

# (Re)build repo db
rm -f "$AUR_CACHE/$REPO_NAME.db.tar.gz" "$AUR_CACHE/$REPO_NAME.files.tar.gz"
repo-add "$AUR_CACHE/$REPO_NAME.db.tar.gz" "$AUR_CACHE"/*.pkg.tar.zst 2>/dev/null || echo "[WARN] repo-add: no packages yet"
echo "[OK] AUR cache: built=$built skipped=$skipped dir=$AUR_CACHE"
echo "[INFO] Install in chroot with: ROOT=/mnt/pi-root AUR_CACHE=$AUR_CACHE bash crate/pi-image/lib/packages-pi.sh"
