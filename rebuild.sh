#!/usr/bin/env bash
# Re-apply the home-manager config after editing files in this repo.
# Run from anywhere: ./rebuild.sh  (or: bash ~/.dotfiles/rebuild.sh)
set -euo pipefail

# Resolve the repo dir via ~/.dotfiles symlink (stable regardless of where
# the repo was cloned). Re-create the symlink idempotently in case it's
# missing (first run on a fresh machine, or if the checkout moved).
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ln -sfn "$DIR" ~/.dotfiles

# Apply the home-manager config for the remote host.
# Uses nix-portable (rootless Nix) - no sudo, no /nix daemon.
~/.local/bin/nix-portable nix run github:nix-community/home-manager/release-26.05#home-manager -- \
  switch --flake "$DIR#hayden@remote"
