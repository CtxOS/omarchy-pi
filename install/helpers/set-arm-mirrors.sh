#!/bin/bash
# Set Arch Linux ARM mirrors for best performance
# Usage: sudo ./set-arm-mirrors.sh [country_code]

MIRRORLIST_FILE="/etc/pacman.d/mirrorlist"
COUNTRY="us"
FORCE=0
BACKUP=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --country) COUNTRY="$2"; shift 2 ;;
    --force) FORCE=1; shift ;;
    --backup) BACKUP=1; shift ;;
    *) shift ;;
  esac
done

# List of some fast Arch Linux ARM mirrors by country
case "$COUNTRY" in
  us)
    MIRROR="Server = https://us.mirror.archlinuxarm.org/$arch/$repo"
    ;;
  de)
    MIRROR="Server = https://de.mirror.archlinuxarm.org/$arch/$repo"
    ;;
  uk)
    MIRROR="Server = https://uk.mirror.archlinuxarm.org/$arch/$repo"
    ;;
  fr)
    MIRROR="Server = https://fr.mirror.archlinuxarm.org/$arch/$repo"
    ;;
  au)
    MIRROR="Server = https://au.mirror.archlinuxarm.org/$arch/$repo"
    ;;
  *)
    MIRROR="Server = https://mirror.archlinuxarm.org/$arch/$repo"
    ;;
esac

if [[ -f "$MIRRORLIST_FILE" && $FORCE -eq 0 && -z "${OMARCHY_FORCE_MIRROR_OVERWRITE:-}" ]]; then
  # Merge behavior: append the ARM mirror Server line only if not already present
  existing=$(grep -E '^\s*Server\s*=' "$MIRRORLIST_FILE" || true)
  if echo "$existing" | grep -F -q "$MIRROR"; then
    echo "[OK] ARM mirror already present in $MIRRORLIST_FILE; not changing file."
  else
    if [[ $BACKUP -eq 1 ]]; then
      sudo cp "$MIRRORLIST_FILE" "$MIRRORLIST_FILE.bak.$(date +%Y%m%d%H%M%S)"
      echo "[INFO] Backed up existing mirrorlist to $MIRRORLIST_FILE.bak.*"
    fi
    echo "$MIRROR" | sudo tee -a "$MIRRORLIST_FILE" > /dev/null
    echo "[OK] Appended ARM mirror to $MIRRORLIST_FILE: $MIRROR"
    echo "Updating package database..."
    sudo pacman -Syy
  fi
else
  # Force overwrite or mirrorlist missing -> write the single ARM server entry
  if [[ -f "$MIRRORLIST_FILE" && $BACKUP -eq 1 ]]; then
    sudo cp "$MIRRORLIST_FILE" "$MIRRORLIST_FILE.bak.$(date +%Y%m%d%H%M%S)"
    echo "[INFO] Backed up existing mirrorlist to $MIRRORLIST_FILE.bak.*"
  fi

  echo "$MIRROR" | sudo tee "$MIRRORLIST_FILE"
  echo "[OK] Set ARM mirror: $MIRROR"

  echo "Updating package database..."
  sudo pacman -Syy
fi
