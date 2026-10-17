-- Docs: https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- To check class name, open the app and run:
-- hyprctl clients

-- Opacity rules for all windows except fullscreen.
-- Two values = inactive + active so FOCUSED windows also follow SUPER+O
-- (a single value only pins the unfocused state, leaving the focused
-- window at full opacity — that read as "Thunar has fixed opacity").
hl.window_rule({
    match = { class = ".*" },
    opacity = "1.0 1.0 override",
})
hl.window_rule({
    match = { class = ".*", fullscreen = true },
    opacity = "1.0 1.0 override",
})

--hl.window_rule({
--    name = "brave-opaque",
--    match = { class = "^brave-browser$" },
--    opacity = "1.0 override",
--})

hl.window_rule({
    match = { class = "foot" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "float-pavucontrol",
    match = { class = "^(pavucontrol)$" },
    float = true,
})

hl.window_rule({
    name = "float-nm-connection-editor",
    match = { class = "^(nm-connection-editor)$" },
    float = true,
})

hl.window_rule({
    name = "float-blueman-manager",
    match = { class = "^(blueman-manager)$" },
    float = true,
})

hl.window_rule({
    name = "float-open-file",
    match = { title = "^(Open File)$" },
    float = true,
})

hl.window_rule({
    name = "float-save-file",
    match = { title = "^(Save File)$" },
    float = true,
})

-- ── Ported from old-arch window-rules.lua ──
hl.window_rule({
    name = "idle-inhibit-fullscreen",
    match = { class = ".*" },
    idle_inhibit = "fullscreen",
})

hl.window_rule({
    name = "suppress-maximize-all",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "float-center",
    match = { class = ".*" },
    center = true,
})

hl.window_rule({
    name = "media-float",
    match = { class = "^(imv|mpv)$" },
    float = true,
    center = true,
    size = { 875, 600 },
})

hl.window_rule({
    name = "doc-float",
    match = { class = "^org.pwmt.zathura$" },
    float = true,
    center = true,
    size = { 900, 700 },
})

hl.window_rule({
    name = "thunar-dialog-float",
    match = { class = "^Thunar$", title = ".*(Properties|Rename|Preferences|Bulk Rename).*" },
    float = true,
    center = true,
    size = { 700, 500 },
})

hl.window_rule({
    name = "media-opaque",
    match = { class = "^(zoom|vlc|mpv|org.kde.kdenlive|com.obsproject.Studio|com.github.PintaProject.Pinta|imv)$" },
    opacity = "1 1",
})

hl.window_rule({
    name = "code-translucent",
    match = { class = "^(code|Code|code-oss)$" },
    opacity = "0.92 0.88",
})

hl.window_rule({
    name = "text-preview-float",
    match = { class = "^text-preview$" },
    float = true,
    center = true,
    size = { 800, 600 },
})

hl.window_rule({
    name = "webapp-install-float",
    match = { class = "(webapp-install|webapp-remove)" },
    float = true,
    center = true,
    size = { 650, 480 },
})
