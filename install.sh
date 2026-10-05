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
#   --packages-only   install XBPS packages and enable services, skip stow links
#   --links-only      only (re)stow packages into $HOME (requires stow installed)
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
    # NOTE: elogind is intentionally NOT supervised here. The elogind package
    # ships dbus activation (org.freedesktop.login1.service, Exec with
    # --daemon), which starts it on first login1 request; the daemon
    # self-backgrounds, so a runit supervisor can never track it and just
    # spins in a restart loop showing a permanent red X in vsv.
    for svc in NetworkManager bluetoothd chronyd cronie dbus greetd polkitd \
               power-profiles-daemon rtkit seatd ufw; do
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
    # snd-perms re-triggers sound-device udev events at boot so /dev/snd/*
    # gets GROUP=audio + the elogind uaccess ACL. Boot coldplug otherwise
    # leaves them root:root 0600 and PipeWire falls back to Dummy Output
    # (see system/sv/snd-perms/run for the full explanation).
    "$PRIV" mkdir -p /etc/sv/snd-perms
    "$PRIV" cp "$REPO_DIR/system/sv/snd-perms/run" /etc/sv/snd-perms/run
    "$PRIV" chmod +x /etc/sv/snd-perms/run
    if [ ! -e /var/service/snd-perms ]; then
        "$PRIV" ln -s /etc/sv/snd-perms /var/service/
        log "  enabled snd-perms"
    fi

    log "Configuring greetd + wheel sudo"
    if command -v tuigreet >/dev/null 2>&1; then
        "$PRIV" mkdir -p /etc/greetd
        "$PRIV" tee /etc/greetd/config.toml >/dev/null <<'EOF'
[terminal]
vt = 7
[default_session]
command = "tuigreet --time --asterisks --remember --remember-user-session --sessions /usr/share/wayland-sessions --theme border=blue;text=white;prompt=green;time=gray;action=cyan;button=yellow;container=black;input=red"
user = "_greeter"
EOF
    else
        warn "tuigreet not installed; skipping /etc/greetd/config.toml"
    fi
    # Sway needs a session bus for waybar/mako/portals, but greetd runs the
    # session Exec= line verbatim (no shell, no bus). Wrap it so every login
    # gets DBUS_SESSION_BUS_ADDRESS from the start (absolute paths: greetd's
    # PATH may not include /usr/sbin).
    if [ -f /usr/share/wayland-sessions/sway.desktop ]; then
        "$PRIV" sed -i 's|^Exec=.*|Exec=/usr/sbin/dbus-run-session -- /usr/sbin/sway|' \
            /usr/share/wayland-sessions/sway.desktop
        log "  sway.desktop runs under dbus-run-session"
    fi
    # PipeWire session stack: sway launches bare `pipewire`, which spawns the
    # session manager + PulseAudio bridge from these drop-ins (sway/config
    # autostart note). Without them there is no sink and no audio.
    if [ -x /usr/bin/wireplumber ] || [ -x /usr/sbin/wireplumber ]; then
        "$PRIV" mkdir -p /etc/pipewire/pipewire.conf.d
        printf '%s\n' '# void-config: spawn the session manager from bare `pipewire`.' \
            'context.exec = [' \
            '    { path = "/usr/sbin/wireplumber" args = "" }' \
            ']' | "$PRIV" tee /etc/pipewire/pipewire.conf.d/10-wireplumber.conf >/dev/null
        printf '%s\n' '# void-config: PulseAudio compatibility for pactl/pavucontrol/waybar.' \
            'context.exec = [' \
            '    { path = "/usr/sbin/pipewire-pulse" args = "" }' \
            ']' | "$PRIV" tee /etc/pipewire/pipewire.conf.d/20-pipewire-pulse.conf >/dev/null
        log "  pipewire autospawn drop-ins installed"
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
# Stow layout: each top-level directory is a stow package mirroring $HOME,
# e.g. alacritty/.config/alacritty/ -> ~/.config/alacritty,
# shell/.zshrc -> ~/.zshrc, bin/.local/bin/* -> ~/.local/bin/*.
# `system/` is NOT stowed (deployed to /etc/sv above).
# ~/.config/starship.toml is NOT stowed: matugen generates it directly
# from matugen/.config/matugen/templates/starship.toml on every wallpaper
# switch, so there is no tracked source file for it.
STOW_PACKAGES="alacritty applications bin btop environment fastfetch foot gtk mako matugen mimeapps nvim rofi shell sway swayosd waybar xdg-desktop-portal zsh"

if [ "$DO_LINKS" -eq 1 ]; then
    if ! command -v stow >/dev/null 2>&1; then
        echo "stow is required (packages.txt includes it). Run ./install.sh without --links-only first," >&2
        echo "or 'xbps-install -Sy stow' manually." >&2
        exit 1
    fi
    log "Removing legacy flat-layout symlinks (backups go to $BACKUP_DIR)"
    # Pre-stow layout linked whole dirs (e.g. ~/.config/alacritty ->
    # void-config/alacritty); those targets moved under .config/, so any
    # symlink pointing into the repo is stale and must go before stowing.
    while IFS= read -r -d '' l; do
        target="$(readlink "$l")"
        case "$target" in
            "$REPO_DIR"/*)
                mkdir -p "$BACKUP_DIR"
                mv "$l" "$BACKUP_DIR/$(echo "$l" | tr '/' '_' | sed 's/^_//')"
                log "  backed up stale link $l"
                ;;
        esac
    done < <(find "$HOME" -maxdepth 1 -type l -print0 2>/dev/null; \
        find "$HOME/.config" -maxdepth 1 -mindepth 1 -type l -print0 2>/dev/null; \
        find "$HOME/.local/bin" "$HOME/.local/share/applications" \
        -maxdepth 1 -mindepth 1 -type l -print0 2>/dev/null)
    # Legacy ~/.config/fastfetch and ~/.config/environment.d were real dirs
    # before being versioned; back them up so stow can take over cleanly.
    # (Contents were imported into fastfetch/ and environment/ packages.)
    # ~/.config/swayosd stays a real dir: the package ships no tracked files,
    # matugen writes style.css there directly. ~/.config/starship.toml likewise
    # stays a real generated file — never backed up, never stowed.
    for realdir in "$HOME/.config/fastfetch" "$HOME/.config/environment.d"; do
        if [ -e "$realdir" ] && [ ! -L "$realdir" ]; then
            mkdir -p "$BACKUP_DIR"
            mv "$realdir" "$BACKUP_DIR/$(echo "$realdir" | tr '/' '_' | sed 's/^_//')"
            log "  backed up $realdir"
        fi
    done

    log "Stowing packages into \$HOME"
    # shellcheck disable=SC2086
    stow -R -t "$HOME" $STOW_PACKAGES
    chmod +x "$REPO_DIR"/bin/.local/bin/* 2>/dev/null || true

    log "Creating data directories"
    mkdir -p "$HOME/.local/share/wallpapers" "$HOME/.cache"

    if ! command -v zsh >/dev/null 2>&1; then
        warn "zsh not installed; chsh skipped"
    else
        # Compare canonical paths: /bin/zsh, /usr/bin/zsh and /usr/sbin/zsh
        # are hardlinks to the same binary, but $SHELL may name a different
        # one than `command -v` finds first in PATH. A string comparison
        # would trigger a pointless (and failing) chsh in that case.
        _zsh="$(command -v zsh)"
        _shell_canon="$(readlink -f "$SHELL" 2>/dev/null || echo "$SHELL")"
        _zsh_canon="$(readlink -f "$_zsh" 2>/dev/null || echo "$_zsh")"
        if [ "$_shell_canon" = "$_zsh_canon" ]; then
            : # already on zsh
        else
            # chsh only accepts paths listed in /etc/shells; prefer one
            # that already is (e.g. /usr/bin/zsh over /usr/sbin/zsh).
            _chsh_target=""
            for _cand in "$_zsh" /usr/bin/zsh /bin/zsh; do
                if [ -x "$_cand" ] && grep -Fxq "$_cand" /etc/shells 2>/dev/null; then
                    _chsh_target="$_cand"
                    break
                fi
            done
            if [ -z "$_chsh_target" ]; then
                warn "no zsh path is listed in /etc/shells; add one first:"
                warn "  echo $_zsh | sudo tee -a /etc/shells && chsh -s $_zsh"
            else
                log "Setting zsh as login shell ($_chsh_target, password prompt expected)"
                chsh -s "$_chsh_target" || warn "chsh failed; run 'chsh -s $_chsh_target' manually"
            fi
            unset _zsh _shell_canon _zsh_canon _chsh_target _cand
        fi
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
    # sway/config points at a static fallback background; guarantee it exists
    # so a fresh clone without that exact filename never errors at startup.
    if [ ! -f "$WALL_DIR/fallback-wallpaper.jpg" ]; then
        _fb="$(find "$WALL_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' \
            -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | sort | head -n 1 || true)"
        if [ -n "${_fb:-}" ]; then
            cp -n "$_fb" "$WALL_DIR/fallback-wallpaper.jpg"
            log "  seeded fallback wallpaper from $(basename "$_fb")"
        fi
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
        warn "to generate the matugen theme (waybar/rofi/alacritty/starship follow it)."
    fi
fi
cat <<'EOF'
[install] Not covered by this script (see README.md):
[install]   - Zen Browser  : build with vay (AUR zen-browser-bin)
[install]   - Cloudflare WARP .deb : convert with xdeb, then enable warp-svc
[install]   - gh auth login + per-repo git-work / git-personal identity
EOF
