{ config, ... }:

{
  # nvim config lives in the repo, edit-in-place (no rebuild for nvim lua edits).
  # ~/.dotfiles is a symlink to ~/gitrepos/dotfiles (created in Task 9 install step).
  home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/.dotfiles/home/.config/nvim";
}
