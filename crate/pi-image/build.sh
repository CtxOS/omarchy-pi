#!/usr/bin/env bash
# Orchestrator: partition -> bootstrap -> pacman-pi -> kernel-pi -> packages-pi -> omarchy install -> boot-pi -> firstboot
# Usage: sudo ./build.sh --img out.img --tarball ArchLinuxARM-rpi-aarch64-latest.tar.gz --user pi [--allow-aur] [--country us]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IMG=""; DEVICE=""; SIZE="8G"; TARBALL=""; USER_NAME="pi"; HOSTNAME="omarchy-pi"
COUNTRY="us"; ALLOW_AUR=0; WIFI_SSID=""; WIFI_PSK=""; AUR_CACHE=""; PI_PLYMOUTH=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --img) IMG="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    --size) SIZE="$2"; shift 2 ;;
    --tarball) TARBALL="$2"; shift 2 ;;
    --user) USER_NAME="$2"; shift 2 ;;
    --hostname) HOSTNAME="$2"; shift 2 ;;
    --country) COUNTRY="$2"; shift 2 ;;
    --allow-aur) ALLOW_AUR=1; shift ;;
    --aur-cache) AUR_CACHE="$2"; shift 2 ;;
    --no-plymouth) PI_PLYMOUTH=0; shift ;;
    --wifi-ssid) WIFI_SSID="$2"; shift 2 ;;
    --wifi-psk) WIFI_PSK="$2"; shift 2 ;;
    *) echo "Unknown: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$TARBALL" ]] || { echo "--tarball required" >&2; exit 2; }
[[ -n "$IMG" || -n "$DEVICE" ]] || { echo "--img or --device required" >&2; exit 2; }
if [[ "$(uname -m)" != "aarch64" ]] && ! command -v qemu-aarch64-static >/dev/null; then
  echo "[WARN] cross-build needs qemu-aarch64-static" >&2
fi

# 1. partition
if [[ -n "$IMG" ]]; then
  bash "$SCRIPT_DIR/lib/partition.sh" --img "$IMG" --size "$SIZE"
  LOOP="$(cat /tmp/omarchy-pi.loop)"
  export ROOT_MNT BOOT_MNT
  ROOT_MNT="$(mktemp -d)"; BOOT_MNT="$(mktemp -d)"
  sudo mount "${LOOP}p2" "$ROOT_MNT"
  sudo mount "${LOOP}p1" "$BOOT_MNT"
else
  bash "$SCRIPT_DIR/lib/partition.sh" --device "$DEVICE"
  export ROOT_MNT=/mnt/pi-root BOOT_MNT=/mnt/pi-boot
  sudo mkdir -p "$ROOT_MNT" "$BOOT_MNT"
  sudo mount "${DEVICE}2" "$ROOT_MNT"
  sudo mount "${DEVICE}1" "$BOOT_MNT"
fi
export TARBALL

cleanup() {
  sudo umount -R "$ROOT_MNT" 2>/dev/null || true
  [[ -f /tmp/omarchy-pi.loop ]] && sudo losetup -d "$(cat /tmp/omarchy-pi.loop)" 2>/dev/null || true
}
trap cleanup EXIT

# 2-5. bootstrap + pacman + kernel + packages
bash "$SCRIPT_DIR/lib/bootstrap.sh"
ROOT="$ROOT_MNT" bash "$SCRIPT_DIR/lib/pacman-pi.sh" --root "$ROOT_MNT" --country "$COUNTRY"
sudo cp /usr/bin/qemu-aarch64-static "$ROOT_MNT/usr/bin/" 2>/dev/null || true
sudo mount --bind "$BOOT_MNT" "$ROOT_MNT/boot"
ROOT="$ROOT_MNT" bash "$SCRIPT_DIR/lib/kernel-pi.sh"
ROOT="$ROOT_MNT" ALLOW_AUR="$ALLOW_AUR" AUR_CACHE="$AUR_CACHE" bash "$SCRIPT_DIR/lib/packages-pi.sh"

# 6. Omarchy install in chroot (login bootloader steps self-skip on Pi via OMARCHY_PI_BUILD;
#    see install/login/all.sh + alt-bootloaders.sh Pi guards)
sudo cp -r "$SCRIPT_DIR/../.." "$ROOT_MNT/root/omarchy"
sudo arch-chroot "$ROOT_MNT" bash -c "
  export HOME=/root OMARCHY_PATH=/root/omarchy OMARCHY_INSTALL=/root/omarchy/install
  export OMARCHY_CHROOT_INSTALL=1 OMARCHY_FORCE_MIRROR_OVERWRITE=1 OMARCHY_PI_BUILD=1
  export OMARCHY_WIFI_REGDOM=$COUNTRY
  source \$OMARCHY_INSTALL/helpers/all.sh
  source \$OMARCHY_INSTALL/preflight/all.sh || true
  source \$OMARCHY_INSTALL/packaging/all.sh || true
  source \$OMARCHY_INSTALL/config/all.sh || true
  source \$OMARCHY_INSTALL/login/all.sh || true
"

# 7. firstboot payload
ROOT="$ROOT_MNT" USER_NAME="$USER_NAME" HOSTNAME="$HOSTNAME" WIFI_SSID="$WIFI_SSID" WIFI_PSK="$WIFI_PSK" bash "$SCRIPT_DIR/lib/firstboot.sh"

# 8. boot finalize
ROOT="$ROOT_MNT" BOOT_MNT="$BOOT_MNT" OMARCHY_PI_PLYMOUTH="$PI_PLYMOUTH" bash "$SCRIPT_DIR/lib/boot-pi.sh"

echo "[OK] build complete: ${IMG:-$DEVICE} (user=$USER_NAME host=$HOSTNAME plymouth=$PI_PLYMOUTH aur_cache=${AUR_CACHE:-none})"
