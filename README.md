# dotfiles

Cross-platform dotfiles managed by chezmoi, with mise for tool installation. Same config files on Mac and Linux.

## Quick start

**Linux (HPC, no sudo):**
```sh
# 1. Install chezmoi (installs to ~/.local/bin/chezmoi, already on PATH)
sh -c "$(curl -fsLS https://get.chezmoi.io/lb)" --

# 2. Apply dotfiles (deploys configs + installs all tools via mise + micromamba)
chezmoi init --apply git@github-haydeni0:Haydeni0/dotfiles.git

# 3. Symlink ~/.dotfiles -> source dir for easy access
ln -sfn ~/.local/share/chezmoi ~/.dotfiles

# 4. Set git identity (not managed by chezmoi - different per user)
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

**macOS:**
```sh
# 1. Install chezmoi
brew install chezmoi

# 2. Apply dotfiles (deploys configs + Brewfile + mise tools + macOS defaults + GUI app settings)
chezmoi init --apply git@github-haydeni0:Haydeni0/dotfiles.git

# 3. Symlink ~/.dotfiles -> source dir for easy access
ln -sfn ~/.local/share/chezmoi ~/.dotfiles

# 4. Install GUI apps + fonts via Homebrew (Brewfile was deployed by step 2)
brew bundle --file=~/Brewfile

# 5. Set git identity (not managed by chezmoi - different per user)
git config --global user.name "Your Name"
git config --global user.email "you@example.com"

# 6. Manual one-time steps (see docs/setup.md for detail):
#    - Launch Karabiner-Elements once (approve driver + Accessibility/Input Monitoring)
#    - System Settings > Keyboard > Modifier Keys > swap Globe/Control
#    - System Settings > Mouse > turn OFF natural scrolling
#    - LOG OUT and back in (macOS defaults + Karabiner need it)
#    - Reload tmux config if a server was running pre-apply: tmux source-file ~/.tmux.conf
```

See [docs/setup.md](docs/setup.md) for the full guide (includes macOS system.defaults, GUI app settings, managed-PC safety notes).

## Supported platforms

- **macOS** (Mac): Homebrew packages, WezTerm, Karabiner-Elements, zsh default shell, Opt+Arrow navigation (`\e[1;3`).
- **Linux HPC (no sudo)**: Login & compute nodes with glibc ≥ 2.35, bash login default (`exec zsh`), tools via mise + micromamba, Ctrl+Arrow navigation (`\e[1;5`).
- **WSL (Windows Subsystem for Linux)**: Ubuntu/Debian on Windows, Windows Terminal/WezTerm, LF line endings enforced, Ctrl+Arrow navigation (`\e[1;5`).

## What's included

- **zsh**: history, completion, ~100 aliases, starship prompt, zoxide (frecency cd), fzf
- **zsh plugins**: autosuggestions, syntax-highlighting, history-substring-search (git-cloned, sourced with guards)
- **tmux**: dracula theme, custom keybindings (Ctrl-Space prefix, Shift-arrow window switching)
- **neovim**: lazy.nvim plugin manager
- **herdr**: agent multiplexer with tmux-compatible keybindings (Ctrl-B prefix)
- **git**: autoSetupRemote, rerere, ~60 git aliases

Keybinds and daily-use features: see the [cheatsheet](docs/cheatsheet.md).

## Architecture

- `configs/` - source of truth (plain files, NOT deployed to `$HOME`)
- `dot_*.tmpl` - chezmoi templates that deploy configs via `{{ include "configs/..." }}`
- `dot_config/nvim/` - nvim config (plain files, deployed directly - exception to configs/ pattern)
- `.chezmoiignore` - files not deployed to `$HOME` (configs/, docs/, AGENTS.md, etc.)
- `run_once_install-tools.sh.tmpl` - installs all tools on first `chezmoi apply`
- Runtime `command -v` guards in `.zshrc` handle tool availability gracefully
- Platform differences via chezmoi templates (`.bashrc` picks linux/darwin, herdr config resolves zsh path)

## Tool installation

- **mise** bootstraps and installs 17 CLI tools (starship, zoxide, fzf, nvim, bat, ripgrep, fd, jq, lazygit, gh, delta, difftastic, yazi, gdu, btop, rclone, uv) - handles archive formats, URLs, version detection, and download verification automatically
- **micromamba** installs zsh to `~/.local/bin/zsh` (compute nodes don't have system zsh; login nodes and Mac do)
- **herdr** via its own curl installer (not in mise registry)
- **zsh plugins** (autosuggestions, syntax-highlighting, history-substring-search) git-cloned to `~/.local/share/zsh/`
- **Mac only**: mise + zsh also available via Homebrew (Brewfile)

## Customize before using

- **Git identity**: `git config --global user.name` and `user.email` (not in the repo - different per user)
- **AWS_PROFILE**: edit `configs/bashrc.linux`
- **pi-node PATH**: edit `configs/zprofile`
- **SSH keys**: stays manual in `~/.ssh/` (never in repo)

## Aliases: tracked vs machine-local

- **Tracked** (synced across machines): edit `configs/zsh/aliases.zsh`, then `chezmoi apply`
- **Machine-local** (single machine, not in repo): edit `~/.zsh/aliases.local.zsh` - sourced by `~/.zshrc`
  if present, never touched by chezmoi

## What stays manual (not managed by chezmoi)

- `~/.ssh/` - keys, config, authorized_keys (secrets)
- `~/.config/rclone/rclone.conf` - cloud credentials (secrets)
- `~/.local/bin/` - CoreWeave proxies and other machine-specific binaries
- uv-managed tools (nvitop, hf, evo, graphify) - installed via `uv tool install`
- Git identity (user.name, user.email) - different per user
- `~/.zsh/aliases.local.zsh` - machine-local aliases and functions

## Testing

Run automated checks locally before committing:

```sh
mise run test    # or ./scripts/test
```

Validates:
- Syntax for all zsh and bash files (`zsh -n`, `bash -n`)
- Multi-platform template compilation (`darwin/arm64`, `darwin/amd64`, `linux/amd64`, `linux/arm64`)
- Cross-platform keybinding parity in `configs/zshrc` (Mac `\e[1;3` Opt and Linux/WSL `\e[1;5` Ctrl)
- CRLF line ending prevention
- Config format validation (JSON, TOML)

## Updating

```sh
chezmoi update    # pull + apply
```

## Adding new tools

- Mac: add to `Brewfile`, `brew bundle install`
- Linux: edit `run_once_install-tools.sh.tmpl` (adding a tool re-runs it automatically on
  `chezmoi apply` because the content hash changes). To force a re-run of unchanged
  content: `chezmoi state delete-bucket --bucket=scriptState && chezmoi apply`
- Both: commit + push

## Adopting a tool's existing config into the repo

When a tool has already written config to `$HOME` (e.g. `~/.config/<tool>/`) and you
want it tracked:

```sh
chezmoi add ~/.config/<tool>       # copies current state into the source dir
chezmoi diff                       # should be empty (source == deployed)
git add dot_config/<tool> && git commit
```

Nuances:

- Files with secrets never get added (`chezmoi add` them into `dot_config/` only after
  scrubbing, or add to `.chezmoiignore`). `chezmoi unmanaged` lists candidates you
  haven't adopted yet.
- A config needing platform differences becomes a template: `chezmoi add --template`
  then edit with `{{ if eq .chezmoi.os "darwin" }}` blocks (see
  `dot_config/herdr/config.toml.tmpl` for the pattern).
- After adopting, edits go to the source file (repo), never the deployed copy -
  `chezmoi edit ~/.config/<tool>/...` opens the source in `$EDITOR`.
