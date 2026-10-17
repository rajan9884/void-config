-- ~/.config/hypr/keybinds.lua
-- Full keymap: old-arch port (minus calc/voxtype) + quickshell panels.
-- mainMod/terminal/browser/fileManager come from hyprland.lua.
-- Remaps vs old-arch (documented, no silent drops):
--   launcher: SUPER+Space/D/Q -> qs launcher (fuzzy + =calc)
--   calculator: SUPER+CTRL+Q -> qs launcher calc (rofi calc replaced)
--   opacity menu: SUPER+O -> qs opacity menu (rofi dmenu replaced)
--   float-toggle: SUPER+ALT+Space — SUPER+CTRL+Space is wallpaper picker
--   close window: SUPER+W (SUPER+Q freed)
--   scratchpad: SUPER+S toggle, SUPER+CTRL+S + SUPER+ALT+S send,
--             SUPER+ALT+SHIFT+S bring back (r+0) — Wheel moved to ALT+S
--   layout-toggle (was L): SUPER+ALT+L — SUPER+L stays theme light/dark
--   night-light (was CTRL+N): SUPER+CTRL+SHIFT+N — CTRL+N stays network panel
--   todo (was C): SUPER+ALT+T — SUPER+C/V/X are universal copy/paste/cut
--   clipboard: SUPER+SHIFT+V simple clipboard pipe (previous), SUPER+CTRL+V preview mgr
--   xkblayout (was X): SUPER+CTRL+X — voxtype not installed
--   40px CTRL+H/J/K/L resize dropped (no replacement) — CTRL+H is HDR
--   monitor scaling (was SLASH): SUPER+EQUAL up, SUPER+MINUS down —
--     SLASH stays cheatsheet (was double-bound: scaling AND cheatsheet)
--   togglesplit (was J): SUPER+ALT+J — SUPER+J stays focus-down
--   recorder (was R): SUPER+ALT+R
--   random wallpaper (was ALT+R): SUPER+R
--   close-window on W dropped (W = wallpaper picker) — Q still closes
--   lock: SUPER+CTRL+L — SUPER+TAB cycles workspaces (old-arch restore)
--   workspace-cycle: SUPER+TAB next, SUPER+SHIFT+TAB prev, SUPER+CTRL+TAB former
--   XF86PowerOff -> quickshell powermenu

local home = os.getenv("HOME")
local scripts = home .. "/.config/hypr/scripts"
local bin = home .. "/.local/bin"

-- ── Terminal / apps ──
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(scripts .. "/terminal-launch.sh"), { description = "Terminal (cwd-aware)" })
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd(bin .. "/helium-browser"), { description = "Open browser" })
hl.bind(mainMod .. " + SHIFT + Return", hl.dsp.exec_cmd(bin .. "/helium-browser"), { description = "Open browser" })
hl.bind(mainMod .. " + SHIFT + ALT + B", hl.dsp.exec_cmd(bin .. "/helium-browser --incognito"), { description = "Private browser" })
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("foot --working-directory " .. home .. " -e nvim"), { description = "Editor (nvim)" })
hl.bind(mainMod .. " + ALT + Return", hl.dsp.exec_cmd("foot --working-directory " .. home .. " -e tmux"), { description = "Terminal (tmux)" })
hl.bind(mainMod .. " + SHIFT + ALT + M", hl.dsp.exec_cmd("cliamp"), { description = "Music player (cliamp)" })
hl.bind(mainMod .. " + CTRL + T", hl.dsp.exec_cmd("foot --working-directory " .. home .. " -e btop"), { description = "System monitor" })
hl.bind(mainMod .. " + CTRL + W", hl.dsp.exec_cmd("foot --working-directory " .. home .. " -e nmtui"), { description = "Network connections" })
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(bin .. "/thunar-cwd"), { description = "File manager (cwd)" })
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.exec_cmd(bin .. "/thunar-cwd"), { description = "File manager (cwd)" })
hl.bind(mainMod .. " + SHIFT + ALT + F", hl.dsp.exec_cmd(bin .. "/thunar-cwd"), { description = "File manager (cwd)" })
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(browser), { description = "Open browser (brave)" })

-- ── Launcher (quickshell: fuzzy apps + =calc) ──
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("quickshell ipc call launcher toggle"), { description = "App launcher" })
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("quickshell ipc call launcher toggle"), { description = "App launcher" })

-- ── Quickshell ──
hl.bind("ALT + S", hl.dsp.exec_cmd("qs ipc call wheel toggle"), { description = "Wheel launcher" })
hl.bind(mainMod .. " + W", hl.dsp.window.close(), { description = "Close window" })
hl.bind(mainMod .. " + CTRL + L", hl.dsp.exec_cmd("hyprlock"), { description = "Lock screen" })
hl.bind(mainMod .. " + GRAVE", hl.dsp.exec_cmd("qs ipc call powermenu toggle"), { description = "Power menu" })
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("qs ipc call powermenu toggle"), { description = "Power menu" })
hl.bind(mainMod .. " + CTRL + N", hl.dsp.exec_cmd("qs ipc call network toggle"), { description = "Network panel" })
hl.bind(mainMod .. " + CTRL + B", hl.dsp.exec_cmd("qs ipc call bluetooth toggle"), { description = "Bluetooth panel" })
hl.bind(mainMod .. " + CTRL + A", hl.dsp.exec_cmd("qs ipc call audio toggle"), { description = "Audio panel" })
hl.bind(mainMod .. " + CTRL + D", hl.dsp.exec_cmd("qs ipc call display toggle"), { description = "Display panel" })
hl.bind(mainMod .. " + CTRL + SHIFT + Space", hl.dsp.exec_cmd("qs ipc call themes toggle"), { description = "Theme carousel" })
hl.bind(mainMod .. " + CTRL + Space", hl.dsp.exec_cmd("qs -n -p ~/.config/quickshell/hyprquickpaper"), { description = "Wallpaper picker" })
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = 0 }), { description = "Toggle fullscreen" })
hl.bind(mainMod .. " + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized" }), { description = "Maximize window" })
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("qs ipc call opacity toggle"), { description = "Opacity menu (100/90/80/70/60/50/40)" })
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("python3 " .. home .. "/.config/theme/bin/theme.py toggle"), { description = "Light/dark theme" })
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("qs ipc call notifications toggle"), { description = "Notifications" })
hl.bind("SUPER + comma", hl.dsp.exec_cmd("qs ipc call notifications dismiss"), { locked = true, description = "Dismiss notification" })
hl.bind("SUPER + CTRL + comma", hl.dsp.exec_cmd("qs ipc call notifications dismissAll"), { locked = true, description = "Dismiss all notifications" })
hl.bind("SUPER + SHIFT + comma", hl.dsp.exec_cmd("qs ipc call notifications dnd"), { locked = true, description = "Toggle notification silence" })
hl.bind(mainMod .. " + ALT + T", hl.dsp.exec_cmd("qs ipc call todo toggle"), { description = "To-do list" })
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("qs ipc call bar toggle"), { description = "Toggle bar" })

-- ── Float toggle (old-arch SUPER+T) ──
hl.bind(mainMod .. " + T", function()
    local w = hl.get_active_window()
    if not w then return end
    local was_floating = w.floating
    hl.dispatch(hl.dsp.window.float())
    if not was_floating then
        hl.dispatch(hl.dsp.window.resize({ x = 900, y = 600 }))
        hl.dispatch(hl.dsp.window.center())
    end
end, { description = "Toggle floating (small centered 900x600)" })

-- ── Scratchpad (general + music + terminal, old-arch parity) ──
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("scratchpad"), { description = "Toggle scratchpad" })
hl.bind(mainMod .. " + CTRL + S", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }), { description = "Move window to scratchpad" })
hl.bind(mainMod .. " + ALT + S", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }), { description = "Send window to scratchpad" })
hl.bind(mainMod .. " + ALT + SHIFT + S", hl.dsp.window.move({ workspace = "r+0" }), { description = "Bring window back from scratchpad" })
hl.bind(mainMod .. " + ALT + M", hl.dsp.workspace.toggle_special("music"), { description = "Toggle music scratchpad" })
hl.bind(mainMod .. " + CTRL + ALT + M", hl.dsp.window.move({ workspace = "special:music", follow = false }), { description = "Move window to music scratchpad" })
hl.bind(mainMod .. " + CTRL + Return", hl.dsp.workspace.toggle_special("terminal"), { description = "Toggle terminal scratchpad" })
hl.bind(mainMod .. " + CTRL + SHIFT + Return", hl.dsp.window.move({ workspace = "special:terminal", follow = false }), { description = "Move window to terminal scratchpad" })

-- ── Layout / groups ──
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo(), { description = "Pseudo window" })
hl.bind(mainMod .. " + ALT + J", hl.dsp.layout("togglesplit"), { description = "Toggle window split" })
hl.bind(mainMod .. " + ALT + L", hl.dsp.exec_cmd(scripts .. "/workspace-layout-toggle.sh"), { description = "Toggle workspace layout" })
hl.bind(mainMod .. " + G", hl.dsp.group.toggle(), { description = "Toggle window group" })
hl.bind(mainMod .. " + ALT + G", hl.dsp.window.move({ out_of_group = true }), { description = "Move window out of group" })
hl.bind(mainMod .. " + ALT + left", hl.dsp.window.move({ into_group = "l" }), { description = "Move window into group (left)" })
hl.bind(mainMod .. " + ALT + right", hl.dsp.window.move({ into_group = "r" }), { description = "Move window into group (right)" })
hl.bind(mainMod .. " + ALT + up", hl.dsp.window.move({ into_group = "u" }), { description = "Move window into group (up)" })
hl.bind(mainMod .. " + ALT + down", hl.dsp.window.move({ into_group = "d" }), { description = "Move window into group (down)" })
hl.bind(mainMod .. " + ALT + TAB", hl.dsp.group.next(), { description = "Next window in group" })
hl.bind(mainMod .. " + ALT + SHIFT + TAB", hl.dsp.group.prev(), { description = "Previous window in group" })
hl.bind(mainMod .. " + CTRL + left", hl.dsp.group.prev(), { description = "Focus previous in group" })
hl.bind(mainMod .. " + CTRL + right", hl.dsp.group.next(), { description = "Focus next in group" })
hl.bind(mainMod .. " + ALT + mouse_up", hl.dsp.group.prev(), { description = "Previous window in group" })
hl.bind(mainMod .. " + ALT + mouse_down", hl.dsp.group.next(), { description = "Next window in group" })
for idx = 1, 5 do
    hl.bind(mainMod .. " + ALT + " .. tostring(idx), hl.dsp.group.active({ index = idx }), { description = "Switch to group window " .. idx })
end

-- ── Window cycling / monitors ──
hl.bind("ALT + Tab", hl.dsp.window.cycle_next(), { description = "Next window" })
hl.bind("ALT + SHIFT + Tab", hl.dsp.window.cycle_next({ next = false }), { description = "Previous window" })
hl.bind("CTRL + ALT + TAB", hl.dsp.focus({ monitor = "+1" }), { description = "Focus next monitor" })
hl.bind("CTRL + SHIFT + ALT + TAB", hl.dsp.focus({ monitor = "-1" }), { description = "Focus previous monitor" })
hl.bind(mainMod .. " + Home", hl.dsp.exec_cmd(scripts .. "/window-size-save.sh restore"), { description = "Restore saved window size" })
hl.bind(mainMod .. " + ALT + Home", hl.dsp.exec_cmd(scripts .. "/window-size-save.sh save"), { description = "Save window size" })
hl.bind(mainMod .. " + BACKSPACE", hl.dsp.exec_cmd(scripts .. "/window-transparency-toggle.sh"), { description = "Toggle window transparency" })
hl.bind(mainMod .. " + SHIFT + BACKSPACE", hl.dsp.exec_cmd(scripts .. "/window-gaps-toggle.sh"), { description = "Toggle window gaps" })
hl.bind(mainMod .. " + EQUAL", hl.dsp.exec_cmd(scripts .. "/monitor-scaling.sh up"), { description = "Monitor scaling up" })
hl.bind(mainMod .. " + MINUS", hl.dsp.exec_cmd(scripts .. "/monitor-scaling.sh down"), { description = "Monitor scaling down" })
hl.bind("CTRL + ALT + DELETE", hl.dsp.exec_cmd(bin .. "/window-close-all"), { locked = true, description = "Close all windows" })

-- ── Toggles ──
hl.bind(mainMod .. " + CTRL + SHIFT + N", hl.dsp.exec_cmd(bin .. "/night-light-toggle"), { description = "Toggle nightlight" })
hl.bind(mainMod .. " + CTRL + I", hl.dsp.exec_cmd(scripts .. "/idle-toggle.sh"), { description = "Toggle idle lock" })
hl.bind(mainMod .. " + K", hl.dsp.exec_cmd("qs ipc call cheatsheet toggle"), { description = "Keybindings cheatsheet" })
hl.bind(mainMod .. " + slash", hl.dsp.exec_cmd("qs ipc call cheatsheet toggle"), { description = "Keybindings cheatsheet" })
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.exec_cmd(scripts .. "/animations-toggle.sh"), { description = "Toggle animations" })
hl.bind(mainMod .. " + CTRL + H", hl.dsp.exec_cmd(scripts .. "/hdr-toggle.sh"), { description = "Toggle HDR (eDP-1)" })
hl.bind(mainMod .. " + CTRL + Z", function()
    local z = hl.get_config("cursor.zoom_factor") or 1
    hl.config({ cursor = { zoom_factor = z + 1 } })
end, { description = "Zoom in" })
hl.bind(mainMod .. " + CTRL + ALT + Z", function() hl.config({ cursor = { zoom_factor = 1 } }) end, { description = "Reset zoom" })
local square_aspect = false
hl.bind(mainMod .. " + CTRL + BACKSPACE", function()
    square_aspect = not square_aspect
    if square_aspect then
        hl.config({ layout = { single_window_aspect_ratio = { 1, 1 } } })
    else
        hl.config({ layout = { single_window_aspect_ratio = { 0, 0 } } })
    end
end, { description = "Toggle single-window square aspect" })

-- ── Wallpaper ──
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(scripts .. "/random-wall.sh"), { description = "Random wallpaper" })

-- ── Webapps ──
hl.bind(mainMod .. " + ALT + SHIFT + W", hl.dsp.exec_cmd("qs ipc call webapps install"), { description = "Install web app" })
hl.bind(mainMod .. " + ALT + SHIFT + X", hl.dsp.exec_cmd("qs ipc call webapps remove"), { description = "Remove web app" })

-- ── Resize family: fine (±25) / normal (±100) / coarse (±300) ──
hl.bind(mainMod .. " + minus", hl.dsp.window.resize({ x = -100, y = 0, relative = true }), { repeating = true, description = "Resize window" })
hl.bind(mainMod .. " + equal", hl.dsp.window.resize({ x = 100, y = 0, relative = true }), { repeating = true, description = "Resize window" })
hl.bind(mainMod .. " + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -100, relative = true }), { repeating = true, description = "Resize window" })
hl.bind(mainMod .. " + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 100, relative = true }), { repeating = true, description = "Resize window" })
hl.bind(mainMod .. " + ALT + minus", hl.dsp.window.resize({ x = -25, y = 0, relative = true }), { repeating = true, description = "Resize window (fine)" })
hl.bind(mainMod .. " + ALT + equal", hl.dsp.window.resize({ x = 25, y = 0, relative = true }), { repeating = true, description = "Resize window (fine)" })
hl.bind(mainMod .. " + SHIFT + ALT + minus", hl.dsp.window.resize({ x = 0, y = -25, relative = true }), { repeating = true, description = "Resize window (fine)" })
hl.bind(mainMod .. " + SHIFT + ALT + equal", hl.dsp.window.resize({ x = 0, y = 25, relative = true }), { repeating = true, description = "Resize window (fine)" })
hl.bind(mainMod .. " + CTRL + minus", hl.dsp.window.resize({ x = -300, y = 0, relative = true }), { repeating = true, description = "Resize window (coarse)" })
hl.bind(mainMod .. " + CTRL + equal", hl.dsp.window.resize({ x = 300, y = 0, relative = true }), { repeating = true, description = "Resize window (coarse)" })
hl.bind(mainMod .. " + CTRL + SHIFT + minus", hl.dsp.window.resize({ x = 0, y = -300, relative = true }), { repeating = true, description = "Resize window (coarse)" })
hl.bind(mainMod .. " + CTRL + SHIFT + equal", hl.dsp.window.resize({ x = 0, y = 300, relative = true }), { repeating = true, description = "Resize window (coarse)" })

-- ── Focus / move (vim-style) ──
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }), { description = "Focus left" })
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }), { description = "Focus down" })
hl.bind(mainMod .. " + ALT + K", hl.dsp.focus({ direction = "up" }), { description = "Focus up" })
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }), { description = "Focus right" })
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }), { description = "Focus left" })
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }), { description = "Focus right" })
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }), { description = "Focus up" })
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }), { description = "Focus down" })
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }), { description = "Move window left" })
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }), { description = "Move window down" })
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }), { description = "Move window up" })
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }), { description = "Move window right" })
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.swap({ direction = "left" }), { description = "Swap window left" })
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.swap({ direction = "right" }), { description = "Swap window right" })
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.swap({ direction = "up" }), { description = "Swap window up" })
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.swap({ direction = "down" }), { description = "Swap window down" })
hl.bind(mainMod .. " + SHIFT + ALT + left", hl.dsp.workspace.move({ monitor = "l" }), { description = "Move workspace to left monitor" })
hl.bind(mainMod .. " + SHIFT + ALT + right", hl.dsp.workspace.move({ monitor = "r" }), { description = "Move workspace to right monitor" })
hl.bind(mainMod .. " + SHIFT + ALT + up", hl.dsp.workspace.move({ monitor = "u" }), { description = "Move workspace to up monitor" })
hl.bind(mainMod .. " + SHIFT + ALT + down", hl.dsp.workspace.move({ monitor = "d" }), { description = "Move workspace to down monitor" })

-- ── Universal copy / paste / cut / select-all (terminal-aware) ──
local function send_shortcut_once(mods, key)
    return function()
        hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
        hl.timer(function()
            hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
        end, { timeout = 50, type = "oneshot" })
    end
end
local terminal_classes = {
    "foot", "wezterm", "ghostty", "rio", "ptyxis",
    "konsole", "xfce4-terminal", "gnome-terminal", "gnome-console",
    "urxvt", "urxvtc", "xterm", "st",
    -- foot instances with a custom --app-id are still terminals
    "fastfetch", "text-preview",
}
local function active_window_is_terminal()
    local window = hl.get_active_window()
    if not window then return false end
    local tags = type(window.tags) == "table" and window.tags or { window.tags }
    for _, tag in ipairs(tags) do
        if tostring(tag):gsub("%*$", "") == "terminal" then return true end
    end
    for _, class in ipairs(terminal_classes) do
        if tostring(window.class or ""):lower() == class then return true end
    end
    return false
end
local function universal_clipboard_shortcut(default_mods, default_key, terminal_mods, terminal_key)
    return function()
        if active_window_is_terminal() then
            send_shortcut_once(terminal_mods, terminal_key)()
        else
            send_shortcut_once(default_mods, default_key)()
        end
    end
end
hl.bind("SUPER + C", universal_clipboard_shortcut("CTRL", "C", "CTRL", "Insert"), { description = "Universal copy" })
hl.bind("SUPER + V", universal_clipboard_shortcut("CTRL", "V", "SHIFT", "Insert"), { description = "Universal paste" })
hl.bind("SUPER + X", send_shortcut_once("CTRL", "X"), { description = "Universal cut" })
hl.bind("SUPER + A", hl.dsp.send_shortcut({ mods = "CTRL", key = "A" }), { description = "Select all" })

-- ── Clipboard history (simple dmenu, as before) ──
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("qs ipc call clipboard toggle"), { description = "Clipboard history" })

-- ── Emoji / clipboard manager ──
hl.bind(mainMod .. " + CTRL + Q", hl.dsp.exec_cmd("qs ipc call launcher calc"), { description = "Calculator (=expr, Enter copies)" })
hl.bind(mainMod .. " + period", hl.dsp.exec_cmd("qs ipc call emoji toggle"), { description = "Emoji picker" })
hl.bind(mainMod .. " + CTRL + E", hl.dsp.exec_cmd("qs ipc call emoji toggle"), { description = "Emoji picker" })
hl.bind("SUPER + CTRL + V", hl.dsp.exec_cmd("qs ipc call clipboard toggle"), { description = "Clipboard history" })
hl.bind("SUPER + CTRL + SHIFT + V", hl.dsp.exec_cmd("qs ipc call clipboard wipe"), { description = "Wipe clipboard history" })

-- ── Screenshots ──
hl.bind("Print", hl.dsp.exec_cmd(bin .. "/capture-region"), { description = "Screenshot region" })
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(bin .. "/capture-satty"), { description = "Screenshot & annotate" })
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("pkill hyprpicker || hyprpicker -a"), { description = "Color picker" })
hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd(bin .. "/capture-screen"), { description = "Capture entire screen" })
hl.bind("ALT + Print", hl.dsp.exec_cmd(scripts .. "/screen-record.sh"), { description = "Screen recording" })
hl.bind("SUPER + CTRL + Print", hl.dsp.exec_cmd(bin .. "/ocr-extract"), { description = "OCR region to clipboard" })
hl.bind("Delete", hl.dsp.exec_cmd("sh -c 'mkdir -p " .. home .. "/Pictures/Screenshots; file=" .. home .. "/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png; grim \"$file\"; wl-copy < \"$file\"; notify-send -t 4000 \"Screenshot saved\" \"$file\"'"), { description = "Screenshot fullscreen" })
hl.bind("SHIFT + Delete", hl.dsp.exec_cmd("sh -c 'mkdir -p " .. home .. "/Pictures/Screenshots; file=" .. home .. "/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png; grim -g \"$(slurp)\" \"$file\"; wl-copy < \"$file\"; notify-send -t 4000 \"Screenshot saved\" \"$file\"'"), { description = "Screenshot area" })

-- ── Recorder (wf-recorder region toggle; moved off SUPER+R for wallpaper) ──
hl.bind(mainMod .. " + ALT + R", hl.dsp.exec_cmd(scripts .. "/screen-record.sh"), { description = "Screen recording" })

-- ── Mouse ──
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Drag window" })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Resize window" })
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), { description = "Next workspace" })
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }), { description = "Previous workspace" })

-- ── Zoom ──
local function zoomfunction(value)
    local zoomvalue = hl.get_config("cursor:zoom_factor")
    if (zoomvalue + value) > 1.5 then
        hl.config({ cursor = { zoom_factor = 1.5 } })
    elseif (zoomvalue + value) < 1.0 then
        hl.config({ cursor = { zoom_factor = 1.0 } })
    else
        hl.config({ cursor = { zoom_factor = zoomvalue + value } })
    end
end
hl.bind(mainMod .. " + code:82", function() zoomfunction(-0.3) end, { repeating = true })
hl.bind(mainMod .. " + code:86", function() zoomfunction(0.3) end, { repeating = true })

-- ── Workspaces (occupied-only cycling; empty workspaces skipped) ──
hl.bind(mainMod .. " + Tab", hl.dsp.exec_cmd(scripts .. "/workspace-cycle.sh next"), { description = "Next workspace (occupied)" })
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.exec_cmd(scripts .. "/workspace-cycle.sh prev"), { description = "Previous workspace (occupied)" })
hl.bind(mainMod .. " + CTRL + Tab", hl.dsp.focus({ workspace = "previous" }), { description = "Former workspace" })
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }), { description = "Workspace " .. i })
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }), { description = "Move to workspace " .. i })
    hl.bind(mainMod .. " + SHIFT + ALT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }), { description = "Send to workspace " .. i })
end

-- ── Exit / layout ──
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit(), { description = "Exit Hyprland" })
hl.bind(mainMod .. " + CTRL + X", hl.dsp.exec_cmd("hyprctl switchxkblayout current next"), { description = "Switch keyboard layout" })

-- ── Volume / brightness / media ──
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(scripts .. "/osd-volume.sh up"), { repeating = true, locked = true, description = "Volume up" })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(scripts .. "/osd-volume.sh down"), { repeating = true, locked = true, description = "Volume down" })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(scripts .. "/osd-volume.sh mute-toggle"), { locked = true, description = "Mute toggle" })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd(scripts .. "/osd-volume.sh mic-toggle"), { locked = true, description = "Mic mute toggle" })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(scripts .. "/osd-brightness.sh up"), { repeating = true, locked = true, description = "Brightness up" })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(scripts .. "/osd-brightness.sh down"), { repeating = true, locked = true, description = "Brightness down" })
hl.bind("SHIFT + XF86MonBrightnessUp", hl.dsp.exec_cmd(scripts .. "/osd-brightness.sh max"), { locked = true, description = "Brightness max" })
hl.bind("SHIFT + XF86MonBrightnessDown", hl.dsp.exec_cmd(scripts .. "/osd-brightness.sh min"), { locked = true, description = "Brightness min" })
hl.bind("ALT + XF86MonBrightnessUp", hl.dsp.exec_cmd(scripts .. "/osd-brightness.sh up"), { locked = true, repeating = true, description = "Brightness up (precise)" })
hl.bind("ALT + XF86MonBrightnessDown", hl.dsp.exec_cmd(scripts .. "/osd-brightness.sh down"), { locked = true, repeating = true, description = "Brightness down (precise)" })
hl.bind("ALT + XF86AudioRaiseVolume", hl.dsp.exec_cmd(scripts .. "/osd-volume.sh up"), { locked = true, repeating = true, description = "Volume up (precise)" })
hl.bind("ALT + XF86AudioLowerVolume", hl.dsp.exec_cmd(scripts .. "/osd-volume.sh down"), { locked = true, repeating = true, description = "Volume down (precise)" })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Next track" })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Previous track" })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play/pause" })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true, description = "Play/pause" })
hl.bind("ALT + XF86AudioPlay", hl.dsp.exec_cmd("playerctl next"), { locked = true, description = "Next track" })
hl.bind("ALT + SHIFT + XF86AudioPlay", hl.dsp.exec_cmd("playerctl previous"), { locked = true, description = "Previous track" })
hl.bind("XF86KbdBrightnessUp", hl.dsp.exec_cmd(scripts .. "/osd-keyboard-brightness.sh up"), { locked = true, repeating = true, description = "Keyboard light up" })
hl.bind("XF86KbdBrightnessDown", hl.dsp.exec_cmd(scripts .. "/osd-keyboard-brightness.sh down"), { locked = true, repeating = true, description = "Keyboard light down" })
hl.bind("XF86KbdLightOnOff", hl.dsp.exec_cmd(scripts .. "/osd-keyboard-brightness.sh cycle"), { locked = true, description = "Keyboard light cycle" })
hl.bind("XF86Eject", hl.dsp.exec_cmd("eject"), { locked = true, description = "Eject media" })
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("qs ipc call powermenu toggle"), { locked = true, description = "Power menu" })
hl.bind("XF86TouchpadToggle", hl.dsp.exec_cmd(scripts .. "/touchpad-toggle.sh toggle"), { locked = true, description = "Toggle touchpad" })
hl.bind("XF86TouchpadOn", hl.dsp.exec_cmd(scripts .. "/touchpad-toggle.sh on"), { locked = true, description = "Touchpad on" })
hl.bind("XF86TouchpadOff", hl.dsp.exec_cmd(scripts .. "/touchpad-toggle.sh off"), { locked = true, description = "Touchpad off" })

-- ── Lid switch ──
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd(scripts .. "/lid-close.sh"), { locked = true, description = "Lock on lid close" })
