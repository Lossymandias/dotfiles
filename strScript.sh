#!/usr/bin/env bash
spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
set -e

total_steps=11
LOG_FILE="install.log"

# Initialize or clear the log file at the start
echo "=== Installation Started: $(date) ===" > "$LOG_FILE"

run_step() {
    local step_num=$1
    local description=$2
    local cmd=$3

    echo "----------------------------------------" >> "$LOG_FILE"
    echo "Step $step_num/$total_steps: $description" >> "$LOG_FILE"
    echo "----------------------------------------" >> "$LOG_FILE"

    # Execute the command, stream output live to terminal, and capture everything into install.log
    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        echo "[✔] Step $step_num/$total_steps: $description - Done"
    else
        echo "[✖] Step $step_num/$total_steps: $description - Failed"
        echo "Check '$LOG_FILE' for the full error output."
        exit 1
    fi
}

if [ "$EUID" -eq 0 ]; then
    echo "Do not run this script as root. It uses sudo where needed."
    exit 1
fi

# Authenticate sudo upfront so it doesn't interrupt later steps
sudo -v

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------
# 1. System Update & Packages
# ---------------------------------------------------------------
run_step 1 "Updating system packages" "$(cat << 'EOF'
    sudo pacman -Syu --noconfirm
EOF
)"

run_step 2 "Installing core packages and desktop environment" "$(cat << 'EOF'
    sudo pacman -S --needed --noconfirm \
        base-devel git curl \
        hyprland quickshell hyprpaper hyprlauncher hyprlock hyprcursor \
        xdg-desktop-portal-hyprland pipewire wireplumber \
        greetd greetd-tuigreet \
        satty dolphin ark 7zip imv kitty \
        kvantum qt6ct otf-font-awesome ttf-nerd-fonts-symbols pavucontrol \
        ttf-nerd-fonts-symbols-mono ttf-font-awesome \ 
        vim neovim zsh bash code \
        xorg-xcursorgen yarn zip tmux \
        python python-pip python-pillow python-numpy xcur2png
EOF
)"

# ---------------------------------------------------------------
# 2. AUR helper (yay)
# ---------------------------------------------------------------
run_step 3 "Installing yay" "$(cat << 'EOF'
    if ! command -v yay >/dev/null 2>&1; then
        cd ~
        rm -rf ~/yay
        git clone https://aur.archlinux.org/yay.git
        cd ~/yay
        makepkg -si --noconfirm
        cd ~
    fi
EOF
)"

# ---------------------------------------------------------------
# 3. Shell frameworks & Powerlevel10k
# ---------------------------------------------------------------
run_step 4 "Setting up shell frameworks and Powerlevel10k" "$(cat << 'EOF'
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" '' --unattended
    
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" '' --unattended
    fi
    
    yay -S --noconfirm --answerclean None --answerdiff None --overwrite '*' zsh-theme-powerlevel10k-git
    echo 'source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme' >>~/.zshrc
EOF
)"

# ---------------------------------------------------------------
# 4. Layan KDE theme & Tela icons
# ---------------------------------------------------------------
run_step 5 "Installing Layan KDE theme and Tela icons" "$(cat << 'EOF'
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
EOF
)"

# ---------------------------------------------------------------
# 5. Quickshell + hyprpaper configs
# ---------------------------------------------------------------
run_step 6 "Applying Quickshell and Hyprpaper configs" "$(cat << 'EOF'
    mkdir -p ~/.config/quickshell ~/.config/hypr
    mkdir -p ~/Documents/Backgrounds/hyprpaper

    cp -a "$SCRIPT_DIR/DotFiles/quickshell/."       ~/.config/quickshell/.
    cp "$SCRIPT_DIR/DotFiles/hyprpaper/hyprpaper.conf"   ~/.config/hypr/hyprpaper.conf
    cp -r "$SCRIPT_DIR/DotFiles/hyprpaper/Backgrounds/."    ~/Documents/Backgrounds/hyprpaper/
    cp -r "$SCRIPT_DIR/DotFiles/kitty/."    ~/.config/kitty/
EOF
)"

# ---------------------------------------------------------------
# 6. Kvantum theme
# ---------------------------------------------------------------
run_step 7 "Configuring Kvantum theme and environment variables" "$(cat << 'EOF'
    mkdir -p ~/.config/Kvantum

    KV_CONF="$HOME/.config/Kvantum/kvantum.kvconfig"
    if [ ! -f "$KV_CONF" ]; then
        printf '[General]\ntheme=LayanDark\n' > "$KV_CONF"
    elif grep -q '^theme=' "$KV_CONF"; then
        sed -i 's/^theme=.*/theme=LayanDark/' "$KV_CONF"
    elif grep -q '^[General]' "$KV_CONF"; then
        sed -i '/^[General]/a theme=LayanDark' "$KV_CONF"
    else
        printf '[General]\ntheme=LayanDark\n' >> "$KV_CONF"
    fi

    touch ~/.profile
    LINE_STYLE='export QT_STYLE_OVERRIDE=kvantum'
    LINE_PLATFORM='export QT_QPA_PLATFORMTHEME=qt6ct'
    grep -qxF "$LINE_STYLE"    ~/.profile || echo "$LINE_STYLE"    >> ~/.profile
    grep -qxF "$LINE_PLATFORM" ~/.profile || echo "$LINE_PLATFORM" >> ~/.profile
EOF
)"

# ---------------------------------------------------------------
# 7. Dolphin color scheme
# ---------------------------------------------------------------
run_step 8 "Configuring Dolphin color scheme" "$(cat << 'EOF'
    touch ~/.config/dolphinrc
    if ! grep -q '^ColorScheme=Layan' ~/.config/dolphinrc; then
        cat << 'EOF_CONFIG' >> ~/.config/dolphinrc

[UiSettings]
ColorScheme=Layan
EOF_CONFIG
    fi
EOF
)"

# ---------------------------------------------------------------
# 8. Hyprland environment variables (Lua config)
# ---------------------------------------------------------------
run_step 9 "Applying Hyprland environment configuration" "$(cat << 'EOF'
    cp "$SCRIPT_DIR/DotFiles/hyprland/hyprland.lua" ~/.config/hypr/hyprland.lua
EOF
)"

# ---------------------------------------------------------------
# 9. Catppuccin hyprtoolkit theme
# ---------------------------------------------------------------
run_step 10 "Setting up Catppuccin hyprtoolkit theme" "$(cat << 'EOF'
    cd ~
    rm -rf ~/hyprtoolkit
    git clone https://github.com/catppuccin/hyprtoolkit.git

    THEME_FILE="$HOME/hyprtoolkit/themes/macchiato/catppuccin-macchiato-lavender.conf"
    if [ -f "$THEME_FILE" ]; then
        cp "$THEME_FILE" ~/.config/hypr/hyprtoolkit.conf
    else
        echo "WARNING: theme file not found at $THEME_FILE"
        exit 1
    fi
EOF
)"

# ---------------------------------------------------------------
# 10. greetd & NvChad / Bibata
# ---------------------------------------------------------------
run_step 11 "Configuring greetd, NvChad and Bibata cursor theme" "$(cat << 'EOF'
    sudo cp "$SCRIPT_DIR/DotFiles/greetd/config.toml" /etc/greetd/config.toml

    if [ -d ~/.config/nvim ]; then
        mv ~/.config/nvim ~/.config/nvim.bak.$(date +%s)
    fi
    git clone https://github.com/NvChad/starter ~/.config/nvim
    if [ -d "$HOME/.config/nvim" ]; then
        mv ~/.config/nvim ~/.config/nvim-$(date +%Y-%m-%d_%H-%m-%s)
    fi
    cp  -r "$SCRIPT_DIR/DotFiles/nvim" ~/.config/nvim

    cd ~
    yay -S --noconfirm --answerclean None --answerdiff None python-clickgen
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
EOF
)"

echo "All steps completed successfully! Full log saved to install.log"
echo "Launching zsh configuration..."
exec zsh -ic "p10k configure"
chsh -s /usr/bin/zsh