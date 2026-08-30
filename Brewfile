# Package manager (installs all CLI tools via mise activate)
brew "mise"

# Shell (system zsh on Mac, but brew provides current version)
brew "zsh"

# btop - mise's aqua backend has no darwin build, so Mac gets btop via brew.
# (Linux gets btop via mise in run_once_install-tools.sh.tmpl.)
brew "btop"

# opencode - AI coding agent. brew version (1.x) is current; mise registry is
# way behind (0.0.48). Uses ripgrep via PATH (mise provides rg). Kept as brew
# for the current version. Brings node + npm as brew deps.
brew "opencode"
brew "node"

# Note: most CLI tools (starship, zoxide, fzf, bat, ripgrep, fd, etc.)
# are installed via mise (run_once_install-tools.sh.tmpl) on both platforms.
# Homebrew is used for mise + zsh only on Mac. Add more brew entries here
# if you prefer Homebrew for specific tools.

# --- GUI apps (casks) ---
# No `cask_args` or `cleanup` directive: on a company Mac, brew must NOT
# uninstall casks that aren't listed here (Office, 1Password, Falcon, etc.
# are company-managed). `brew bundle` installs/updates listed casks only.
cask "wezterm"
cask "rectangle"
cask "dockdoor"
cask "scroll-reverser"
cask "betterdisplay"
cask "obsidian"
cask "cursor"
cask "visual-studio-code"
cask "docker-desktop"
cask "zotero"
cask "whatsapp"

# --- Keyboard ---
# Karabiner-Elements: keyboard remapping (ISO UK layout). Config deployed to
# ~/.config/karabiner/ via chezmoi (dot_config/private_karabiner/); reload kicks via
# run_onchange_reload-karabiner.sh.tmpl.
# Installed via cask (not the nix-darwin service - this is chezmoi, no nix-darwin).
cask "karabiner-elements"

# --- Fonts ---
cask "font-hack-nerd-font"

# --- Company-managed apps NOT declared here (left manual) ---
# Microsoft Office, 1Password, Intune Company Portal, Falcon (CrowdStrike),
# FortiClient, Microsoft Defender, Chrome, Notion, Slack, Zoom, OneDrive,
# Windows App. These are deployed by employer MDM - declaring them here risks
# conflicts and `brew bundle` won't manage them anyway. Reinstall via IT/MDM
# on a fresh Mac.
