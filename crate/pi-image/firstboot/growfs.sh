#!/usr/bin/env bash
# First-boot: grow rootfs, machine-id, user creation.
# Config via /etc/omarchy-pi-firstboot.env (USER, HOSTNAME, WIFI_SSID, WIFI_PSK, REGDOM)
set -euo pipefail
ENV="${ENV:-/etc/omarchy-pi-firstboot.env}"
[[ -f "$ENV" ]] && source "$ENV"

# Grow FS (ext4 root on p2)
ROOT_DEV="$(findmnt -n -o SOURCE / || true)"
if command -v growpart >/dev/null && [[ -n "$ROOT_DEV" ]]; then
  DISK="$(echo "$ROOT_DEV" | sed 's/p\?[0-9]*$//')"
  PART="$(echo "$ROOT_DEV" | grep -o 'p\?[0-9]*$' | sed 's/^p//')"
  growpart "$DISK" "$PART" || true
  resize2fs "$ROOT_DEV" || true
fi

systemd-machine-id-setup 2>/dev/null || true

USER_NAME="${USER_NAME:-pi}"
if ! id "$USER_NAME" >/dev/null 2>&1; then
  useradd -m -G wheel,audio,video "$USER_NAME"
  echo "$USER_NAME:${PASSWORD:-omarchy}" | chpasswd
  echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
fi

HOST="${HOSTNAME:-omarchy-pi}"
echo "$HOST" > /etc/hostname

if [[ -n "${WIFI_SSID:-}" ]] && command -v nmcli >/dev/null; then
  nmcli dev wifi connect "$WIFI_SSID" password "${WIFI_PSK:-}" || true
fi
echo "[OK] omarchy-pi firstboot done"
