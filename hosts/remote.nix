{ ... }:

{
  # Nix profile bin FIRST so Nix-managed tools take precedence over uv-tools
  # in ~/.local/bin. (nix-portable doesn't auto-add this to PATH - HM owns it here.)
  # ~/.local/bin stays on PATH for:
  # - uv-managed tools (uv tool install ruff -> ~/.local/bin/ruff)
  # - the local-claude/local-opencode/local-cursor etc. proxies
  # - micro (fallback editor, kept)
  # - task, nvitop, hf, evo, graphify (staying as uv-tools)
  home.sessionPath = [
    "$HOME/.nix-profile/bin"
    "$HOME/.local/bin"
    "$HOME/.local/share/pi-node/node-v22.23.1-linux-x64/bin"
    "$HOME/.opencode/bin"
  ];

  # nix-zsh wrapper - bwrap/Linux-only workaround for herdr pane segfault.
  # A Nix binary (herdr) fork+exec'ing another Nix binary (zsh) inside bwrap
  # segfaults; a system binary (the wrapper's /bin/bash interpreter) exec'ing
  # a Nix binary works. HM-managed so the install is reproducible (no manual
  # symlink step). Linux-only by virtue of being in hosts/remote.nix - Mac has
  # no bwrap, so no segfault; herdr config default_shell points directly at
  # Nix zsh there (no wrapper needed). See docs/herdr-learnings.md.
  home.file.".local/bin/nix-zsh" = {
    source = ./nix-zsh;
  };
}
