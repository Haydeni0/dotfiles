# dotfiles

Cross-platform dotfiles managed by chezmoi. No Nix, no bwrap, no root. Same config files on Mac and Linux.

## Quick start

**Linux (HPC, no sudo):**
```sh
sh -c "$(curl -fsLS get.chezmoi.io)"
chezmoi init --apply git@github-haydeni0:Haydeni0/dotfiles.git
```

**macOS:**
```sh
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
- `.chezmoiignore` - files not deployed to `$HOME` (configs/, docs/, Brewfile, etc.)
- Runtime `command -v` guards in `.zshrc` handle tool availability gracefully
- Platform differences via chezmoi templates (`.bashrc` picks linux/darwin, herdr config resolves zsh path)
- Tools: Homebrew (Mac) or curl/git-clone (Linux) - no `/nix/store` dependency

## Customize before using

- **Git identity**: edit `configs/gitconfig` (add `user.name`/`user.email`)
- **AWS_PROFILE**: edit `configs/bashrc.linux`
- **pi-node PATH**: edit `configs/zprofile`
- **local-claude/local-opencode aliases**: edit `configs/zsh/aliases.zsh`
- **SSH keys**: stays manual in `~/.ssh/` (never in repo)

## What stays manual (not managed by chezmoi)

- `~/.ssh/` - keys, config, authorized_keys (secrets)
- `~/.config/rclone/rclone.conf` - cloud credentials (secrets)
- `~/.local/bin/local-claude`, `local-opencode` - CoreWeave proxies
- uv-managed tools (task, nvitop, hf, evo, graphify) - installed via `uv tool install`

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
