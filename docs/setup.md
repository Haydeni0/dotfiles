# Setup Guide

## Linux (HPC, no sudo)

### Prerequisites
- tmux installed (`which tmux`)
- git installed (`which git`)
- micromamba OR conda installed (for zsh - available on CoreWeave HPC nodes)
- No zsh required (installed automatically via micromamba if not system-provided)

### Install
```sh
# 1. Install chezmoi (installs to ~/bin/chezmoi)
sh -c "$(curl -fsLS https://get.chezmoi.io)"

# 2. Add ~/bin to PATH for this session (chezmoi installs here)
export PATH="$HOME/bin:$PATH"

# 3. Apply dotfiles (deploys configs + installs all tools)
#    - mise bootstraps and installs 16 CLI tools
#    - micromamba installs zsh to ~/.local/bin/zsh
#    - herdr installed via curl
#    - zsh plugins git-cloned
chezmoi init --apply git@github-haydeni0:Haydeni0/dotfiles.git

# 4. Set git identity (not managed by chezmoi)
git config --global user.name "Your Name"
git config --global user.email "you@example.com"

# 5. Verify (open a new tmux pane so the new .bashrc runs)
#    Shell chain: bash login -> .bash_profile -> .bashrc (PATH, mise, tmux) -> exec zsh -> .zshrc (mise, starship, zoxide, plugins)
echo $SHELL          # should be zsh
which starship       # should resolve via mise
which zoxide         # should resolve via mise
alias g              # should show git
zoxide query --list  # should show db entries
```

### What gets installed
- chezmoi → `~/bin/chezmoi`
- mise (package manager) → `~/.local/bin/mise`
- starship, zoxide, fzf, nvim, bat, ripgrep, fd, jq, lazygit, gh, delta, yazi, gdu, btop, rclone, uv → managed by mise (in `~/.local/share/mise/installs/`)
- herdr → `~/.local/bin/herdr`
- zsh → `~/.local/bin/zsh` (via micromamba - shared on NFS home, available on all nodes)
- zsh plugins → `~/.local/share/zsh/`
- Configs → `~` (real files, managed by chezmoi)

### Notes
- No /nix/store dependency
- No bwrap/proot/namespace overhead
- Works on login nodes AND compute nodes (same NFS home)
- mise handles tool archives/URLs/versions automatically (no brittle per-tool install scripts)
- zsh installed via micromamba to the shared NFS home (one install, available on all nodes)
- New tmux panes: bash sources `.bashrc` → sets PATH → starts tmux → exec zsh → sources `.zshrc` (mise activate, starship, zoxide, plugins)

## macOS

### Prerequisites
- Homebrew installed (https://brew.sh)

### Install
```sh
# 1. Install chezmoi
brew install chezmoi

# 2. Apply dotfiles (deploys configs + installs mise tools, zsh plugins, herdr)
chezmoi init --apply git@github-haydeni0:Haydeni0/dotfiles.git

# 3. Install Homebrew packages (mise + zsh)
brew bundle --file=~/Brewfile

# 4. Set git identity
git config --global user.name "Your Name"
git config --global user.email "you@example.com"

# 5. Verify
echo $SHELL
which starship
which zoxide
alias g
```

## Updating
```sh
chezmoi update    # pull + apply
# or
chezmoi git pull && chezmoi apply
```

## Adding new tools
- Mac: add to Brewfile, `brew bundle install`
- Linux: edit `run_once_install-tools.sh.tmpl` (adding a tool re-runs it automatically on
  `chezmoi apply` because the content hash changes). To force a re-run of unchanged
  content: `chezmoi state delete-bucket --bucket=scriptState && chezmoi apply`
- Both: commit + push

## What stays manual (not managed by chezmoi)
- `~/.ssh/` - keys, config, authorized_keys (secrets, never in repo)
- `~/.config/rclone/rclone.conf` - cloud credentials (secrets)
- `~/.local/bin/local-claude`, `local-opencode` - CoreWeave proxies
- uv-managed tools (task, nvitop, hf, evo, graphify) - installed via `uv tool install`
- Git identity (user.name, user.email) - different per user
