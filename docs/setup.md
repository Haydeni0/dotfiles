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
- starship, zoxide, fzf, nvim, bat, ripgrep, fd, jq, lazygit, gh, delta, yazi, gdu, btop, rclone, uv, herdr → ~/.local/bin
- zsh plugins → ~/.local/share/zsh/
- Configs → ~ (real files, not symlinks to /nix/store)

### Notes
- No /nix/store dependency
- No bwrap/proot/namespace overhead
- Works on login nodes AND compute nodes (same NFS home)
- nvim installed via appimage extraction (no FUSE needed)

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
