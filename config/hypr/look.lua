---- LOOK AND FEEL ----

hl.config({ render = { expand_undersized_textures = false}})
hl.config({
    general = {
        gaps_in = 4,
        gaps_out = {
            top = 5,
            right = 8,
            bottom = 8,
            left = 8,
        },
        border_size = 2,
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
        col = {
            -- subtle light borders so SUPER+arrows focus jumps are visible
            active_border = "rgba(d8d8d8ff)",
            inactive_border = "rgba(5a5a5a99)",
        },
    },
    decoration = {
        rounding = 8,
        blur = {
            enabled = true,
            size = 5,
            passes = 1,
            vibrancy = 0.2,
        },
        shadow = {
            enabled = true,
            range = 4,
            render_power = 3,
        },
        -- Focus clarity: dim + slightly fade inactive windows
        dim_inactive = true,
        dim_strength = 0.12,
        dim_special = 0.0,
        inactive_opacity = 0.93,
    },
    animations = {
        enabled = true,
    },
})

hl.curve("easeOut", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.0} } })

hl.animation({ leaf = "windows",       enabled = true, speed = 5, bezier = "easeOut" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 5, bezier = "easeOut" })
hl.animation({ leaf = "windowsMove",   enabled = true, speed = 4, bezier = "easeOut" })
hl.animation({ leaf = "fade",          enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 6, bezier = "default", style = "slidefadevert" }) -- styles: "slide", "slidefade", "slidevert", "slidefadevert"
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 3.5, bezier = "default", style = "slidevert" })
hl.animation({ leaf = "layers",        enabled = true, speed = 4, bezier = "default", style = "slide" })

