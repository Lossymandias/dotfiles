# Dotfiles

Config files and a single setup script for my Arch Linux desktop.

![desktop image](https://github.com/Lossymandias/dotfiles/docs/images/imgScreen.png)

## Environment

| Component | Choice |
|---|---|
| OS | Arch Linux |
| WM | Hyprland |
| Terminal emulator | Kitty |
| Text editor | Neovim (NvChad) |
| Greeter | greetd (tuigreet) |
| Bar | Quickshell |
| Launcher | tofi |
| Wallpaper | hyprpaper |
| File manager | Dolphin |
| Qt theme | Kvantum (Layan Dark) |
| Icons | Tela (grey, dark) |
| Cursor | Bibata Modern Classic (hyprcursor) |

## Repository structure

```
.
├── strScript.sh
└── DotFiles/
    ├── kdeglobals/kdeglobals
    ├── quickshell/shell.qml
    ├── tofi/config
    ├── hyprpaper/
    │   ├── hyprpaper.conf
    │   └── Backgrounds/
    ├── greetd/config.toml
    └── nvim/
```

## Installation

Clone the repo and run the script as a normal user (not root). It calls `sudo` only where needed.

```bash
git clone <repo-url> ~/dotfiles
cd ~/dotfiles
chmod +x strScript.sh
./strScript.sh
```

Reboot when it finishes.

## What the script does

1. **Packages:** updates the system and installs Hyprland, Quickshell, hyprpaper, hyprlock, greetd, Dolphin, Kitty, Neovim, Kvantum, qt6ct, Python tooling and other dependencies with `pacman`.
2. **AUR helper:** installs `yay` if missing, then installs `tofi`.
3. **Shell frameworks:** installs Oh My Bash, Oh My Zsh and Powerlevel10k.
4. **Layan KDE theme:** clones and installs Layan-kde.
5. **Tela icons:** installs the grey variant and sets `Tela-grey-dark` in `kdeglobals` and `qt6ct.conf`, then clears the icon cache.
6. **Configs:** copies the Quickshell, tofi and hyprpaper configs and the wallpapers into place.
7. **Kvantum:** sets the `LayanDark` theme and exports `QT_STYLE_OVERRIDE` and `QT_QPA_PLATFORMTHEME` in `~/.profile`.
8. **Dolphin:** sets the `Layan` color scheme in `dolphinrc`.
9. **Hyprland environment:** appends the Qt and cursor environment variables to `~/.config/hypr/hyprland.lua`.
10. **Catppuccin hyprtoolkit:** installs the Macchiato Lavender theme to `~/.config/hypr/hyprtoolkit.conf`.
11. **greetd:** installs `config.toml` and enables the service. It is not started, so your current session stays alive.
12. **NvChad:** backs up any existing `~/.config/nvim` and installs the Neovim config from `DotFiles/nvim`.
13. **Bibata cursor:** builds the hyprcursor theme and installs it to `~/.local/share/icons`.

## Notes

- Start Hyprland once before running the script so `~/.config/hypr/hyprland.lua` exists. Otherwise the environment variables step is skipped with a warning.
- Existing `~/.config/kdeglobals` is overwritten with the one in `DotFiles/kdeglobals/`. Edit the dotfile in the repo if you want to change the icon theme.
- Existing `~/.config/nvim` is moved to `~/.config/nvim.bak.<timestamp>`.
- Run `p10k configure` after the first launch of zsh to set up the prompt.

## Troubleshooting

**Icons look mixed or did not change**

```bash
grep -A1 '\[Icons\]' ~/.config/kdeglobals
grep icon_theme ~/.config/qt6ct/qt6ct.conf
rm -f ~/.cache/icon-cache.kcache && kbuildsycoca6 --noincremental
pkill -x dolphin
```

Both files must name the same theme.

**Permission denied on files in `~/.config`**

Something was created as root by an earlier `sudo` command:

```bash
sudo chown -R $USER:$USER ~/.config ~/.cache ~/.local/share/icons
```