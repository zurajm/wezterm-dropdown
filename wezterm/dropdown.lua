-- dropdown.lua
-- Configuration exclusively for the drop-down WezTerm instance.
local wezterm = require 'wezterm'
local base = require 'dropdown_base'
local wallpaper = require 'wallpaper'
local config = wezterm.config_builder()

-- Aplicamos la base compartida
base.apply(config)

-- Configuraciones específicas para el dropdown
config.enable_tab_bar = true

-- CRITICAL: Use "RESIZE", NOT "NONE".
-- With "NONE", WezTerm tells KDE Wayland "I am a native fullscreen surface".
-- KDE then memorises the original monitor size and forces it on minimize/restore.
config.window_decorations = "RESIZE"

-- Define a mux domain for the dropdown. Without this, wezterm --domain dropdown
-- fails with "invalid domain dropdown; terminating". With this, wezterm-gui
-- registers a named mux server that the toggle script can target via
-- `wezterm start --domain dropdown` (without --always-new-process), avoiding
-- the KWin placement race that comes with starting a fresh process per F12.
config.unix_domains = {
    {
        name = "dropdown",
        -- No socket_path: use default. Wezterm picks /tmp/wezterm-$USER/dropdown.
    },
}

-- Apply the same random-wallpaper background as the main session, tinted by
-- the dropdown's own color scheme (Dracula, set in dropdown_base.lua).
wezterm.on('window-config-reloaded', function(window)
    if not window:get_config_overrides() then
        wallpaper.apply_random(window, 'Dracula')
    end
end)

return config
