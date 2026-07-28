# dotfiles

Cross-platform dotfiles managed by chezmoi, with mise for tool installation. No Nix, no bwrap, no root. Same config files on Mac and Linux.

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

See [docs/setup.md](docs/setup.md) for the full guide (includes macOS system.defaults, GUI app settings, company-PC safety notes).

## What's included

- **zsh**: history, completion, ~100 aliases, starship prompt, zoxide (frecency cd), fzf
- **zsh plugins**: autosuggestions, syntax-highlighting, history-substring-search (git-cloned, sourced with guards)
- **tmux**: dracula theme, custom keybindings (Ctrl-Space prefix, Shift-arrow window switching)
- **neovim**: lazy.nvim plugin manager
- **herdr**: agent multiplexer with tmux-compatible keybindings (Ctrl-B prefix)
- **git**: autoSetupRemote, rerere, ~60 git aliases

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
- **local-claude/local-opencode aliases**: edit `configs/zsh/aliases.zsh`
- **SSH keys**: stays manual in `~/.ssh/` (never in repo)

## What stays manual (not managed by chezmoi)

- `~/.ssh/` - keys, config, authorized_keys (secrets)
- `~/.config/rclone/rclone.conf` - cloud credentials (secrets)
- `~/.local/bin/local-claude`, `local-opencode` - CoreWeave proxies
- uv-managed tools (task, nvitop, hf, evo, graphify) - installed via `uv tool install`
- Git identity (user.name, user.email) - different per user

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
