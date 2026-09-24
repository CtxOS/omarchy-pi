echo "Re-enabling mkinitcpio hooks..."

if grep -qi raspberry /proc/device-tree/model 2>/dev/null || [[ -n "${OMARCHY_PI_BUILD:-}${OMARCHY_PI:-}" ]]; then
  echo "enable-mkinitcpio: Raspberry Pi detected — mkinitcpio only, no limine."
  sudo mkinitcpio -P
  exit 0
fi

# Restore the specific mkinitcpio pacman hooks
if [ -f /usr/share/libalpm/hooks/90-mkinitcpio-install.hook.disabled ]; then
  sudo mv /usr/share/libalpm/hooks/90-mkinitcpio-install.hook.disabled /usr/share/libalpm/hooks/90-mkinitcpio-install.hook
fi

if [ -f /usr/share/libalpm/hooks/60-mkinitcpio-remove.hook.disabled ]; then
  sudo mv /usr/share/libalpm/hooks/60-mkinitcpio-remove.hook.disabled /usr/share/libalpm/hooks/60-mkinitcpio-remove.hook
fi

echo "mkinitcpio hooks re-enabled"

if command -v limine &>/dev/null; then
  sudo limine-update
else
  sudo mkinitcpio -P
fi
