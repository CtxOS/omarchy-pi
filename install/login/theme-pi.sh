#!/usr/bin/env bash
# Apply Pi-optimized theme on login. Called from install/login/all.sh on Pi.
set -euo pipefail

OMARCHY_PATH="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"

# Copy Pi-specific Hyprland configs
if [[ -f "$OMARCHY_PATH/config/hypr/monitors-pi.conf" ]]; then
  mkdir -p ~/.config/hypr
  cp "$OMARCHY_PATH/config/hypr/monitors-pi.conf" ~/.config/hypr/monitors.conf
fi
if [[ -f "$OMARCHY_PATH/default/hypr/looknfeel-pi.conf" ]]; then
  mkdir -p ~/.config/hypr
  cp "$OMARCHY_PATH/default/hypr/looknfeel-pi.conf" ~/.config/hypr/looknfeel.conf
fi

# Apply Pi theme via omarchy-theme-set if available
if command -v omarchy-theme-set &>/dev/null; then
  omarchy-theme-set --pi
fi

echo "[login] Pi theme applied (SCALE=1, no blur, V3D-friendly)"
