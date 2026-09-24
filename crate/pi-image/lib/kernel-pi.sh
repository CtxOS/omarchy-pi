#!/usr/bin/env bash
# Swap Asahi/x86 kernel+bootloader for Pi stack inside chroot $ROOT.
# Usage: ROOT=/mnt/pi-root kernel-pi.sh
set -euo pipefail
: "${ROOT:?set ROOT to chroot dir}"

arch-chroot "$ROOT" pacman -Rns --noconfirm \
  linux-asahi linux-asahi-headers asahi-fwextract asahi-desktop-meta \
  grub efibootmgr limine limine-mkinitcpio-hook limine-snapper-sync \
  broadcom-wl nvidia-dkms nvidia-open-dkms nvidia-utils lib32-nvidia-utils \
  libva-intel-driver libva-nvidia-driver macbook12-spi-driver-dkms \
  linux-t2 linux-t2-headers apple-bcm-firmware apple-t2-audio-config t2fanrd tiny-dfr \
  2>/dev/null || true

arch-chroot "$ROOT" pacman -S --noconfirm --needed \
  linux-rpi linux-rpi-headers linux-firmware \
  raspberrypi-bootloader firmware-raspberrypi \
  mkinitcpio dosfstools e2fsprogs \
  bluez bluez-utils wireless-regdb iwd \
  btrfs-progs

# Install Pi boot + mkinitcpio assets (preserve *.dtb, overlays/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOT_DIR="$ROOT/boot"
# When BOOT is a separate FAT mount at build time, $ROOT/boot may be empty mountpoint;
# caller bind-mounts BOOT_MNT there before invoking. Only copy config files, never delete *.dtb.
cp "$SCRIPT_DIR/assets/config.txt" "$BOOT_DIR/config.txt"
cp "$SCRIPT_DIR/assets/cmdline.txt" "$BOOT_DIR/cmdline.txt"
mkdir -p "$ROOT/etc/mkinitcpio.conf.d"
cp "$SCRIPT_DIR/assets/mkinitcpio.conf.d-pi.conf" "$ROOT/etc/mkinitcpio.conf.d/pi.conf"
arch-chroot "$ROOT" mkinitcpio -P
echo "[OK] Pi kernel stack installed; BOOT preserved: $(ls "$BOOT_DIR" | head -8 | tr '\n' ' ')"
