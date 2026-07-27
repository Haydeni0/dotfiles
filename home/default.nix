{
  home.username = "hayden.dorahy";
  home.homeDirectory = "/mnt/home/hayden.dorahy";
  home.stateVersion = "24.11";

  imports = [
    ./shell.nix
    ./packages.nix
    ./git.nix
    ./tmux.nix
    ./editor.nix
    ./zoxide.nix
    ./btop.nix
    ./rclone.nix
    ./herdr.nix
  ];
}
