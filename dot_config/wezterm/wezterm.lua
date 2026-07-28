local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.color_scheme = 'rose-pine-moon'
config.font = wezterm.font('Hack Nerd Font')
config.font_size = 14
config.window_padding = { left = 8, right = 8, top = 4, bottom = 4 }
config.window_background_opacity = 0.95
config.macos_window_background_blur = 20
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = false
config.window_decorations = 'RESIZE'
-- Auto-boot herdr. Absolute path: GUI-launched wezterm doesn't source zprofile,
-- so ~/.local/bin isn't on PATH (same constraint as ghostty).
config.default_prog = { os.getenv('HOME') .. '/.local/bin/herdr' }

return config
