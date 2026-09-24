# Set links for Nautilius action icons
sudo ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-previous-symbolic.svg /usr/share/icons/Yaru/scalable/actions/go-previous-symbolic.svg
sudo ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-next-symbolic.svg /usr/share/icons/Yaru/scalable/actions/go-next-symbolic.svg

# Setup theme links
OMARCHY_PATH="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"
mkdir -p ~/.config/omarchy/themes
for f in "$OMARCHY_PATH"/themes/*; do ln -nfs "$f" ~/.config/omarchy/themes/; done

# Set initial theme — Pi gets the Pi-optimized variant
mkdir -p ~/.config/omarchy/current
if [[ -n "${OMARCHY_PI_BUILD:-}${OMARCHY_PI:-}" ]] || grep -qi raspberry /proc/device-tree/model 2>/dev/null; then
  ln -nsf "$OMARCHY_PATH/themes/pi" ~/.config/omarchy/current/theme
else
  ln -snf ~/.config/omarchy/themes/tokyo-night ~/.config/omarchy/current/theme
fi
ln -snf ~/.config/omarchy/current/theme/backgrounds/1-scenery-pink-lakeside-sunset-lake-landscape-scenic-panorama-7680x3215-144.png ~/.config/omarchy/current/background

# Set specific app links for current theme
ln -snf ~/.config/omarchy/current/theme/neovim.lua ~/.config/nvim/lua/plugins/theme.lua

mkdir -p ~/.config/btop/themes
ln -snf ~/.config/omarchy/current/theme/btop.theme ~/.config/btop/themes/current.theme

mkdir -p ~/.config/mako
ln -snf ~/.config/omarchy/current/theme/mako.ini ~/.config/mako/config

mkdir -p ~/.config/eza
ln -snf ~/.config/omarchy/current/theme/eza.yml ~/.config/eza/theme.yml

# Add managed policy directories for Chromium and Brave for theme changes
sudo mkdir -p /etc/chromium/policies/managed
sudo chmod a+rw /etc/chromium/policies/managed

sudo mkdir -p /etc/brave/policies/managed
sudo chmod a+rw /etc/brave/policies/managed
