#!/bin/bash
# Pi hardware config — called from install/config/all.sh when Raspberry Pi detected.
# Skips power-profiles-daemon/usb-autosuspend/power-button tweaks harmful on Pi.

is_pi() { grep -qi raspberry /proc/device-tree/model 2>/dev/null; }
is_pi || exit 0

echo "[pi] configuring Raspberry Pi hardware"

# Wireless regdom (default US; override with OMARCHY_WIFI_REGDOM=DE etc.)
REGDOM="${OMARCHY_WIFI_REGDOM:-US}"
if command -v iw >/dev/null; then
  sudo iw reg set "$REGDOM" 2>/dev/null || true
fi
echo "country=$REGDOM" | sudo tee /etc/wpa_supplicant/regdom.conf >/dev/null 2>&1 || true

# Bluetooth + iwd
sudo systemctl enable bluetooth.service 2>/dev/null || true
sudo systemctl enable iwd.service 2>/dev/null || true

# Audio: prefer HDMI/V3D path; don't touch f13-amd/apple quirks
# (pipewire stack already in omarchy-pi.packages)

# Display: Pi 1080p/1440p needs SCALE=1 + V3D-friendly looknfeel (no blur).
# config.sh already copied config/* -> ~/.config; override with Pi variants.
OMARCHY_SRC="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"
if [[ -f "$OMARCHY_SRC/config/hypr/monitors-pi.conf" ]]; then
  mkdir -p ~/.config/hypr
  cp "$OMARCHY_SRC/config/hypr/monitors-pi.conf" ~/.config/hypr/monitors.conf
  echo "[pi] monitors.conf set to 1x Pi defaults"
fi
if [[ -f "$OMARCHY_SRC/default/hypr/looknfeel-pi.conf" ]]; then
  mkdir -p ~/.config/hypr
  cp "$OMARCHY_SRC/default/hypr/looknfeel-pi.conf" ~/.config/hypr/looknfeel.conf
  echo "[pi] looknfeel.conf set to V3D-friendly (no blur)"
fi

# Explicitly do NOT apply on Pi:
# - usb-autosuspend.sh, ignore-power-button.sh, fix-powerprofilesctl-shebang
# - printer/keyboard-backlight/fingerprint (no-op, left to user)
echo "[pi] done (regdom=$REGDOM)"
