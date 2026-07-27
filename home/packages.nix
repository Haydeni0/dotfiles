{ pkgs, herdrPkg, ... }:

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
    # zsh plugin: up/down arrow search history by typed prefix
    zsh-history-substring-search
  ] ++ [
    # agent multiplexer (from flake input - not in nixpkgs)
    herdrPkg
  ];
}
