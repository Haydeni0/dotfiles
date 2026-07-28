# dotfiles

Cross-platform dotfiles managed by chezmoi, with mise for tool installation. No Nix, no bwrap, no root. Same config files on Mac and Linux.

## Quick start

**Linux (HPC, no sudo):**
```sh
# 1. Install chezmoi (installs to ~/bin/chezmoi)
sh -c "$(curl -fsLS https://get.chezmoi.io)"

# 2. Add ~/bin to PATH (chezmoi installs here, not ~/.local/bin)
export PATH="$HOME/bin:$PATH"

# 3. Apply dotfiles (deploys configs + installs all tools via mise + micromamba)
chezmoi init --apply git@github-haydeni0:Haydeni0/dotfiles.git

# 4. Set git identity (not managed by chezmoi - different per user)
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

**macOS:**
```sh
# 1. Install chezmoi + Homebrew packages (mise + zsh)
brew install chezmoi
chezmoi init --apply git@github-haydeni0:Haydeni0/dotfiles.git
brew bundle --file=~/Brewfile
```

See [docs/setup.md](docs/setup.md) for the full guide.

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

- **mise** bootstraps and installs 16 CLI tools (starship, zoxide, fzf, nvim, bat, ripgrep, fd, jq, lazygit, gh, delta, yazi, gdu, btop, rclone, uv) - handles archive formats, URLs, version detection, and download verification automatically
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
