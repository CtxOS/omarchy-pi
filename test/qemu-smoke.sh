#!/usr/bin/env bash
# Static + optional-boot smoke for omarchy-pi images. No Pi hardware needed.
# - Static checks always run (size, partitions, BOOT files when mountable).
# - QEMU boot attempt only with --boot and qemu-system-aarch64 present.
# Usage: bash test/qemu-smoke.sh --img out.img [--boot] [--timeout 60]
set -euo pipefail

IMG=""; BOOT=0; TIMEOUT=60
while [[ $# -gt 0 ]]; do
  case "$1" in
    --img) IMG="$2"; shift 2 ;;
    --boot) BOOT=1; shift ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    *) echo "Unknown: $1 (usage: qemu-smoke.sh --img out.img [--boot])" >&2; exit 2 ;;
  esac
done
[[ -n "$IMG" ]] || { echo "--img required" >&2; exit 2; }
[[ -f "$IMG" ]] || { echo "no such image: $IMG" >&2; exit 2; }

fail=0
pass() { echo "[PASS] $1"; }
failm() { echo "[FAIL] $1"; fail=1; }

# 1. Size + partitions (no root needed)
SIZE=$(stat -c%s "$IMG")
(( SIZE > 512*1024*1024 )) && pass "image size $SIZE > 512M" || failm "image too small: $SIZE"
if command -v sfdisk >/dev/null; then
  sfdisk -d "$IMG" | grep -q 'type=c\|type=0c' && pass "FAT BOOT partition present" || failm "no FAT BOOT partition"
  sfdisk -d "$IMG" | grep -q 'type=83' && pass "Linux ROOT partition present" || failm "no Linux ROOT partition"
else
  echo "[INFO] sfdisk not installed — skipped partition checks"
fi

# 2. BOOT file listing — needs loop mount (root) or mtools/7z; degrade gracefully
list_boot() {
  if [[ "$EUID" -eq 0 ]]; then
    LOOP="$(losetup -Pf --show "$IMG")"
    trap 'losetup -d "$LOOP" 2>/dev/null || true' RETURN
    mkdir -p /tmp/pi-smoke-boot
    mount -o ro "${LOOP}p1" /tmp/pi-smoke-boot
    ls /tmp/pi-smoke-boot
    umount /tmp/pi-smoke-boot
  elif command -v 7z >/dev/null; then
    7z l "$IMG" 2>/dev/null | grep -i -o 'config.txt\|cmdline.txt\|kernel8.img\|*.dtb' | sort -u
  elif command -v mdir >/dev/null; then
    # mtools against image offset: BOOT starts at sector 2048 (dos label from partition.sh)
    mdir -i "$IMG@@1048576" :: 2>/dev/null || return 1
  else
    return 2
  fi
}
if BOOT_LIST="$(list_boot 2>/dev/null)"; then
  echo "$BOOT_LIST" | grep -q config.txt && pass "BOOT/config.txt present" || failm "BOOT/config.txt missing"
  echo "$BOOT_LIST" | grep -q cmdline.txt && pass "BOOT/cmdline.txt present" || failm "BOOT/cmdline.txt missing"
  echo "$BOOT_LIST" | grep -q 'kernel8.img\|\.dtb' && pass "BOOT kernel/dtb present" || echo "[INFO] kernel/dtb not listed (ok if listing truncated)"
else
  rc=$?
  [[ $rc -eq 2 ]] && echo "[INFO] no loop/mtools/7z available — skipped BOOT file contents check" || failm "BOOT listing failed"
fi

# 3. Optional QEMU boot (best-effort; raspi4b machine model varies by QEMU version)
if [[ "$BOOT" == "1" ]]; then
  command -v qemu-system-aarch64 >/dev/null || { echo "[INFO] qemu-system-aarch64 not installed — skipped boot test"; exit $fail; }
  echo "[INFO] attempting QEMU boot (timeout ${TIMEOUT}s, expect UEFI/serial noise, not full desktop)"
  timeout "$TIMEOUT" qemu-system-aarch64 -M raspi4b -m 2048 -nographic \
    -drive "file=$IMG,format=raw,if=sd" -serial mon:stdio \
    -display none 2>&1 | head -n 30 || true
  echo "[INFO] QEMU attempt finished (manual log review needed; exit codes unreliable here)"
fi

exit $fail
