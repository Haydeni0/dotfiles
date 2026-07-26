{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # CLI tools (video's set + user's)
    ripgrep
    fd
    fzf
    jq
    lazygit
    neovim
    bat
    gh
    delta
    uv
    yazi
    gdu
    rsync
  ];
}
