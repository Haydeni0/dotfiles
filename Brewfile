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
# No `cleanup` directive: `brew bundle` must never uninstall casks that
# aren't listed here (e.g. pre-existing/managed installs). It
# installs/updates listed casks only.
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
