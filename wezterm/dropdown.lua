-- dropdown.lua
-- Configuration exclusively for the drop-down WezTerm instance.
local wezterm = require 'wezterm'
local base = require 'dropdown_base'
local config = wezterm.config_builder()

-- Aplicamos la base compartida
base.apply(config)

-- Configuraciones específicas para el dropdown
config.enable_tab_bar = true

-- CRITICAL: Use "RESIZE", NOT "NONE".
-- With "NONE", WezTerm tells KDE Wayland "I am a native fullscreen surface".
-- KDE then memorises the original monitor size and forces it on minimize/restore.
config.window_decorations = "RESIZE"

return config
