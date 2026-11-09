#!/usr/bin/env bash

set -e

if [ "$EUID" -eq 0 ]; then
    echo "Do not run this script as root. It uses sudo where needed."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------
# 1. System update + packages
# ---------------------------------------------------------------
sudo pacman -Syu --noconfirm

sudo pacman -S --needed --noconfirm \
    base-devel git curl \
    hyprland quickshell hyprpaper hyprlauncher hyprlock hyprcursor \
    xdg-desktop-portal-hyprland pipewire wireplumber \
    greetd greetd-tuigreet \
    satty dolphin ark 7zip imv kitty \
    kvantum qt6ct otf-font-awesome \
    vim neovim zsh bash code \
    xorg-xcursorgen yarn zip tmux \
    python python-pip python-pillow python-numpy xcur2png

# ---------------------------------------------------------------
#
# 2. AUR helper (yay)
# ---------------------------------------------------------------
if ! command -v yay >/dev/null 2>&1; then
    cd ~
    rm -rf ~/yay
    git clone https://aur.archlinux.org/yay.git
    cd ~/yay
    makepkg -si --noconfirm
    cd ~
fi

yay -S tofi


# ---------------------------------------------------------------
# 3. Shell frameworks
# ---------------------------------------------------------------
# --unattended stops the installers from replacing/spawning a new shell mid-script
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" "" --unattended

# Oh My Zsh is required for the powerlevel10k path below
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
fi

yay -S --noconfirm zsh-theme-powerlevel10k-git
echo 'source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme' >>~/.zshrc

exec zsh
p10k configure

# ---------------------------------------------------------------
# 4. Layan KDE theme
# ---------------------------------------------------------------
cd ~
rm -rf ~/Layan-kde
git clone https://github.com/vinceliuice/Layan-kde.git
cd ~/Layan-kde
./install.sh
cd ~

# ---------------------------------------------------------------
# 5. Waybar + hyprpaper configs
# ---------------------------------------------------------------
mkdir -p ~/.config/quickshell ~/.config/hypr
mkdir -p ~/.config/tofi/

# User-level config (no sudo needed, and survives package updates)
cp "$SCRIPT_DIR/quickshell/shell.qml" ~/.config/quickshell/shell.qml
cp "$SCRIPT_DIR/tofi/config" ~/.config/tofi/config
cp "$SCRIPT_DIR/hyprpaper/hyprpaper.conf"      ~/.config/hypr/hyprpaper.conf


# ---------------------------------------------------------------
# 6. Kvantum theme
# ---------------------------------------------------------------
mkdir -p ~/.config/Kvantum

KV_CONF="$HOME/.config/Kvantum/kvantum.kvconfig"
if [ ! -f "$KV_CONF" ]; then
    printf '[General]\ntheme=LayanDark\n' > "$KV_CONF"
elif grep -q '^theme=' "$KV_CONF"; then
    sed -i 's/^theme=.*/theme=LayanDark/' "$KV_CONF"
elif grep -q '^\[General\]' "$KV_CONF"; then
    sed -i '/^\[General\]/a theme=LayanDark' "$KV_CONF"
else
    printf '[General]\ntheme=LayanDark\n' >> "$KV_CONF"
fi

# Fallback for sessions that source ~/.profile
touch ~/.profile
LINE_STYLE='export QT_STYLE_OVERRIDE=kvantum'
LINE_PLATFORM='export QT_QPA_PLATFORMTHEME=qt6ct'
grep -qxF "$LINE_STYLE"    ~/.profile || echo "$LINE_STYLE"    >> ~/.profile
grep -qxF "$LINE_PLATFORM" ~/.profile || echo "$LINE_PLATFORM" >> ~/.profile

# ---------------------------------------------------------------
# 7. Dolphin color scheme
# ---------------------------------------------------------------
touch ~/.config/dolphinrc
if ! grep -q '^ColorScheme=Layan' ~/.config/dolphinrc; then
    cat << 'EOF' >> ~/.config/dolphinrc

[UiSettings]
ColorScheme=Layan
EOF
fi

# ---------------------------------------------------------------
# 8. Hyprland environment variables (Lua config)
# ---------------------------------------------------------------
HYPR_LUA="$HOME/.config/hypr/hyprland.lua"

if [ -f "$HYPR_LUA" ]; then
    if ! grep -q 'QT_STYLE_OVERRIDE' "$HYPR_LUA"; then
        cat << 'EOF' >> "$HYPR_LUA"

-- Qt / Kvantum theming (Dolphin) and cursor
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "kvantum")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
EOF
        echo "Environment configuration added to hyprland.lua"
    else
        echo "hyprland.lua already configured, skipping"
    fi
else
    echo "WARNING: $HYPR_LUA not found. Start Hyprland once to generate it, then re-run this script."
fi

# ---------------------------------------------------------------
# 9. Catppuccin hyprtoolkit theme
# ---------------------------------------------------------------
cd ~
rm -rf ~/hyprtoolkit
git clone https://github.com/catppuccin/hyprtoolkit.git

THEME_FILE="$HOME/hyprtoolkit/themes/macchiato/catppuccin-macchiato-lavender.conf"
if [ -f "$THEME_FILE" ]; then
    cp "$THEME_FILE" ~/.config/hypr/hyprtoolkit.conf
else
    echo "WARNING: theme file not found, check the contents of ~/hyprtoolkit/themes/macchiato/"
fi

# ---------------------------------------------------------------
# 10. greetd (enable only; starting it now would kill your current session)
# ---------------------------------------------------------------
sudo cp "$SCRIPT_DIR/greetd/config.toml" /etc/greetd/config.toml
sudo systemctl enable greetd.service

# ---------------------------------------------------------------
# 11. NvChad (back up any existing config first; run `nvim` manually afterwards)
# ---------------------------------------------------------------
if [ -d ~/.config/nvim ]; then
    mv ~/.config/nvim ~/.config/nvim.bak.$(date +%s)
fi
git clone https://github.com/NvChad/starter ~/.config/nvim

# ---------------------------------------------------------------
# 12. Bibata hyprcursor theme
# ---------------------------------------------------------------
cd ~


yay -S python-clickgen
rm -rf ~/Bibata-Cursor-hyprcursor
git clone https://github.com/LOSEARDES77/Bibata-Cursor-hyprcursor.git
cd ~/Bibata-Cursor-hyprcursor
yarn install
yarn generate

mkdir -p ~/.local/share/icons

# Copy every generated theme directory (identified by its manifest.hl)
find . -name manifest.hl -not -path "*/node_modules/*" -printf '%h\n' | while read -r dir; do
    cp -r "$dir" ~/.local/share/icons/
done

cd ~

# hyprctl only works inside a running Hyprland session; the env vars set in
# hyprland.lua above handle the cursor on the next login.
if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    hyprctl setcursor Bibata-Modern-Classic 24
fi

echo "Done. Log out/reboot to start greetd."
