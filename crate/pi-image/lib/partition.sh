#!/usr/bin/env bash
# Partition + format target for Pi. Supports image file or block device.
# Usage: partition.sh --img out.img --size 8G | --device /dev/sdX
# Output: prints BOOT/ROOT mountpoints when used via build.sh (sets $BOOT_MNT $ROOT_MNT).
set -euo pipefail

IMG=""
DEVICE=""
SIZE="8G"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --img) IMG="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    --size) SIZE="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

if [[ -n "$IMG" ]]; then
  echo "[INFO] Creating image $IMG ($SIZE)"
  truncate -s 0 "$IMG"
  fallocate -l "$SIZE" "$IMG" || truncate -s "$SIZE" "$IMG"
  sfdisk "$IMG" <<'EOF'
label: dos
, 512M, c, *
, +, 83,
EOF
  LOOP="$(sudo losetup -Pf --show "$IMG")"
  echo "$LOOP" > /tmp/omarchy-pi.loop
  BOOT_DEV="${LOOP}p1"
  ROOT_DEV="${LOOP}p2"
  sudo mkfs.vfat -F32 "$BOOT_DEV"
  sudo mkfs.ext4 -F "$ROOT_DEV"
  echo "[OK] image partitioned: $LOOP (p1=FAT BOOT, p2=ext4 ROOT)"
elif [[ -n "$DEVICE" ]]; then
  echo "[WARN] This will wipe $DEVICE. Ctrl-C now to abort (5s)."
  sleep 5
  sudo sfdisk "$DEVICE" <<'EOF'
label: dos
, 512M, c, *
, +, 83,
EOF
  sudo mkfs.vfat -F32 "${DEVICE}1"
  sudo mkfs.ext4 -F "${DEVICE}2"
  echo "[OK] device partitioned: $DEVICE"
else
  echo "Provide --img or --device" >&2; exit 2
fi
