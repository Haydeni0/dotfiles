{ config, ... }:

{
  # nvim config lives in the repo, edit-in-place (no rebuild for nvim lua edits).
  # ~/.dotfiles is a symlink to ~/dotfiles (the git checkout).
  home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/.dotfiles/home/.config/nvim";
}
