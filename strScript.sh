#!/usr/bin/env bash
spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
set -e


run_step() {
    local step_num=$1
    local description=$2
    local cmd=$3

    eval "$cmd" > /dev/null 2>&1 &
    local pid=$!

    local i=0
    while kill -0 $pid 2>/dev/null; do
        local char="${spin:i%${#spin}:1}"
        printf "\r\033[K[%s] Step %d/%d: %s..." "$char" "$step_num" "$total_steps" "$description"
        i=$((i + 1))
        sleep 0.1
    done

    wait $pid
    if [ $? -eq 0 ]; then
        printf "\r\033[K[✔] Step %d/%d: %s - Done\n" "$step_num" "$total_steps" "$description"
    else
        printf "\r\033[K[✖] Step %d/%d: %s - Failed\n" "$step_num" "$total_steps" "$description"
        exit 1
    fi
}


if [ "$EUID" -eq 0 ]; then
    echo "Do not run this script as root. It uses sudo where needed."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

yay -S --noconfirm tofi

# ---------------------------------------------------------------
# 3. Shell frameworks
# ---------------------------------------------------------------
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" "" --unattended

if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

yay -S --noconfirm zsh-theme-powerlevel10k-git
echo 'source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme' >>~/.zshrc


# ---------------------------------------------------------------
# 4. Layan KDE theme
# ---------------------------------------------------------------
cd ~
rm -rf ~/Layan-kde
git clone https://github.com/vinceliuice/Layan-kde.git
cd ~/Layan-kde
./install.sh
cd ~


rm -rf /tmp/Tela-icon-theme
git clone --depth 1 https://github.com/vinceliuice/Tela-icon-theme /tmp/Tela-icon-theme
/tmp/Tela-icon-theme/install.sh -c grey

mkdir -p ~/.config/environment.d ~/.config/qt6ct ~/.local/share/icons
sudo chown -R $USER:$USER ~/.config/environment.d
echo "QT_QPA_PLATFORMTHEME=qt6ct" > ~/.config/environment.d/qt.conf

sudo chown -R $USER:$USER ~/.config
rm -f ~/.config/kdeglobals
cp "$SCRIPT_DIR/DotFiles/kdeglobals/kdeglobals" ~/.config/kdeglobals

kwriteconfig6 --file kdeglobals --group Icons --key Theme Tela-grey-dark
kwriteconfig6 --file qt6ct/qt6ct.conf --group Appearance --key icon_theme Tela-grey-dark

rm -f ~/.cache/icon-cache.kcache
kbuildsycoca6 --noincremental

# ---------------------------------------------------------------
# 5. Quickshell + hyprpaper configs
# ---------------------------------------------------------------
mkdir -p ~/.config/quickshell ~/.config/hypr
mkdir -p ~/.config/tofi/
mkdir -p ~/Documents/Backgrounds/hyprpaper

# User-level config (no sudo needed, and survives package updates)
cp "$SCRIPT_DIR/DotFiles/quickshell/shell.qml"       ~/.config/quickshell/shell.qml
cp "$SCRIPT_DIR/DotFiles/tofi/config"                ~/.config/tofi/config
cp "$SCRIPT_DIR/DotFiles/hyprpaper/hyprpaper.conf"   ~/.config/hypr/hyprpaper.conf
cp -r "$SCRIPT_DIR/DotFiles/hyprpaper/Backgrounds/."    ~/Documents/Backgrounds/hyprpaper/

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

cp "$SCRUPT_DIR/DotFiles/hyprland/hyprland.lua" ~/.config/hypr/hyprland.lua

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

sudo cp "$SCRIPT_DIR/DotFiles/greetd/config.toml" /etc/greetd/config.toml

# ---------------------------------------------------------------
# 11. NvChad (back up any existing config first; run `nvim` manually afterwards)
# ---------------------------------------------------------------
if [ -d ~/.config/nvim ]; then
    mv ~/.config/nvim ~/.config/nvim.bak.$(date +%s)
fi
git clone https://github.com/NvChad/starter ~/.config/nvim
if [ -d "$HOME/.config/nvim" ]; then
    mv ~/.config/nvim ~/.config/nvim-$(date +%Y-%m-%d_%H-%m-%s)
fi
cp  -r "$SCRIPT_DIR/DotFiles/nvim" ~/.config/nvim

# ---------------------------------------------------------------
# 12. Bibata hyprcursor theme
# ---------------------------------------------------------------
cd ~

yay -S --noconfirm python-clickgen
rm -rf ~/Bibata-Cursor-hyprcursor
git clone https://github.com/LOSEARDES77/Bibata-Cursor-hyprcursor.git
cd ~/Bibata-Cursor-hyprcursor
yarn install
yarn generate

mkdir -p ~/.local/share/icons

find . -name manifest.hl -not -path "*/node_modules/*" -printf '%h\n' | while read -r dir; do
    cp -r "$dir" ~/.local/share/icons/
done

if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    hyprctl setcursor Bibata-Modern-Classic 24
fi

cd ~


# exec zsh
# p10k configure

echo "Done. Log out or reboot too apply all the changes"
