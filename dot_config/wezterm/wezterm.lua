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
-- Never prompt on close. Panes are herdr's, not WezTerm's, so there is nothing
-- WezTerm can warn about that is worth a dialog.
config.window_close_confirmation = 'NeverPrompt'
-- The tab bar's x button ignores key assignments and checks this list instead.
-- WezTerm reports the pane's foreground process, so a gssh window reads as
-- 'ssh' (its sh retry wrapper is only in front between reconnects).
config.skip_close_confirmation_for_processes_named = {
    'bash', 'sh', 'zsh', 'fish', 'tmux', 'nu', 'herdr', 'ssh',
}
-- Auto-boot herdr. Absolute path: GUI-launched wezterm doesn't source zprofile,
-- so ~/.local/bin isn't on PATH (same constraint as ghostty).
config.default_prog = { os.getenv('HOME') .. '/.local/bin/herdr' }

-- Cycle WezTerm windows with cmd+\ and cmd+` (ISO UK + Karabiner reshuffling
-- move these keys around). WezTerm swallows unhandled cmd combos so macOS's
-- native cycle-windows never fires; bind both to WezTerm's own action.
config.keys = {
    { key = '\\', mods = 'CMD', action = wezterm.action.ActivateWindowRelative(1) },
    { key = '\\', mods = 'CMD|SHIFT', action = wezterm.action.ActivateWindowRelative(-1) },
    { key = '`', mods = 'CMD', action = wezterm.action.ActivateWindowRelative(1) },
    { key = '`', mods = 'CMD|SHIFT', action = wezterm.action.ActivateWindowRelative(-1) },
    -- cmd+w closes the tab outright; the default binding sets confirm = true.
    { key = 'w', mods = 'CMD', action = wezterm.action.CloseCurrentTab { confirm = false } },
    -- cmd+arrows: jump to line start/end (readline ctrl+a/ctrl+e). WezTerm
    -- doesn't bind cmd+arrows by default so zsh never sees a line-jump action.
    { key = 'LeftArrow', mods = 'CMD', action = wezterm.action.SendKey { key = 'a', mods = 'CTRL' } },
    { key = 'RightArrow', mods = 'CMD', action = wezterm.action.SendKey { key = 'e', mods = 'CTRL' } },
    -- cmd+backspace: delete to start of line (readline ctrl+u)
    { key = 'Backspace', mods = 'CMD', action = wezterm.action.SendKey { key = 'u', mods = 'CTRL' } },
    -- # arrives as opt+3 (Karabiner: backslash key -> opt+3 = # on UK layout).
    -- With Option=Meta (send_composed_key=false, above), wezterm emits ESC+3
    -- which vim reads as Esc (normal mode) and shells read as cancel. Send the
    -- literal char so # types normally. Keeps opt+arrow word-move intact.
    { key = '3', mods = 'ALT', action = wezterm.action.SendKey { key = '#' } },
}

return config
