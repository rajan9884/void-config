#!/usr/bin/env bash
#
# void-config installer — reproduce this Sway desktop on a fresh Void Linux.
#
# Usage:
#   git clone https://github.com/rajan9884/void-config.git ~/void-config
#   cd ~/void-config
#   ./install.sh [options]
#
# Options:
#   --packages-only   install XBPS packages and enable services, skip dotfile links
#   --links-only      only (re)create ~/.config ~/ ~/.local/bin symlinks
#   --no-fonts        skip the Nerd Font download step
#   --no-wallpapers   skip the wallpaper collection download step
#   -h, --help        show this help and exit
#
# The script is idempotent: re-running it repairs missing links/packages.
# Existing files that would be replaced are backed up to
# ~/.config-backup-void-<timestamp>/ first.

set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_FILE="$REPO_DIR/packages.txt"
BACKUP_DIR="$HOME/.config-backup-void-$(date +%Y%m%d-%H%M%S)"

DO_PACKAGES=1
DO_LINKS=1
DO_FONTS=1
DO_WALLPAPERS=1

for arg in "$@"; do
    case "$arg" in
        --packages-only) DO_LINKS=0 ;;
        --links-only) DO_PACKAGES=0; DO_FONTS=0; DO_WALLPAPERS=0 ;;
        --no-fonts) DO_FONTS=0 ;;
        --no-wallpapers) DO_WALLPAPERS=0 ;;
        -h|--help)
            sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "Unknown option: $arg (see --help)" >&2; exit 1 ;;
    esac
done

log()  { printf '[install] %s\n' "$*"; }
warn() { printf '[install] WARNING: %s\n' "$*" >&2; }

# ---------------------------------------------------------------- guards ---
if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
fi
if [ "${ID:-}" != "void" ] && [ ! -f /etc/void-release ]; then
    echo "This installer targets Void Linux (not detected via /etc/os-release)." >&2
    exit 1
fi

if [ "$(id -u)" -eq 0 ]; then
    echo "Run as your normal user (with sudo/doas rights), not as root." >&2
    exit 1
fi

if [ "$DO_PACKAGES" -eq 1 ]; then
    if command -v sudo >/dev/null 2>&1; then
        PRIV="sudo"
    elif command -v doas >/dev/null 2>&1; then
        PRIV="doas"
    else
        echo "Neither sudo nor doas found; install opendoas or sudo first." >&2
        exit 1
    fi
    log "Privilege escalation: $PRIV (credentials will be requested once)"
    if ! "$PRIV" -n true 2>/dev/null; then
        if [ -n "${SUDO_ASKPASS:-}" ]; then
            "$PRIV" -A -v
        else
            "$PRIV" -v
        fi
    fi
fi

# --------------------------------------------------------------- packages ---
if [ "$DO_PACKAGES" -eq 1 ]; then
    if [ ! -f "$PACKAGES_FILE" ]; then
        echo "Package list missing: $PACKAGES_FILE" >&2
        exit 1
    fi
    log "Syncing repositories and installing $(grep -c . "$PACKAGES_FILE") packages (this takes a while)"
    # shellcheck disable=SC2046
    "$PRIV" xbps-install -Syu $(grep -v '^[[:space:]]*#' "$PACKAGES_FILE" | grep -v '^[[:space:]]*$' | tr '\n' ' ')

    log "Enabling services"
    for svc in NetworkManager bluetoothd chronyd cronie dbus greetd polkitd \
               power-profiles-daemon rtkit ufw; do
        if [ -d "/etc/sv/$svc" ] && [ ! -e "/var/service/$svc" ]; then
            "$PRIV" ln -s "/etc/sv/$svc" /var/service/
            log "  enabled $svc"
        fi
    done
    # warp-svc only exists when cloudflare-warp was installed separately (see README)
    if [ -d /etc/sv/warp-svc ] && [ ! -e /var/service/warp-svc ]; then
        "$PRIV" ln -s /etc/sv/warp-svc /var/service/
        log "  enabled warp-svc"
    fi

    log "Configuring greetd + wheel sudo"
    if command -v tuigreet >/dev/null 2>&1; then
        "$PRIV" mkdir -p /etc/greetd
        "$PRIV" tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 7
[default_session]
command = "tuigreet --time --remember --remember-user-session --sessions /usr/share/wayland-sessions --theme border=blue;text=white;prompt=green;time=gray;action=cyan;button=yellow;container=black;input=red"
user = "_greeter"
EOF
    else
        warn "tuigreet not installed; skipping /etc/greetd/config.toml"
    fi
    if [ ! -f /etc/sudoers.d/wheel ]; then
        echo '%wheel ALL=(ALL:ALL) ALL' | "$PRIV" tee /etc/sudoers.d/wheel >/dev/null
        "$PRIV" chmod 440 /etc/sudoers.d/wheel
    fi
    "$PRIV" visudo -c >/dev/null
    for grp in wheel input video _seatd; do
        if getent group "$grp" >/dev/null 2>&1 && ! id -nG "$USER" | grep -qw "$grp"; then
            "$PRIV" usermod -aG "$grp" "$USER"
            log "  added $USER to $grp (takes effect on next login)"
        fi
    done

    command -v ufw >/dev/null 2>&1 && "$PRIV" ufw --force enable || true
    command -v xdg-user-dirs-update >/dev/null 2>&1 && xdg-user-dirs-update || true
fi

# ------------------------------------------------------------------ links ---
link() { # link <source-in-repo> <destination>
    local src="$1" dest="$2"
    # Already pointing at the right source: nothing to do.
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        return 0
    fi
    # Never write through a parent directory that itself links into the repo
    # (e.g. ~/.config/zsh -> void-config/zsh): the file is already deployed
    # via the directory link, and touching it would mutate the repo.
    local parent_real
    parent_real="$(realpath -m "$(dirname "$dest")")"
    case "$parent_real/" in
        "$REPO_DIR/"*)
            log "  already covered by directory link, skipping: $dest"
            return 0
            ;;
    esac
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        mkdir -p "$BACKUP_DIR"
        mv "$dest" "$BACKUP_DIR/$(echo "$dest" | tr '/' '_' | sed 's/^_//')"
        log "  backed up $dest"
    fi
    mkdir -p "$(dirname "$dest")"
    ln -sfn "$src" "$dest"
}

if [ "$DO_LINKS" -eq 1 ]; then
    log "Linking ~/.config directories (backups go to $BACKUP_DIR)"
    for d in btop foot gtk-3.0 gtk-4.0 matugen nvim rofi sway swaylock swaync \
             swayosd waybar xdg-desktop-portal zsh; do
        [ -e "$REPO_DIR/$d" ] && link "$REPO_DIR/$d" "$HOME/.config/$d"
    done
    [ -f "$REPO_DIR/starship.toml" ] && link "$REPO_DIR/starship.toml" "$HOME/.config/starship.toml"
    [ -f "$REPO_DIR/mimeapps.list" ] && link "$REPO_DIR/mimeapps.list" "$HOME/.config/mimeapps.list"

    log "Linking shell startup files"
    link "$REPO_DIR/shell/bash_profile" "$HOME/.bash_profile"
    link "$REPO_DIR/shell/bashrc"       "$HOME/.bashrc"
    link "$REPO_DIR/shell/zprofile"     "$HOME/.zprofile"
    link "$REPO_DIR/shell/zshrc"        "$HOME/.zshrc"

    log "Linking helper scripts into ~/.local/bin"
    mkdir -p "$HOME/.local/bin"
    for script in "$REPO_DIR"/bin/*; do
        [ -f "$script" ] || continue
        chmod +x "$script"
        link "$script" "$HOME/.local/bin/$(basename "$script")"
    done

    log "Creating data directories"
    mkdir -p "$HOME/.local/share/wallpapers" "$HOME/.cache"

    if ! command -v zsh >/dev/null 2>&1; then
        warn "zsh not installed; chsh skipped"
    elif [ "$SHELL" != "$(command -v zsh)" ]; then
        log "Setting zsh as login shell (password prompt expected)"
        chsh -s "$(command -v zsh)" || warn "chsh failed; run 'chsh -s \$(which zsh)' manually"
    fi
fi

# ------------------------------------------------------------------ fonts ---
if [ "$DO_FONTS" -eq 1 ]; then
    if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd Font"; then
        log "JetBrainsMono Nerd Font already present"
    else
        log "Downloading JetBrainsMono Nerd Font + Symbols (best effort)"
        mkdir -p "$HOME/.local/share/fonts"
        tmp="$(mktemp -d)"
        if curl -fsSL -o "$tmp/JetBrainsMono.tar.xz" \
                "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz" \
           && curl -fsSL -o "$tmp/Symbols.tar.xz" \
                "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/NerdFontsSymbolsOnly.tar.xz"; then
            tar -xf "$tmp/JetBrainsMono.tar.xz" -C "$HOME/.local/share/fonts"
            tar -xf "$tmp/Symbols.tar.xz" -C "$HOME/.local/share/fonts"
            fc-cache -f "$HOME/.local/share/fonts" >/dev/null
            log "  fonts installed"
        else
            warn "font download failed; copy .ttf files to ~/.local/share/fonts manually"
        fi
        rm -rf "$tmp"
    fi
fi

# ------------------------------------------------------------- wallpapers ---
if [ "$DO_WALLPAPERS" -eq 1 ]; then
    WALL_DIR="$HOME/.local/share/wallpapers"
    mkdir -p "$WALL_DIR"
    if [ "$(find "$WALL_DIR" -type f | head -1)" ]; then
        log "Wallpapers already present in $WALL_DIR ($(find "$WALL_DIR" -type f | wc -l) files), skipping download"
    else
        log "Fetching wallpaper collection (best effort)"
        tmp="$(mktemp -d)"
        if git clone --depth 1 https://github.com/rajan9884/wallpapers "$tmp/wallpapers" >/dev/null 2>&1; then
            # Flatten: copy every image out of the nested repo layout,
            # -n keeps any user-added file with the same name.
            find "$tmp/wallpapers" -type f \( -iname "*.jpg" -o -iname "*.jpeg" \
                -o -iname "*.png" -o -iname "*.webp" \) \
                -exec cp -n {} "$WALL_DIR/" \;
            log "  $(find "$WALL_DIR" -type f | wc -l) wallpapers in $WALL_DIR"
        else
            warn "wallpaper clone failed; copy images to $WALL_DIR manually"
        fi
        rm -rf "$tmp"
    fi
fi

# ------------------------------------------------------------------- done ---
log "Done."
if [ ! -s "$HOME/.cache/current-wallpaper" ]; then
    if pgrep -x sway >/dev/null 2>&1 && [ "$(find "$HOME/.local/share/wallpapers" -type f | head -1)" ]; then
        log "Seeding theme from a random wallpaper"
        "$HOME/.config/sway/scripts/random-wall.sh" >/dev/null 2>&1 \
            || warn "theme seeding failed; run ~/.config/sway/scripts/sway-wall.sh <image> manually"
    else
        warn "No wallpaper selected yet: log into Sway, then run"
        warn "  ~/.config/sway/scripts/sway-wall.sh ~/path/to/wallpaper.jpg"
        warn "to generate the matugen theme (waybar/rofi/foot/starship follow it)."
    fi
fi
cat <<'EOF'
[install] Not covered by this script (see README.md):
[install]   - Zen Browser  : build with vay (AUR zen-browser-bin)
[install]   - Cloudflare WARP .deb : convert with xdeb, then enable warp-svc
[install]   - gh auth login + per-repo git-work / git-personal identity
EOF
