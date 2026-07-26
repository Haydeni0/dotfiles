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
}
