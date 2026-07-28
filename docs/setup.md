# Setup Guide

## Linux (HPC, no sudo)

### Prerequisites
- zsh installed (`which zsh` - if not available, ask admin or use bash)
- tmux installed (`which tmux`)
- git installed (`which git`)
- unzip installed (for yazi install: `which unzip`)

### Install
```sh
# 1. Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)"

# 2. Apply dotfiles (deploys configs + installs tools to ~/.local/bin)
chezmoi init --apply <repo-url>

# 3. Verify
zsh -c 'echo $SHELL; which starship; which zoxide; zoxide query --list'
```

### What gets installed
- mise (package manager) → `~/.local/bin/mise`
- starship, zoxide, fzf, nvim, bat, ripgrep, fd, jq, lazygit, gh, delta, yazi, gdu, btop, rclone, uv → managed by mise (in `~/.local/share/mise/installs/`)
- herdr → `~/.local/bin/herdr`
- zsh → `~/.local/bin/zsh` (via micromamba on Linux if not system-provided)
- zsh plugins → `~/.local/share/zsh/`
- Configs → `~` (real files, managed by chezmoi)

### Notes
- No /nix/store dependency
- No bwrap/proot/namespace overhead
- Works on login nodes AND compute nodes (same NFS home)
- mise handles tool archives/URLs/versions automatically (no brittle per-tool install scripts)
- zsh installed via micromamba if not system-provided (compute nodes)

## macOS

### Prerequisites
- Homebrew installed (https://brew.sh)
- unzip installed (macOS has it by default)

### Install
```sh
# 1. Install chezmoi
brew install chezmoi

# 2. Apply dotfiles (deploys configs + installs zsh plugins + herdr)
chezmoi init --apply <repo-url>

# 3. Install packages via Homebrew
brew bundle --file=~/Brewfile

# 4. Verify
zsh -c 'echo $SHELL; which starship; which zoxide; zoxide query --list'
```

## Updating
```sh
chezmoi update    # pull + apply
# or
chezmoi git pull && chezmoi apply
```

## Adding new tools
- Mac: add to Brewfile, `brew bundle install`
- Linux: add to run_once_install-tools.sh.tmpl, `chezmoi state delete-bucket --bucket=entryState && chezmoi apply`
- Both: commit + push

## What stays manual (not managed by chezmoi)
- `~/.ssh/` - keys, config, authorized_keys (secrets, never in repo)
- `~/.config/rclone/rclone.conf` - cloud credentials (secrets)
- `~/.local/bin/local-claude`, `local-opencode` - CoreWeave proxies
- uv-managed tools (task, nvitop, hf, evo, graphify) - installed via `uv tool install`
