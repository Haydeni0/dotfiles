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

    # herdr from its own flake input (not nixpkgs)
    herdrPkg
  ];
}
