is_pi() { grep -qi raspberry /proc/device-tree/model 2>/dev/null || [[ -n "${OMARCHY_PI_BUILD:-}${OMARCHY_PI:-}" ]]; }

run_logged $OMARCHY_INSTALL/login/plymouth.sh
if is_pi; then
  echo "login: Raspberry Pi detected — skipping limine-snapper (x86_64/UEFI only), using FAT /boot (see crate/pi-image)."
  run_logged $OMARCHY_INSTALL/login/theme-pi.sh
else
  run_logged $OMARCHY_INSTALL/login/limine-snapper.sh
fi
run_logged $OMARCHY_INSTALL/login/enable-mkinitcpio.sh
if is_pi; then
  echo "login: Raspberry Pi detected — skipping alt-bootloaders (systemd-boot/grub/UKI); BOOT/config.txt managed by crate/pi-image."
else
  run_logged $OMARCHY_INSTALL/login/alt-bootloaders.sh
fi
