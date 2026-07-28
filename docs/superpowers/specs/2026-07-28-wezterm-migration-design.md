# WezTerm Migration Design

Date: 2026-07-28
Status: Approved (pending user spec review)

## Context

The user runs herdr (a terminal multiplexer, prefix `ctrl+space`) as their primary
shell experience, auto-launched by their terminal emulator. They SSH into remote
Linux boxes (headless) which also auto-launch herdr via the remote `.zshrc`.

Current setup uses Ghostty, which auto-boots herdr via `command = herdr` in
`dot_config/ghostty/config.tmpl`. The problem: when SSHing from inside a local
herdr pane, the remote herdr nests inside the local one. herdr blocks nested
launches by default (`HERDR_ENV=1` guard) and has no native F11-style keybinding
toggle. The double-prefix-forward workaround is per-keystroke and fiddly.

The chosen solution: open a **separate terminal window** for SSH that runs plain
`ssh` with no local herdr layer. The remote boots its own herdr; no nesting.
Ghostty's `open --args --command` mechanism mangles multi-word command arguments
and wraps them in `/usr/bin/login`, making this flow unreliable. WezTerm's
`wezterm start -- ssh -t <host>` passes args natively with no shell quoting issues.

Decision: switch permanently from Ghostty to WezTerm. WezTerm is Mac-only in
this repo (Linux boxes are headless SSH targets that never run a terminal
emulator locally).

## Goals

- Auto-boot herdr in the primary terminal (preserve current workflow).
- `gssh <host>` opens a new terminal window running plain ssh (no local herdr),
  landing on the remote which boots its own herdr. No nesting.
- Everything reproducible from the dotfiles repo via `brew bundle` + `chezmoi apply`.
- Migrate the Ghostty visual settings (theme, font, padding, opacity, blur,
  option-as-alt) to WezTerm.

## Non-Goals

- No custom WezTerm keybinds (user does not use Ghostty's split keybinds; wezterm
  defaults suffice).
- No wezterm shell-integration script (herdr manages panes/cwd/agents; see
  Known Regressions).
- No Linux install of WezTerm (headless-only; WezTerm runs on Mac only).
- No templating of wezterm.lua (Mac-only; lua `os.getenv('HOME')` handles the
  one runtime path need).

## Files

### ADD: `dot_config/wezterm/wezterm.lua`

Plain lua file (not a chezmoi template), Mac-only. Deployed to
`~/.config/wezterm/wezterm.lua`. Matches the nvim exception in CLAUDE.md
(plain files deployed directly when templating is unnecessary).

```lua
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.color_scheme = 'rose-pine-moon'
config.font = wezterm.font('Hack Nerd Font')
config.font_size = 14
config.window_padding = { left = 8, right = 8, top = 4, bottom = 4 }
config.window_background_opacity = 0.95
config.macos_window_background_blur = 20
config.macos_option_as_alt = true
config.window_decorations = 'RESIZE'
-- Auto-boot herdr. Absolute path: GUI-launched wezterm doesn't source zprofile,
-- so ~/.local/bin isn't on PATH (same constraint as ghostty).
config.default_prog = { os.getenv('HOME') .. '/.local/bin/herdr' }

return config
```

Config keys verified against WezTerm docs/source:
- `color_scheme = 'rose-pine-moon'` - theme exists in wezterm's bundled schemes
  (scheme_data.rs, name "rose-pine-moon", aliases include "Rose Pine Moon (Gogh)").
- `macos_window_background_blur = 20` - default 0; 20 is the documented example
  value for a strong translucent-blur effect when combined with opacity < 1.0.
- `macos_option_as_alt = true` - treats Option as Alt (matches ghostty
  `macos-option-as-alt = true`).
- `default_prog` - replaces ghostty `command`. Bare `'herdr'` would fail on
  GUI launch (no `~/.local/bin` on PATH); `os.getenv('HOME')` resolves at lua
  runtime so the file stays plain (no chezmoi template needed).
- `window_decorations = 'RESIZE'` - removes macOS titlebar, keeps resize
  (approximates ghostty `macos-titlebar-style = tabs`).

### REMOVE: `dot_config/ghostty/config.tmpl` (entire `dot_config/ghostty/` dir)

Ghostty is being removed entirely. Its config goes with it.

### MODIFY: `Brewfile`

Swap `cask "ghostty"` -> `cask "wezterm"` (line 25).

Note: Brewfile has no `cleanup` directive (intentional - company Mac must not
uninstall MDM-managed casks). `brew bundle` will install wezterm but will NOT
uninstall ghostty. User runs `brew uninstall --cask ghostty` manually once.

### MODIFY: `configs/zshrc`

Add the `gssh` function with a runtime guard (matches existing `command -v`
guard pattern at lines 12, 43, 52). Guard ensures Linux headless boxes (no
wezterm installed) don't get a broken function reference.

```sh
# gssh: open a new WezTerm window running plain ssh (no local herdr layer).
# Remote auto-boots its own herdr; no nesting. Put ssh options before the host
# (e.g. `gssh -p 2222 user@host`), not after - ssh parses positionally.
if command -v wezterm >/dev/null 2>&1; then
    gssh() { wezterm start -- ssh -t "$@" }
fi
```

- `wezterm start --` spawns a new GUI window; `--` passes subsequent args as the
  command to run instead of `default_prog`.
- `ssh -t` forces TTY allocation so the remote herdr renders correctly.
- `"$@"` preserves args with spaces intact (native arg passing, no shell-quoting
  issues that broke the ghostty `open --args` approach).
- Does NOT shadow `ssh` - scripts/git calling `ssh` internally are unaffected.

### MODIFY: `docs/setup.md`

Update 5 ghostty references (lines 77, 84, 125, 134, 137) -> wezterm:
- Line 77: "Ghostty config deployed to ~/.config/ghostty/" -> "WezTerm config deployed to ~/.config/wezterm/"
- Line 84: cask list "ghostty" -> "wezterm"
- Line 125: "Open Ghostty - should show rose-pine moon theme" -> "Open WezTerm - should show rose-pine moon theme"
- Line 134: GUI apps list "ghostty" -> "wezterm"
- Line 137: Configs list "ghostty" -> "wezterm"

## Known Regressions (accepted)

### window-save-state

Ghostty had `window-save-state = always` (restored previous window layout on
relaunch). WezTerm has no equivalent config key. New WezTerm windows start
fresh. herdr's own session persistence (`~/.config/herdr/session.json`) covers
workspace/tab/pane state regardless, so only the terminal window geometry is
lost, not the herdr session. Accepted.

### shell-integration

Ghostty had `shell-integration = detect` (auto-detected zsh, enabled OSC 133
prompt marking, cwd reporting, command-output boundaries). WezTerm has no
config-key equivalent and does NOT auto-source its shell-integration script on
macOS (only Fedora/Debian/Arch packages auto-activate). Enabling it would
require vendoring `wezterm-shell-integration.sh` into the repo and sourcing it
in `configs/zshrc`.

Decision: skip. `default_prog = { herdr }` means herdr is the shell process
wezterm runs, not bare zsh. herdr manages its own panes, cwd, and agent
detection. WezTerm shell integration is only beneficial for bare-zsh panes
(rare for this user). The marginal value does not justify a vendored script
and an extra zshrc source line. Documented as a known omission.

## Verification

After `brew bundle` + `chezmoi apply`, in a fresh WezTerm window:
- Window opens and auto-launches herdr (default_prog works, absolute path
  resolves via `os.getenv('HOME')`).
- Theme is rose-pine-moon, font is Hack Nerd Font 14.
- Padding 8/8/4/4, opacity 0.95, blur visible.
- Option key behaves as Alt (test: Option+f jumps a word in zsh).
- `gssh <host>` opens a second WezTerm window running plain ssh; remote boots
  its own herdr; no local herdr in that window; no nesting.
- On a Linux headless box, `chezmoi apply` deploys wezterm.lua + gssh guard
  skips function definition (wezterm not installed); no errors.

## Cross-Platform

- WezTerm config (`dot_config/wezterm/wezterm.lua`): deployed to Linux headless
  boxes too, but harmless (wezterm never runs there). No `.chezmoiignore`
  entry needed.
- `gssh` function: runtime `command -v wezterm` guard skips definition on Linux
  (per CLAUDE.md "Runtime guards, not template-time" principle).
- Brewfile: Mac-only (Homebrew casks); Linux uses mise/micromamba, unaffected.
