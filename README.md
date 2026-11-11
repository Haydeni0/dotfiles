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
git config --file ~/.gitconfig.local user.name "Your Name"
git config --file ~/.gitconfig.local user.email "you@example.com"
```

**macOS:**
```sh
# 1. Install chezmoi
brew install chezmoi

# 2. Apply dotfiles (deploys configs + Brewfile). On a fresh Mac this first
#    apply intentionally stops at the tool-install script - mise isn't
#    installed yet (it comes from brew bundle in step 4). See docs/setup.md
#    for the full fresh-Mac sequence.
chezmoi init --apply git@github-haydeni0:Haydeni0/dotfiles.git

# 3. Symlink ~/.dotfiles -> source dir for easy access
ln -sfn ~/.local/share/chezmoi ~/.dotfiles

# 4. Install GUI apps + fonts + mise via Homebrew (Brewfile was deployed by step 2)
brew bundle --file=~/Brewfile

# 5. Re-run the apply - the tool-install script now succeeds (mise on PATH)
#    and installs the mise tools, herdr, and the vendored zsh plugins
chezmoi apply

# 6. Set git identity (not managed by chezmoi - different per user)
git config --file ~/.gitconfig.local user.name "Your Name"
git config --file ~/.gitconfig.local user.email "you@example.com"

# 6. Manual one-time steps (see docs/setup.md for detail):
#    - Launch Karabiner-Elements once (approve driver + Accessibility/Input Monitoring)
#    - System Settings > Mouse > turn OFF natural scrolling
#    - LOG OUT and back in (macOS defaults + Karabiner need it)
```

See [docs/setup.md](docs/setup.md) for the full guide (includes macOS system.defaults, GUI app settings, managed-PC safety notes).

## Supported platforms

- **macOS** (Mac): Homebrew packages, WezTerm, Karabiner-Elements, Opt+Arrow navigation (`\e[1;3`).
- **Linux HPC (no sudo)**: Login & compute nodes with glibc ≥ 2.35, bash login default (`exec zsh`), tools via mise + micromamba, Ctrl+Arrow navigation (`\e[1;5`).
- **WSL (Windows Subsystem for Linux)**: Ubuntu/Debian on Windows, Windows Terminal/WezTerm, LF line endings enforced, Ctrl+Arrow navigation (`\e[1;5`).

## What's included

- **zsh**: history, completion, ~100 aliases, starship prompt, zoxide (frecency cd), fzf
- **zsh plugins**: autosuggestions, syntax-highlighting, history-substring-search (vendored by chezmoi externals, sourced with guards)
- **neovim**: lazy.nvim plugin manager
- **herdr**: agent multiplexer (`ctrl+space` prefix)
- **git**: autoSetupRemote, rerere, ~60 git aliases

Keybinds and daily-use features: see the [cheatsheet](docs/cheatsheet.md).

## Architecture

- `configs/` - templated fragments a template does real work on (bashrc OS variants, herdr.toml, env.sh.tmpl) - NOT deployed to `$HOME`
- `dot_*` / `dot_config/` - plain config sources deployed directly (no template needed)
- `dot_*.tmpl` - chezmoi templates needing per-platform rendering
- `.chezmoiexternal.toml` - pinned zsh plugin archives vendored to `~/.local/share/zsh/`
- `.chezmoiignore` - files not deployed to `$HOME` (configs/, docs/, AGENTS.md, etc.)
- `run_once_install-tools.sh.tmpl` - installs tools on first `chezmoi apply`
- Runtime `command -v` guards in `.zshrc` handle tool availability gracefully
- Platform differences via chezmoi templates (`.bashrc` picks linux/darwin, herdr config resolves zsh path)

## Tool installation

- **mise** installs the tools defined in the mise config (`dot_config/mise/config.toml`) at exact versions; `mise.lock` beside it pins each download's sha256 per platform
- **micromamba** installs zsh to `~/.local/bin/zsh` (compute nodes don't have system zsh; login nodes and Mac do)
- **herdr** pinned GitHub release binary, sha256-checked by the install script (not in mise registry)
- **zsh plugins** (autosuggestions, syntax-highlighting, history-substring-search) vendored to `~/.local/share/zsh/` via `.chezmoiexternal.toml`
- **Mac only**: mise, btop, opencode, and GUI apps via Homebrew (Brewfile)

## Customize before using

- **Git identity**: `git config --file ~/.gitconfig.local user.name` and `user.email` (not in the repo - different per user)
- **AWS_PROFILE**: edit `configs/env.sh.tmpl`
- **SSH keys**: stays manual in `~/.ssh/` (never in repo)

## Aliases: tracked vs machine-local

- **Tracked** (synced across machines): edit `dot_zsh/aliases.zsh`, then `chezmoi apply`
- **Machine-local** (single machine, not in repo): edit `~/.zsh/aliases.local.zsh` - sourced by `~/.zshrc`
  if present, never touched by chezmoi

## What stays manual (not managed by chezmoi)

- `~/.ssh/` - keys, config, authorized_keys (secrets)
- `~/.config/rclone/rclone.conf` - cloud credentials (secrets)
- `~/.local/bin/` - CoreWeave proxies and other machine-specific binaries
- uv-managed tools (nvitop, hf, evo, graphify) - installed via `uv tool install`
- Git identity (user.name, user.email) - different per user
- `~/.zsh/aliases.local.zsh` - machine-local aliases and functions
- `~/.zshenv.local` - machine-local env vars (`~/.zshenv` itself is repo-managed: env/PATH via `configs/env.sh.tmpl`)

## Testing and upkeep tasks

```sh
mise run test    # or ./scripts/test - automated checks, run before committing
mise run sync    # pull --ff-only + chezmoi apply + test - the post-pull dance in one command
mise run doctor  # chezmoi doctor + drift summary
```

Run these from the chezmoi source dir - the tasks live in the repo-level `mise.toml`.
What `test` validates: see the testing section of [AGENTS.md](AGENTS.md) (single owner of the test-coverage description).

`sync` replaces the manual `chezmoi update` (pull + apply) by also running tests.

## Adding new tools

- Both platforms: add the tool at an exact version to `dot_config/mise/config.toml`, `chezmoi apply`,
  then `mise lock --global && chezmoi re-add ~/.config/mise/mise.lock` and `mise install`
  (on Mac, resolve mise first: `brew bundle` - see Brewfile)
- Homebrew only for GUI casks and tools with no darwin build in mise (e.g. btop, opencode)
- Commit + push

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
