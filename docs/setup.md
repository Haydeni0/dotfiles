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

Full reproduction: shell + dev tools + GUI apps + macOS prefs + keyboard config.
A fresh work Mac following this section gets the complete setup.

### Prerequisites
- Homebrew installed (https://brew.sh)
- Admin password (for Karabiner-Elements driver install - it prompts once)

### Install
```sh
# 1. Install chezmoi
brew install chezmoi

# 2. Install GUI apps + fonts + mise + zsh via Homebrew (Brewfile)
#    This installs: ghostty, rectangle, alt-tab, scroll-reverser, betterdisplay,
#    obsidian, cursor, visual-studio-code, docker-desktop, zotero, whatsapp,
#    karabiner-elements, font-hack-nerd-font, mise, zsh.
#    Company-managed apps (Office, 1Password, Falcon, etc.) are NOT touched.
brew bundle --file=~/Brewfile

# 3. Apply dotfiles (deploys configs + runs install scripts)
#    - mise bootstraps and installs 16 CLI tools (starship, zoxide, fzf, etc.)
#    - herdr installed via curl
#    - zsh plugins git-cloned
#    - Karabiner config deployed to ~/.config/karabiner/ (ISO UK layout)
#    - Ghostty config deployed to ~/.config/ghostty/
#    - macOS system.defaults script runs (separate-spaces, fn-keys, mission-control keybinds)
#    - GUI app settings script runs (Rectangle/AltTab/ScrollReverser keybinds)
chezmoi init --apply git@github-haydeni0:Haydeni0/dotfiles.git

# 4. Set git identity (not managed by chezmoi - different per user)
git config --global user.name "Your Name"
git config --global user.email "you@example.com"

# 5. Manual one-time steps (cannot be automated):
#    a. Karabiner-Elements: launch the app once (installs its driver, prompts for
#       Accessibility + Input Monitoring permissions in System Settings > Privacy).
#       Approve both. The config (ISO UK layout) is already in place from step 3.
#       You can also use Karabiner for the Globe<->Control key swap (below).
#    b. Globe<->Control key swap: no stable `defaults write` exists (lives in a
#       keyboard-specific ByHost plist). Either:
#         - System Settings > Keyboard > Modifier Keys > swap Globe and Control, OR
#         - Add it as a Karabiner-Elements complex modification (config in this repo).
#    c. System Settings > Mouse > turn OFF "natural scrolling" (so ScrollReverser
#       can fix mouse scroll direction without conflict).
#    d. LOG OUT and back in - macOS system.defaults (separate-spaces, fn-keys,
#       mission-control keybinds) need a logout to take effect.
#    e. WARNING (macOS 26 Tahoe): "Displays have separate Spaces" OFF has a known
#       WindowServer crash-at-login bug (Apple radar 153570422). If you hit login
#       crashes after step d, re-enable separate spaces in System Settings and
#       remove the spans-displays line from run_once_macos-defaults.sh.tmpl.

# 6. Verify (open a new terminal window after re-login)
echo $SHELL          # /bin/zsh or /opt/homebrew/bin/zsh
which starship       # via mise
which zoxide         # via mise
alias g              # shows git
zoxide query --list  # shows db entries
# Open Ghostty - should show rose-pine moon theme, Hack Nerd Font
# Launch Karabiner-Elements - ISO UK layout active
# Launch Rectangle - ctrl+opt+cmd+up maximizes window
```

### What gets installed
- **CLI tools** (via mise): starship, zoxide, fzf, nvim, bat, ripgrep, fd, jq, lazygit, gh, delta, yazi, gdu, btop, rclone, uv - in `~/.local/share/mise/installs/`
- **herdr** (via curl) - `~/.local/bin/herdr`
- **zsh plugins** (git-cloned) - `~/.local/share/zsh/`
- **GUI apps** (via Homebrew casks): ghostty, rectangle, alt-tab, scroll-reverser, betterdisplay, obsidian, cursor, visual-studio-code, docker-desktop, zotero, whatsapp, karabiner-elements
- **Fonts** (via Homebrew cask): Hack Nerd Font
- **mise + zsh** (via Homebrew): for tool management + current zsh
- **Configs** (via chezmoi): zsh, tmux, starship, herdr, git, nvim, ghostty, karabiner - real files in `~`
- **macOS defaults** (via run_once script): separate-spaces OFF, fn-keys as F-keys, mission-control ctrl+arrow keybinds disabled
- **GUI app settings** (via run_once script): Rectangle keybinds, AltTab behavior, ScrollReverser mouse-only reverse

### Company-PC notes
- The Brewfile has NO `cleanup` directive, so `brew bundle` only installs/updates the listed casks. Company-managed apps (Microsoft Office, 1Password, Intune Company Portal, Falcon/CrowdStrike, FortiClient, Microsoft Defender, Chrome, Notion, Slack, Zoom) are NOT removed.
- The macOS defaults script warns if a setting is MDM-managed (it'll be reverted on sync). Check `profiles show` first; if a pref is enforced by your employer's MDM, remove it from `run_once_macos-defaults.sh.tmpl`.
- Karabiner-Elements installs a driver extension - may trigger an EDR (Falcon) alert. If blocked, keep Karabiner manual (config JSON still deploys via chezmoi; just install the app outside the Brewfile).

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
