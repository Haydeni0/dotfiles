# Package manager (installs all CLI tools via mise activate)
brew "mise"

# btop - mise's aqua backend has no darwin build, so Mac gets btop via brew.
# (Linux gets btop via mise in run_once_install-tools.sh.tmpl.)
brew "btop"

# opencode - AI coding agent. brew version (1.x) is current; mise registry is
# way behind (0.0.48). Uses ripgrep via PATH (mise provides rg). Kept as brew
# for the current version. Brings node + npm as brew deps.
brew "opencode"

# Note: CLI tools (starship, zoxide, fzf, bat, ripgrep, fd, etc.) live in
# the mise config (dot_config/mise/config.toml.tmpl), installed by
# run_once_install-tools.sh.tmpl on both platforms. Homebrew carries mise,
# btop (no darwin build in mise's aqua backend), opencode (brew is current),
# and the GUI casks below.

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
