# tmux is NOT managed by home-manager on this setup.
#
# Reason: system tmux runs OUTSIDE proot (needs kernel pty access, which
# proot's ptrace breaks). HM's `home.file` always writes through the Nix
# store (`/nix/store/...`), which only resolves INSIDE proot. So an
# HM-managed ~/.tmux.conf would dangle outside proot and tmux couldn't
# read it.
#
# Instead, ~/.tmux.conf is a direct symlink to ~/.dotfiles/home/.tmux.conf
# (created manually in the setup steps, like ~/.bashrc). The config file
# is tracked in the repo and edit-in-place, but outside HM's management.
#
# The symlink command (run once during setup, after cloning the repo):
#   ln -sfn ~/.dotfiles/home/.tmux.conf ~/.tmux.conf
{}
