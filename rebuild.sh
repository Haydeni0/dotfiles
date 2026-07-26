#!/usr/bin/env bash
# Re-apply the home-manager config after editing files in this repo.
# Run from anywhere: ./rebuild.sh  (or: bash ~/.dotfiles/rebuild.sh)
set -euo pipefail

# Resolve the repo dir via ~/.dotfiles symlink (stable regardless of where
# the repo was cloned). Re-create the symlink idempotently in case it's
# missing (first run on a fresh machine, or if the checkout moved).
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ln -sfn "$DIR" ~/.dotfiles

# Pick nix launcher + hostname by platform.
case "$(uname -s)" in
  Darwin)
    NIX=nix
    HOST=mac
    ;;
  Linux)
    # nix-portable on rootless remote; plain nix if installed (e.g. NixOS, or a machine with root).
    if command -v nix >/dev/null 2>&1; then
      NIX=nix
    else
      NIX=~/.local/bin/nix-portable
    fi
    HOST=remote
    ;;
  *)
    echo "Unsupported OS: $(uname -s)" >&2
    exit 1
    ;;
esac

# Apply the home-manager config for the host.
$NIX run github:nix-community/home-manager/release-26.05#home-manager -- \
  switch --flake "$DIR#hayden@$HOST"
