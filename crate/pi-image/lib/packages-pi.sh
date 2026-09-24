#!/usr/bin/env bash
# Install Pi package set inside chroot $ROOT. Skips OPTIONAL: unless ALLOW_AUR=1.
# Usage: ROOT=/mnt/pi-root ALLOW_AUR=0 packages-pi.sh
set -euo pipefail
: "${ROOT:?set ROOT}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE="$SCRIPT_DIR/lists/omarchy-pi.packages"
AUR_OPT="$SCRIPT_DIR/lists/omarchy-pi-aur-optional.packages"
ALLOW_AUR="${ALLOW_AUR:-0}"

pkgs=()
while IFS= read -r line; do
  line="${line%%#*}"; line="$(echo "$line" | xargs || true)"
  [[ -z "$line" ]] && continue
  [[ "$line" == OPTIONAL:* ]] && continue
  pkgs+=("$line")
done < "$BASE"

arch-chroot "$ROOT" pacman -S --noconfirm --needed "${pkgs[@]}"

# Swap warning: compiling AUR on 1-2GB Pi can OOM — prefer AUR_CACHE repo (see lib/aur-cache.sh).
if free -m 2>/dev/null | awk '/^Mem:/{exit !($2<2048)}'; then
  echo "[WARN] <2GB RAM detected: AUR source builds may OOM. Build cache first: AUR_CACHE=/var/cache/omarchy-pi-aur bash crate/pi-image/lib/aur-cache.sh --build" >&2
fi

if [[ "$ALLOW_AUR" == "1" ]]; then
  aur_pkgs=()
  while IFS= read -r line; do
    line="${line%%#*}"; line="$(echo "$line" | xargs || true)"
    [[ -z "$line" ]] && continue
    if [[ "$line" == OPTIONAL:* ]]; then
      aur_pkgs+=("${line#OPTIONAL:}")
    fi
  done < "$AUR_OPT"
  [[ ${#aur_pkgs[@]} -gt 0 ]] || { echo "[OK] no AUR-optional packages listed"; exit 0; }
  AUR_CACHE="${AUR_CACHE:-}"
  # Fast path: prebuilt repo from aur-cache.sh — no compiling on target Pi.
  if [[ -n "$AUR_CACHE" && -f "$AUR_CACHE/pi-aur.db.tar.gz" ]]; then
    echo "[INFO] installing AUR set from binary cache $AUR_CACHE (no on-device compile)"
    sudo mkdir -p "$ROOT/var/cache/omarchy-pi-aur"
    sudo cp "$AUR_CACHE"/*.pkg.tar.zst "$ROOT/var/cache/omarchy-pi-aur/" 2>/dev/null || true
    # Register repo inside chroot (idempotent append)
    if ! grep -q "^\[pi-aur\]" "$ROOT/etc/pacman.conf"; then
      printf '\n[pi-aur]\nSigLevel = Optional TrustAll\nServer = file:///var/cache/omarchy-pi-aur\n' | sudo tee -a "$ROOT/etc/pacman.conf" > /dev/null
    fi
    arch-chroot "$ROOT" pacman -Sy --noconfirm
    # Install only what the cache actually has; report the rest as skipped (needs porting to aarch64)
    have=()
    missing=()
    for p in "${aur_pkgs[@]}"; do
      if compgen -G "$AUR_CACHE/$p-*.pkg.tar.zst" > /dev/null; then have+=("$p"); else missing+=("$p"); fi
    done
    [[ ${#have[@]} -gt 0 ]] && arch-chroot "$ROOT" pacman -S --noconfirm --needed "${have[@]}"
    [[ ${#missing[@]} -gt 0 ]] && echo "[WARN] not in cache (likely no aarch64 port), skipped: ${missing[*]}" >&2
    echo "[OK] AUR-cache install done (from-cache=${have[*]:-none})"
    exit 0
  fi
  # Slow path: compile on device via yay-bin (needs swap on small Pi)
  arch-chroot "$ROOT" bash -c "
    set -e
    if ! command -v yay >/dev/null; then
      useradd -m aurbuild 2>/dev/null || true
      echo 'aurbuild ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/aurbuild
      sudo -u aurbuild bash -c 'cd /tmp && rm -rf yay-bin && git clone https://aur.archlinux.org/yay-bin.git && cd yay-bin && makepkg -si --noconfirm'
    fi
    sudo -u aurbuild yay -S --noconfirm --needed ${aur_pkgs[*]:-}
  "
else
  echo "[INFO] Skipped AUR-optional list (ALLOW_AUR=0). See lists/omarchy-pi-aur-optional.packages"
fi
echo "[OK] Pi base packages installed"
