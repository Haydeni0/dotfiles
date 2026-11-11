# Setup Guide

## Linux (HPC, no sudo)

### Prerequisites
- git installed (`which git`)
- micromamba OR conda installed (for zsh - available on CoreWeave HPC nodes)
- No zsh required (installed automatically via micromamba if not system-provided)

### Install
```sh
# 1. Install chezmoi (installs to ~/.local/bin/chezmoi, already on PATH)
sh -c "$(curl -fsLS https://get.chezmoi.io/lb)" --

# 2. Apply dotfiles (deploys configs + installs all tools)
#    - mise bootstraps and installs the tools defined in the mise config
#      (dot_config/mise/config.toml)
#    - micromamba installs zsh to ~/.local/bin/zsh
#    - herdr installed from a pinned, sha256-checked release
#    - zsh plugins vendored by chezmoi to ~/.local/share/zsh/
chezmoi init --apply git@github-haydeni0:Haydeni0/dotfiles.git

# 3. Symlink ~/.dotfiles -> source dir for easy access
#    The chezmoi source dir (~/.local/share/chezmoi) IS the working repo.
#    Edit, commit, and `chezmoi apply` from there. ~/.dotfiles is a convenience alias.
ln -sfn ~/.local/share/chezmoi ~/.dotfiles

# 4. Set git identity (not managed by chezmoi)
git config --file ~/.gitconfig.local user.name "Your Name"
git config --file ~/.gitconfig.local user.email "you@example.com"

# 5. Verify (open a new shell/pane so the new .bashrc runs)
#    Shell chain: bash login -> .bash_profile -> .bashrc (env fragment, mise) -> exec zsh -> .zshenv -> .zshrc (mise, starship, zoxide, plugins)
echo $SHELL          # should be zsh
which starship       # should resolve via mise
which zoxide         # should resolve via mise
alias g              # should show git
zoxide query --list  # should show db entries
```

### What gets installed
- chezmoi → `~/.local/bin/chezmoi`
- mise (package manager) → `~/.local/bin/mise`
- starship, zoxide, fzf, nvim, bat, ripgrep, fd, jq, lazygit, gh, delta, difftastic, yazi, gdu, btop, rclone, uv → managed by mise (in `~/.local/share/mise/installs/`)
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
- New panes: bash sources `.bashrc` (env fragment, mise) → exec zsh → `.zshenv` → `.zshrc` (mise activate, starship, zoxide, plugins)

## macOS

Full reproduction: shell + dev tools + GUI apps + macOS prefs + keyboard config.
A fresh Mac following this section gets the complete setup.

### Prerequisites
- Homebrew installed (https://brew.sh)
- Admin password (for Karabiner-Elements driver install - it prompts once)

### Install
```sh
# 1. Install chezmoi
brew install chezmoi

# 2. Apply dotfiles (deploys configs + Brewfile). On a fresh Mac this first
#    apply INTENTIONALLY stops at the tool-install script - mise isn't
#    installed yet, so the script exits 1 ("run brew bundle first") and chezmoi
#    will not record it as done. Everything alphabetically earlier (all
#    dotfiles, the Brewfile) is already deployed. Continue to step 3.
#    - Karabiner config deployed to ~/.config/karabiner/ (ISO UK layout)
#    - WezTerm config deployed to ~/.config/wezterm/
#    - Brewfile deployed to ~/Brewfile (for step 3)
chezmoi init --apply git@github-haydeni0:Haydeni0/dotfiles.git

# 3. Install GUI apps + fonts + mise + btop + opencode via Homebrew (Brewfile from step 2)
#    This installs: wezterm, rectangle, dockdoor, scroll-reverser, betterdisplay,
#    obsidian, cursor, visual-studio-code, docker-desktop, zotero, whatsapp,
#    karabiner-elements, font-hack-nerd-font, mise, btop, opencode.
#    Pre-existing/managed apps are NOT touched (Brewfile has no `cleanup`
#    directive).
brew bundle --file=~/Brewfile

# 4. Re-run the apply - with mise on PATH the tool-install script now
#    succeeds: mise installs the tools defined in the mise config
#    (dot_config/mise/config.toml), herdr (pinned release), zsh plugins vendored
#    to ~/.local/share/zsh/, then the macOS defaults + GUI app settings
#    scripts run (their casks now exist).
chezmoi apply

# 5. Set git identity (not managed by chezmoi - different per user)
git config --file ~/.gitconfig.local user.name "Your Name"
git config --file ~/.gitconfig.local user.email "you@example.com"

# 6. Manual one-time steps (cannot be automated):
#    a. Karabiner-Elements: launch the app once (installs its driver, prompts for
#       Accessibility + Input Monitoring permissions in System Settings > Privacy).
#       Approve both. The config (ISO UK layout) is already in place from step 2.
#    b. fn/Control key swap: handled by the deployed Karabiner config
#       (fn -> left_control complex modification). No manual step - do NOT also
#       swap keys in System Settings, the two swaps would cancel out.
#    c. System Settings > Mouse > turn OFF "natural scrolling" (so ScrollReverser
#       can fix mouse scroll direction without conflict).
#    d. LOG OUT and back in - macOS system.defaults (separate-spaces, fn-keys,
#       mission-control keybinds) need a logout to take effect.
#    e. WARNING (macOS 26 Tahoe): "Displays have separate Spaces" OFF has a known
#       WindowServer crash-at-login bug (Apple radar 153570422). If you hit login
#       crashes after step d, re-enable separate spaces in System Settings and
#       remove the spans-displays line from run_once_macos-defaults.sh.tmpl.
#    f. DockDoor: launch the app once (it requests Accessibility access in
#       System Settings > Privacy & Security - approve it, required for window
#       switching). Keybinds are automated via run_once_macos-app-settings.sh.tmpl
#       (cmd+tab = all-apps switcher, cmd+` = same-app switcher, recentlyUsed
#       order). No GUI config needed on a fresh Mac - just grant Accessibility.

# 6. Verify (open a new terminal window after re-login)
echo $SHELL          # /bin/zsh
which starship       # via mise
which zoxide         # via mise
alias g              # shows git
zoxide query --list  # shows db entries
# Open WezTerm - should show rose-pine moon theme, Hack Nerd Font
# Launch Karabiner-Elements - ISO UK layout active
# Launch Rectangle - ctrl+opt+cmd+up maximizes window
```

### Migrating from Ghostty (manual cleanup)
WezTerm replaced Ghostty as the terminal emulator. The Brewfile has no `cleanup`
directive, so `brew bundle` installs WezTerm but does NOT remove Ghostty. After
confirming WezTerm works,
remove Ghostty manually:
```sh
brew uninstall --cask ghostty
rm -rf ~/.config/ghostty
```
`chezmoi apply` will not delete `~/.config/ghostty/` just because the source was
removed - chezmoi only manages files it knows about, not abandoned deployed dirs.

### What gets installed
- **CLI tools** (via mise): the tools defined in the mise config (`dot_config/mise/config.toml`) - in `~/.local/share/mise/installs/`
- **herdr** (pinned release, sha256-checked) - `~/.local/bin/herdr`
- **zsh plugins** (vendored by chezmoi) - `~/.local/share/zsh/`
- **GUI apps** (via Homebrew casks): wezterm, rectangle, dockdoor, scroll-reverser, betterdisplay, obsidian, cursor, visual-studio-code, docker-desktop, zotero, whatsapp, karabiner-elements
- **Fonts** (via Homebrew cask): Hack Nerd Font
- **mise + btop + opencode** (via Homebrew): tool management, resource monitor, AI coding agent (opencode brings node + npm as brew deps)
- **Configs** (via chezmoi): zsh (zshenv, zshrc, aliases), starship, herdr, git, nvim, wezterm, karabiner - real files in `~`
- **macOS defaults** (via run_once script): separate-spaces OFF, fn-keys as F-keys, mission-control ctrl+arrow keybinds disabled
- **GUI app settings** (via run_once script): Rectangle keybinds, DockDoor config, ScrollReverser mouse-only reverse

### Managed-PC notes
- The Brewfile has NO `cleanup` directive, so `brew bundle` only installs/updates the listed casks. Apps not declared here are NOT removed.
- The macOS defaults script warns if a setting is MDM-managed (it'll be reverted on sync). Check `profiles show` first; if a pref is enforced by an MDM profile, remove it from `run_once_macos-defaults.sh.tmpl`.
- Karabiner-Elements installs a driver extension - may trigger an endpoint-security alert. If blocked, keep Karabiner manual (config JSON still deploys via chezmoi; just install the app outside the Brewfile).

> Ongoing operations (updating, adding tools, what stays manual) live in [README.md](../README.md).
