#!/usr/bin/env bash
# Install Pi-clean pacman.conf + mirrorlist inside $ROOT (chroot dir) or / when ROOT unset.
# Usage: pacman-pi.sh [--root /] [--country us] [--backup]
set -euo pipefail

ROOT="${ROOT:-/}"
COUNTRY="us"
BACKUP=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT="$2"; shift 2 ;;
    --country) COUNTRY="$2"; shift 2 ;;
    --backup) BACKUP=1; shift ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

PACMAN_CONF="$ROOT/etc/pacman.conf"
MIRRORLIST="$ROOT/etc/pacman.d/mirrorlist"
SRC_CONF="$SCRIPT_DIR/assets/pacman.conf"
SRC_MIRROR="$SCRIPT_DIR/assets/mirrorlist"

mkdir -p "$(dirname "$PACMAN_CONF")" "$(dirname "$MIRRORLIST")"

# 1. pacman.conf — always install Pi version (drop asahi-alarm/community/aur/arch-mact2/omarchy)
if [[ -f "$PACMAN_CONF" ]] && [[ $BACKUP -eq 1 ]]; then
  cp "$PACMAN_CONF" "$PACMAN_CONF.bak.$(date +%Y%m%d%H%M%S)"
fi
cp "$SRC_CONF" "$PACMAN_CONF"
echo "[OK] Installed Pi pacman.conf -> $PACMAN_CONF"

# 2. mirrorlist — fresh https ALARM list (country first if requested)
if [[ -f "$MIRRORLIST" ]] && [[ $BACKUP -eq 1 ]]; then
  cp "$MIRRORLIST" "$MIRRORLIST.bak.$(date +%Y%m%d%H%M%S)"
fi
{
  case "$COUNTRY" in
    us|ca|de|uk|fr|au) echo "Server = https://$COUNTRY.mirror.archlinuxarm.org/\$arch/\$repo" ;;
  esac
  grep -v "^Server = https://$COUNTRY" "$SRC_MIRROR" || true
} > "$MIRRORLIST"
echo "[OK] Installed Pi mirrorlist -> $MIRRORLIST (country=$COUNTRY)"

# 3. Strip stale repo includes if any chroot pacman.conf fragment survived (defensive)
for bad in asahi-alarm community aur arch-mact2 omarchy; do
  if grep -q "^\[$bad\]" "$PACMAN_CONF"; then
    echo "[WARN] stale repo [$bad] still present — refusing to continue" >&2
    exit 1
  fi
done

# 4. Keyring + sync only when operating on live root
if [[ "$ROOT" == "/" ]]; then
  sudo pacman-key --init || true
  sudo pacman-key --populate archlinuxarm
  sudo pacman -Syy
else
  echo "[INFO] chroot mode: run 'pacman-key --init --populate archlinuxarm && pacman -Syy' inside chroot."
fi
