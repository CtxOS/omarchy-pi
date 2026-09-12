#!/usr/bin/env bash
# Boot finalization for Pi: ensure BOOT files present, skip limine/grub/efibootmgr.
# Plymouth V3D auto-tune: OMARCHY_PI_PLYMOUTH=0 disables splash (headless/lite);
# default 1 keeps quiet splash on Pi4/5 V3D.
# Usage: ROOT=/mnt/pi-root BOOT_MNT=/mnt/pi-boot OMARCHY_PI_PLYMOUTH=1 boot-pi.sh
set -euo pipefail
: "${ROOT:?set ROOT}"
BOOT_MNT="${BOOT_MNT:-$ROOT/boot}"
PLYMOUTH="${OMARCHY_PI_PLYMOUTH:-1}"

for f in config.txt cmdline.txt kernel8.img; do
  if [[ ! -e "$BOOT_MNT/$f" ]] && [[ ! -e "$ROOT/boot/$f" ]]; then
    echo "[WARN] missing BOOT/$f — kernel-pi.sh may not have run" >&2
  fi
done
# Guard against accidental UEFI bootloader writes on Pi
for bad in /boot/EFI /boot/grub /boot/limine.conf /etc/default/grub; do
  if [[ -e "$ROOT$bad" ]]; then
    echo "[INFO] removing Pi-incompatible bootloader path: $bad"
    sudo rm -rf "$ROOT$bad"
  fi
done
# Plymouth optional on V3D; keep hook but don't fail without GPU
if [[ "$PLYMOUTH" == "0" ]]; then
  echo "[INFO] plymouth disabled (OMARCHY_PI_PLYMOUTH=0): stripping splash, disabling services"
  for c in "$BOOT_MNT/cmdline.txt" "$ROOT/boot/cmdline.txt"; do
    [[ -f "$c" ]] || continue
    sed -i 's/ *quiet//; s/ *splash//' "$c"
    grep -q plymouth.enable=0 "$c" || sed -i 's/$/ plymouth.enable=0/' "$c"
  done
  arch-chroot "$ROOT" systemctl disable omarchy-seamless-login.service plymouth-quit.service 2>/dev/null || true
else
  arch-chroot "$ROOT" systemctl enable omarchy-seamless-login.service 2>/dev/null || true
fi
echo "[OK] boot-pi done (UEFI artifacts stripped, BOOT preserved, plymouth=$PLYMOUTH)"
