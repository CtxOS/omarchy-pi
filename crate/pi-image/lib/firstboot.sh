#!/usr/bin/env bash
# First-boot payload: growfs, machine-id, user+wheel+sudo, wifi, ssh keys.
# Called from build.sh after omarchy install step.
# Usage: ROOT=/mnt/pi-root USER_NAME=pi HOSTNAME=omarchy-pi WIFI_SSID= WIFI_PSK= firstboot.sh
set -euo pipefail
: "${ROOT:?set ROOT to chroot dir}"
: "${USER_NAME:?set USER_NAME}"
: "${HOSTNAME:?set HOSTNAME}"

GROWFS="$ROOT/usr/local/sbin/omarchy-pi-firstboot.sh"
SERVICE="$ROOT/etc/systemd/system/omarchy-pi-firstboot.service"
ENV_FILE="$ROOT/etc/omarchy-pi-firstboot.env"
FLAG_FILE="$ROOT/var/lib/omarchy-pi-firstboot"

# Install growfs script
cp "$SCRIPT_DIR/../firstboot/growfs.sh" "$GROWFS"
chmod 755 "$GROWFS"

# Install firstboot service
cp "$SCRIPT_DIR/../firstboot/omarchy-pi-firstboot.service" "$SERVICE"

# Enable firstboot service
arch-chroot "$ROOT" systemctl enable omarchy-pi-firstboot.service || true

# Create flag file so service runs on first boot
mkdir -p "$(dirname "$FLAG_FILE")"
touch "$FLAG_FILE"

# Write environment for growfs
cat <<EOF > "$ENV_FILE"
USER_NAME=$USER_NAME
HOSTNAME=$HOSTNAME
WIFI_SSID=${WIFI_SSID:-}
WIFI_PSK=${WIFI_PSK:-}
EOF

# Set hostname
echo "$HOSTNAME" | tee "$ROOT/etc/hostname" > /dev/null

# Ensure machine-id is set
arch-chroot "$ROOT" systemd-machine-id-setup 2>/dev/null || true

echo "[OK] firstboot configured (user=$USER_NAME host=$HOSTNAME)"
