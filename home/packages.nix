{ pkgs, lib, herdrPkg, ... }:

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
  ] ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
    # herdr from its own flake input - works on Mac (no proot).
    # On Linux with nix-portable/proot, the Nix herdr segfaults when spawning
    # panes (proot fork+exec bug). Install standalone: curl -fsSL https://herdr.dev/install.sh | sh
    herdrPkg
  ];
}
