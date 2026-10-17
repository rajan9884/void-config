-- ~/.config/hypr/hyprland.lua
-- Docs: https://wiki.hypr.land/Configuring/Start/

---- MY PROGRAMS ----

mainMod    = "SUPER"
terminal   = "foot"
fileManager = "thunar"
browser    = "brave"

---- AUTOSTART ----

local home = os.getenv("HOME")

hl.on("hyprland.start", function()
    -- hl.exec_cmd("dunst") replaced with quickshell
    -- Clipboard capture is owned by the quickshell clipboard plugin
    -- (wl-paste --watch clipboard.py); no external watchers here.
    -- audio stack: bare `pipewire` — drop-ins in /etc/pipewire/pipewire.conf.d
    -- (from install.sh) make it spawn wireplumber + pipewire-pulse itself
    hl.exec_cmd("pipewire")
    hl.exec_cmd("dbus-update-activation-environment --system --all 2>/dev/null || true")
    hl.exec_cmd("/usr/libexec/hyprpolkitagent") -- auth dialogs (sudo / pkexec)
    hl.exec_cmd(home .. "/.config/hypr/scripts/portal-warmup.sh")
    hl.exec_cmd(home .. "/.local/bin/power-profiles watch")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("sh -c 'B=$(cat \"${XDG_STATE_HOME:-$HOME/.local/state}/backlight\" 2>/dev/null); case \"$B\" in \"\"|*[!0-9]*) ;; *) brightnessctl -c backlight set \"$B\" >/dev/null 2>&1 || true;; esac'")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true")

    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("~/.config/hypr/scripts/wallpaper-restore.sh")
    hl.exec_cmd("foot --app-id=fastfetch") -- foot opens zsh, .zshrc prints fastfetch
    hl.exec_cmd("sleep 2 && QSG_RENDER_LOOP=basic qs -n") -- -n: never start a 2nd bar
end)

hl.config({
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        animate_manual_resizes = false,
        initial_workspace_tracking = false,
    },
    render = {
        direct_scanout = true,
        -- HDR / color management (HDR toggle: SUPER+CTRL+H)
        cm_enabled = true,
        cm_auto_hdr = 1, -- auto-switch to HDR for fullscreen HDR content
    },
    debug = {
        disable_logs = true,
        vfr = true,
    },
    xwayland = {
        enabled = false,
    },
})

---- ENVIRONMENT VARIABLES ----

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Ice")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("MOZ_ENABLE_WAYLAND", "1")
-- Pure Wayland session (no XWayland)
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("GDK_BACKEND", "wayland")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("OZONE_PLATFORM", "wayland")
-- Void / Intel Iris Xe (13th Gen Raptor Lake, iHD driver)
hl.env("LIBVA_DRIVER_NAME", "iHD")

---- INPUT ----

hl.config({
    input = {
        kb_layout = "us",
        -- Snappy repeat from old-arch (Hyprland defaults 600ms/25 feel laggy).
        repeat_rate = 40,
        repeat_delay = 250,
        follow_mouse = 1,
        sensitivity = 0.5,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
        },
    },
})

-- LAYOUT
hl.config({
    dwindle = { preserve_split = true },
})
hl.config({
    master = { new_status = "master" },
})

-- MISC
hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
})

---- SPLIT-OUT FILES ----

require("monitors")
require("keybinds")
require("look")
require("rules")
