-- MONITORS.LUA
-- https://wiki.hypr.land/Configuring/Monitors/
-- Find your monitor names with:
--   hyprctl monitors

-- 1. First monitor
-- hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1 })
-- hl.monitor({ output = "HDMI-A-1", disabled = true })

-- 2. Second monitor
-- hl.monitor({ output = "eDP-1", disabled = true })
-- hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto", scale = 1 })

-- 3. Extend / Auto (Samsung ATNA40YK11-0 OLED: 2880x1800@90 needs scale 2,
--    otherwise apps look tiny)
-- HDR state lives in ~/.cache/hypr-hdr-state ("hdr"/"sdr"), written only by
-- scripts/hdr-toggle.sh. Wallpaper switches run `hyprctl reload`, which
-- re-applies this file — reading the state here keeps the keybind as the
-- only thing that flips HDR. Default when the file is absent: hdr.
local _hdr_state_file = (os.getenv("HOME") or "") .. "/.cache/hypr-hdr-state"
local _hdr_on = true
do
    local _f = io.open(_hdr_state_file, "r")
    if _f then
        local _s = _f:read("*l") or ""
        _f:close()
        _hdr_on = (_s ~= "sdr")
    end
end
if _hdr_on then
    hl.monitor({ output = "eDP-1", mode = "2880x1800@90", position = "0x0", scale = 2, bitdepth = 10, cm = "hdr", supports_hdr = 1, supports_wide_color = 1 })
else
    hl.monitor({ output = "eDP-1", mode = "2880x1800@90", position = "0x0", scale = 2, bitdepth = 8, cm = "srgb" })
end
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 }) 

-- 4. Duplicate
-- hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = 1 })
-- hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "0x0", scale = 1 })

-- 5. Second vertical monitor
-- hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "0x0", scale = 1 })
-- hl.monitor({ output = "eDP-1", mode = "preferred", position = "1920x0", scale = 1, transform = 1 })

pcall(function()
    local path = os.getenv("HOME") .. "/.config/quickshell/state/display.lua"
    local f = io.open(path, "r")
    if f then
        f:close()
        dofile(path)
    end
end)

-- WORKSPACE RULES
-- https://wiki.hypr.land/Configuring/Workspace-Rules/

-- hl.workspace_rule({ workspace = "name:gaming", monitor = PRIMARY_MONITOR, default = true })

hl.workspace_rule({ workspace = "1", monitor = MONITOR1, default = true, persistent = true })
hl.workspace_rule({ workspace = "2", monitor = MONITOR1, default = true, persistent = true })
hl.workspace_rule({ workspace = "3", monitor = MONITOR1, default = true, persistent = true })
hl.workspace_rule({ workspace = "4", monitor = MONITOR1, default = true, persistent = true })

-- hl.workspace_rule({ workspace = "5", monitor = MONITOR2, default = true, persistent = true })
-- hl.workspace_rule({ workspace = "6", monitor = MONITOR2, default = true, persistent = true })

