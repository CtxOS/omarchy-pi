#!/usr/bin/env bash
# Untar ArchLinuxARM rpi tarball into $ROOT_MNT, move /boot/* to BOOT_MNT.
# Usage: ROOT_MNT=/mnt/pi-root BOOT_MNT=/mnt/pi-boot TARBALL=ArchLinuxARM-rpi-aarch64-latest.tar.gz bootstrap.sh
set -euo pipefail

: "${ROOT_MNT:?set ROOT_MNT}"
: "${BOOT_MNT:?set BOOT_MNT}"
: "${TARBALL:?set TARBALL path to ArchLinuxARM-rpi-aarch64-latest.tar.gz}"

mkdir -p "$ROOT_MNT" "$BOOT_MNT"
echo "[INFO] Extracting $TARBALL -> $ROOT_MNT"
sudo bsdtar -xpf "$TARBALL" -C "$ROOT_MNT"
# ALARM tarball ships /boot contents inside root fs — move to FAT partition
sudo mkdir -p "$BOOT_MNT"
if compgen -G "$ROOT_MNT/boot/*" > /dev/null; then
  sudo mv "$ROOT_MNT"/boot/* "$BOOT_MNT"/
fi
sudo mkdir -p "$ROOT_MNT/boot"
echo "$BOOT_MNT /boot vfat defaults 0 2" | sudo tee -a "$ROOT_MNT/etc/fstab" > /dev/null || true
echo "[OK] bootstrap done. BOOT=$(ls "$BOOT_MNT" | head -5 | tr '\n' ' ')"
