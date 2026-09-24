#!/usr/bin/env bash
# Smoke checks for crate/pi-image outputs. No root required except loop mounts (uses sfdisk -d).
# Usage: bash test/test-pi-image.sh [--img out.img] [--root /mnt/pi-root]
set -euo pipefail
IMG="${1:-${2:-}}"
for a in "$@"; do case "$a" in --img) shift; IMG="$1";; --root) shift; ROOT="$1";; esac; shift 2>/dev/null || true; done
ROOT="${ROOT:-}"

fail=0
check() { if eval "$1"; then echo "[PASS] $2"; else echo "[FAIL] $2"; fail=1; fi; }

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

check "test -f $REPO/crate/pi-image/assets/pacman.conf" "assets/pacman.conf exists"
check "! grep -q asahi-alarm $REPO/crate/pi-image/assets/pacman.conf" "pacman.conf has no asahi-alarm"
check "! grep -q '^\\[community\\]' $REPO/crate/pi-image/assets/pacman.conf" "pacman.conf has no [community]"
check "! grep -q '^\\[aur\\]' $REPO/crate/pi-image/assets/pacman.conf" "pacman.conf has no [aur]"
check "grep -q '^\\[alarm\\]' $REPO/crate/pi-image/assets/pacman.conf" "pacman.conf has [alarm]"
check "grep -q https:// $REPO/crate/pi-image/assets/mirrorlist" "mirrorlist uses https"
check "test -f $REPO/crate/pi-image/assets/config.txt" "assets/config.txt exists"
check "grep -q vc4-kms-v3d $REPO/crate/pi-image/assets/config.txt" "config.txt enables vc4-kms-v3d"
check "test -f $REPO/crate/pi-image/assets/cmdline.txt" "assets/cmdline.txt exists"
check "! grep -v '^#' $REPO/crate/pi-image/lists/omarchy-pi.packages | grep -q linux-asahi" "pi list has no linux-asahi"
check "grep -q linux-rpi $REPO/crate/pi-image/lists/omarchy-pi.packages || grep -q linux-rpi $REPO/crate/pi-image/lib/kernel-pi.sh" "linux-rpi covered"
check "test -x $REPO/crate/pi-image/build.sh" "build.sh executable"
check "test -f $REPO/crate/Cargo.toml" "crate Cargo.toml exists"
check "test -f $REPO/config/hypr/monitors-pi.conf" "monitors-pi.conf exists"
check "grep -q 'GDK_SCALE,1' $REPO/config/hypr/monitors-pi.conf" "monitors-pi uses SCALE=1"
check "test -f $REPO/default/hypr/looknfeel-pi.conf" "looknfeel-pi.conf exists"
check "! grep -A3 'blur {' $REPO/default/hypr/looknfeel-pi.conf | grep -q 'enabled = true'" "looknfeel-pi has blur disabled"
check "grep -q 'Raspberry Pi detected' $REPO/install/login/all.sh" "login/all.sh gates Pi"
check "grep -q 'Raspberry Pi detected' $REPO/install/login/alt-bootloaders.sh" "alt-bootloaders.sh guards Pi"
check "grep -q 'hardware/pi.sh' $REPO/install/config/all.sh" "config/all.sh hooks pi.sh"
check "test -x $REPO/crate/pi-image/lib/aur-cache.sh" "aur-cache.sh executable"
check "grep -q 'pi-aur' $REPO/crate/pi-image/lib/packages-pi.sh" "packages-pi uses pi-aur cache"
check "grep -q 'AUR_CACHE' $REPO/crate/pi-image/build.sh" "build.sh wires AUR_CACHE"
check "grep -q 'OMARCHY_PI_PLYMOUTH' $REPO/crate/pi-image/lib/boot-pi.sh" "boot-pi has plymouth toggle"
check "grep -q 'quiet splash' $REPO/crate/pi-image/assets/cmdline.txt" "cmdline has quiet splash"
check "! grep -q 'plymouth.enable=0' $REPO/crate/pi-image/assets/cmdline.txt" "cmdline default keeps plymouth enabled"
check "bash -n $REPO/crate/pi-image/lib/aur-cache.sh" "aur-cache.sh syntax OK"
check "grep -q 'aur_cache' $REPO/crate/src/main.rs" "Rust CLI exposes --aur-cache"
check "grep -q 'no_plymouth' $REPO/crate/src/main.rs" "Rust CLI exposes --no-plymouth"
check "grep -q 'aur-cache' $REPO/README.md" "README documents --aur-cache"
check "grep -q 'for f in' $REPO/.github/workflows/pi-image.yml" "CI lints every script"
check "test -x $REPO/test/qemu-smoke.sh" "qemu-smoke.sh executable"
check "grep -q 'qemu-smoke' $REPO/README.md" "README documents qemu-smoke"

if [[ -n "$IMG" ]]; then
  check "test -f $IMG" "img file exists"
  check "sfdisk -d $IMG | grep -q 'type=c\\|type=0c'" "img has FAT BOOT"
  check "sfdisk -d $IMG | grep -q 'type=83'" "img has Linux ROOT"
fi
if [[ -n "$ROOT" ]]; then
  check "! grep -q asahi-alarm $ROOT/etc/pacman.conf 2>/dev/null" "chroot pacman.conf clean"
  check "test -f $ROOT/boot/config.txt" "chroot /boot/config.txt present"
fi

exit $fail
