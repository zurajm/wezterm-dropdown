-- dropdown_base.lua
-- Self-contained shared defaults for the dropdown-related WezTerm configs.
local wezterm = require 'wezterm'

local M = {}

function M.apply(config)
  config.color_scheme = 'Dracula'
  config.window_background_opacity = 0.85
  config.font = wezterm.font_with_fallback({
    'JetBrainsMono NFM',
    'Symbols Nerd Font Mono',
  })
  config.font_size = 11.0
  config.custom_block_glyphs = false
  config.harfbuzz_features = { 'calt=1', 'liga=1', 'clig=1' }
end

return M
