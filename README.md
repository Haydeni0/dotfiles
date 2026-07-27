# dotfiles

A declarative, reproducible terminal environment managed with Nix (home-manager + flakes), running rootlessly on a shared Linux cluster (no root, no `/nix` daemon). One repo, one command, and a fresh remote ends up configured the same way every time.

Modeled on [kunchenguid/dotfiles](https://github.com/kunchenguid/dotfiles) (walkthrough: https://youtu.be/5N-okeDdIuI), adapted for a rootless Linux remote instead of a Mac.

## What you get

Running `home-manager switch` builds:

- **Shell** - zsh (autosuggestion + syntaxHighlighting, no oh-my-zsh) + starship prompt + tmux auto-start
- **Editor** - Neovim (lazy.nvim, rose-pine moon theme, oil.nvim, snacks.nvim, neogit, gitsigns, which-key)
- **Tools** (Nix-managed, in `~/.nix-profile/bin/`):
  - ripgrep, fd, fzf, jq, bat, gh, delta, lazygit
  - uv (Python), yazi (file manager), gdu (disk usage), btop (resource monitor), zoxide (smart cd)
  - rclone (cloud sync), rsync, tmux
- **git** - `push.autoSetupRemote` + `rerere.enabled` only (no user/credential in the flake)
- **tmux** - ported from the user's `.tmux.conf` (Ctrl-Space prefix, dracula theme, F11 nested toggle, vi copy mode)

## Architecture

```
flake.nix              # inputs: nixpkgs-26.05 + home-manager release-26.05
flake.lock             # pinned versions -> reproducible
home/
  default.nix          # imports all modules + username/homeDirectory/stateVersion
  shell.nix            # zsh + starship + aliases + EDITOR=nvim
  packages.nix         # home.packages (CLI tools)
  git.nix              # programs.git (push + rerere only)
  tmux.nix             # empty module (tmux managed via direct symlink - see "NOT managed by Nix")
  .tmux.conf           # tmux config (tracked in repo, symlinked to ~/.tmux.conf outside HM)
  editor.nix           # mkOutOfStoreSymlink -> home/.config/nvim (edit-in-place)
  zoxide.nix           # programs.zoxide
  btop.nix             # programs.btop
  rclone.nix           # programs.rclone (binary + completion only; config stays manual)
  .config/nvim/        # nvim config (adopted from video, edit-in-place via symlink)
  .tmux.conf           # tmux config (direct symlink, outside HM)
hosts/
  remote.nix           # remote-specific: sessionPath (~/.nix-profile/bin first, then ~/.local/bin)
docs/
  specs/               # design doc
  plans/               # implementation plan
```

**Two config-linking mechanisms** (same as the video):
1. `programs.<x>` (zsh, starship, git, btop, zoxide, rclone) - Nix-expressed, written to the immutable Nix store, symlinked into place. Edit Nix + `switch` to change.
2. `mkOutOfStoreSymlink` (nvim only) - real files live in the repo, `~/.config/nvim` symlinks to `~/.dotfiles/home/.config/nvim`. Edit-in-place, no rebuild.
3. **Direct symlink, outside HM** (tmux, `.bashrc`) - `~/.tmux.conf` -> `~/.dotfiles/home/.tmux.conf` directly. System tmux runs outside proot (needs kernel pty access); HM's store-resident symlinks don't resolve there, so tmux config is managed manually like `.bashrc`. Tracked in the repo, edit-in-place.

## Prerequisites

- **Linux x86_64** (tested on Ubuntu 22.04, CoreWeave Slurm cluster)
- **No root required** - this setup uses [nix-portable](https://github.com/DavHau/nix-portable) (rootless, no `/nix`, no daemon)
- **bash as login shell** - the setup uses a bash -> `exec zsh -l` bridge (no `chsh` needed; zsh isn't in `/etc/shells` on this cluster)

## Fresh-machine setup

On a brand new Linux box, from a bare clone of this repo:

```sh
git clone git@github-haydeni0:Haydeni0/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### Step 1: Install nix-portable (rootless Nix)

```sh
curl -L -o ~/.local/bin/nix-portable https://github.com/DavHau/nix-portable/releases/latest/download/nix-portable-x86_64
chmod +x ~/.local/bin/nix-portable
```

Verify:
```sh
~/.local/bin/nix-portable nix --version
# -> nix (Nix) 2.20.6 (first run takes ~2 min to self-extract)
```

Create convenience symlinks (nix-portable is a multi-call binary):
```sh
ln -sfn ~/.local/bin/nix-portable ~/.local/bin/nix
for tool in nix-env nix-build nix-channel nix-instantiate nix-store nix-hash nix-collect-garbage; do
    ln -sfn ~/.local/bin/nix-portable ~/.local/bin/$tool
done
```

### Step 2: Create the `~/.dotfiles` symlink

Stabilises `mkOutOfStoreSymlink` paths (so the flake keeps working if the repo moves):
```sh
ln -sfn ~/dotfiles ~/.dotfiles
```

Also create the tmux config symlink (tmux runs outside proot, so it's managed manually like `.bashrc`):
```sh
ln -sfn ~/.dotfiles/home/.tmux.conf ~/.tmux.conf
```

### Step 3: Create the nix-portable profile dir

nix-portable doesn't create this by default; home-manager needs it:
```sh
mkdir -p ~/.local/state/nix/profiles
```

### Step 4: Back up existing dotfiles

home-manager refuses to overwrite existing files. Move them aside first:
```sh
mkdir -p ~/dotfiles-backup-$(date +%Y%m%d)
cp ~/.zshrc ~/.p10k.zsh ~/.tmux.conf ~/.gitconfig ~/.bashrc ~/.profile ~/dotfiles-backup-$(date +%Y%m%d)/ 2>/dev/null
mv ~/.zshrc ~/.zshrc.pre-nix 2>/dev/null
mv ~/.gitconfig ~/.gitconfig.pre-nix 2>/dev/null
mv ~/.tmux.conf ~/.tmux.conf.pre-nix 2>/dev/null
mv ~/.p10k.zsh ~/.p10k.zsh.pre-nix 2>/dev/null
```

### Step 5: Set up the `.bashrc` bridge

The login shell is bash. `.bashrc` must: set up `NIX_PROFILES`/PATH, then `exec` zsh through proot (so `/nix/store` resolves). Replace `~/.bashrc` with:

```bash
# ~/.bashrc: slimmed - bash launches system tmux, then proot zsh inside it.
# tmux must run OUTSIDE proot (proot breaks pty creation).

case $- in
    *i*) ;;
      *) return;;
esac

# SSH agent - adds all private keys
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null
    find ~/.ssh -maxdepth 1 -type f -name "*.pub" -exec basename {} .pub \; | while read key; do
        ssh-add ~/.ssh/"$key" 2>/dev/null
    done
fi

# uv env (defensive - kept alongside Nix)
. "$HOME/.local/bin/env" 2>/dev/null

export AWS_PROFILE=coreweave

# Nix profile setup (nix-portable: /nix is virtualized via proot for the shell)
export NIX_PROFILES="$HOME/.nix-profile"
export PATH="$HOME/.nix-profile/bin:$PATH"

# Start system tmux FIRST (outside proot - tmux needs kernel pty access).
# Set SKIP_TMUX=1 to bypass tmux for this session (e.g. to run a non-tmux shell).
if [ -n "$PS1" ] && \
   [ -z "$TMUX" ] && \
   [ -z "$SKIP_TMUX" ] && \
   [ "$TERM_PROGRAM" != "vscode" ] && \
   [ -z "${REMOTE_CONTAINERS_SOCKETS}" ] && \
   [ -z "${CURSOR_AGENT}" ] && \
   command -v /usr/bin/tmux &>/dev/null; then
    exec /usr/bin/tmux new-session -A -s main
fi

# Inside tmux (or tmux not available): launch Nix zsh via proot.
# Check proot binary (real file), NOT `command -v zsh` - the Nix zsh symlink
# dangles outside proot (/nix/store doesn't exist on real FS).
if [ -x ~/.nix-portable/bin/proot ] && \
   [[ $- == *i* ]] && \
   [[ -z "${REMOTE_CONTAINERS_SOCKETS}" ]] && \
   [[ -z "${CURSOR_AGENT}" ]]; then
    exec ~/.nix-portable/bin/proot -b ~/.nix-portable/nix:/nix ~/.nix-profile/bin/zsh -l
fi
```

### Step 6: Apply the config

```sh
cd ~/.dotfiles
./rebuild.sh
```

First run: 10-30 min (builds 115 derivations, downloads ~250 MiB). Subsequent runs: <1 min.

After it completes: open a new SSH session. You should land in zsh inside tmux, with starship prompt, all Nix tools on PATH.

## Daily use

Edit the config files in place, then re-apply:

```sh
cd ~/.dotfiles
./rebuild.sh
```

For nvim config edits only (lua files in `home/.config/nvim/`): no rebuild needed - they're symlinked edit-in-place.

To update flake inputs (nixpkgs, home-manager) deliberately:
```sh
cd ~/.dotfiles
nix flake update
./rebuild.sh
```

## Make it yours

If you clone this repo, review these before running the setup:

- **Username**: `home/default.nix` has `home.username = "hayden.dorahy"` and `home.homeDirectory = "/mnt/home/hayden.dorahy"`. Change both to your user/home.
- **Host label**: `flake.nix` declares `homeConfigurations."hayden@remote"`. The `#hayden@remote` in the switch command must match.
- **AWS_PROFILE**: `.bashrc` sets `AWS_PROFILE=coreweave`. Remove or change if you don't use AWS.
- **pi-node PATH**: `hosts/remote.nix` adds `$HOME/.local/share/pi-node/node-v22.23.1-linux-x64/bin` to `sessionPath`. Remove if you don't use pi-node.
- **Aliases**: `home/shell.nix` has `cc`/`oc` pointing at `~/.local/bin/local-claude`/`local-opencode` (CoreWeave local model proxies). Change or remove if you don't have these.
- **SSH agent**: `.bashrc` auto-adds all `~/.ssh/*.pub` keys. Review if you don't want that.
- **Git identity**: this config deliberately does NOT set git `user.name`/`user.email`. Git will prompt on first commit. Add to `home/git.nix` if you want it managed.

## How the rootless Nix setup works (nix-portable specifics)

This setup differs from a standard Nix install because we have no root (shared cluster, no sudo). Standard Nix needs root to create `/nix/store` and run a daemon. nix-portable avoids this entirely:

- **No `/nix`** - nix-portable stores everything in `~/.nix-portable/`. The Nix store is at `~/.nix-portable/nix/store/`.
- **proot bridge** - HM-managed symlinks point to `/nix/store/...` paths, which don't exist on the real filesystem. `.bashrc` runs zsh through `proot -b ~/.nix-portable/nix:/nix`, which bind-mounts the nix store to `/nix` at the syscall level. This is transparent to the shell - all `/nix/store/...` paths resolve. proot is needed because we can't create the real `/nix` directory (no root).
- **No nix-env by default** - nix-portable only provides `nix`. HM's activation script needs `nix-env`, so we create symlinks (`nix-env` -> `nix-portable`; it's a multi-call binary).
- **Profile dir** - `~/.local/state/nix/profiles/` must exist before `switch` (nix-portable doesn't create it).
- **proot limitation: terminal multiplexers** - proot uses ptrace to intercept syscalls, which breaks fork+exec of Nix binaries by a traced process (proot #119). Terminal multiplexers (tmux, herdr) that spawn panes under proot hit this bug. tmux is run outside proot (system `/usr/bin/tmux`); see `docs/herdr-learnings.md` for the full investigation on herdr.

## What's NOT managed by Nix (stays manual)

- **tmux config (`~/.tmux.conf`)** - managed manually (direct symlink to `~/.dotfiles/home/.tmux.conf`), NOT via HM. System tmux runs outside proot; HM's store-resident symlinks don't resolve there. The config file IS tracked in the repo at `home/.tmux.conf` - edit-in-place. TPM (plugin manager) auto-installs dracula/sensible on first launch.
- **`~/.ssh/`** - keys, config, authorized_keys. The SSH agent setup in `.bashrc` stays manual.
- **`~/.config/rclone/rclone.conf`** - holds cloud credentials. The HM module installs rclone + completion only; config stays manual (never in the flake - public GitHub repo).
- **uv-managed tools** (`task`, `nvitop`, `hf`, `evo`, `graphify`) - these stay as `uv tool install` in `~/.local/bin`. Nix doesn't fight uv for Python-based tools.
- **`micro`** - fallback editor kept in `~/.local/bin` (EDITOR=nvim, but micro invokable directly).
- **`local-claude`/`local-opencode`/etc.** - CoreWeave local model proxies in `~/.local/bin`.

## Mac (deferred)

This repo currently only defines `homeConfigurations."hayden@remote"` (Linux). A separate session will add `hosts/mac.nix` (and possibly a `darwinConfiguration` via nix-darwin) to the same repo, reusing the shared `home/` module. See `docs/specs/2026-07-26-nix-dotfiles-design.md` for the design.

## Notes

- **proot overhead**: proot uses ptrace to intercept syscalls, adding latency to filesystem operations. Acceptable for interactive shells; heavy I/O workloads may be slower. This is the tradeoff for rootless Nix.
- **First nvim launch**: bootstraps [lazy.nvim](https://github.com/folke/lazy.nvim) by cloning plugins from GitHub. Needs network once; after that it's offline.
- **Package versions**: pinned to nixos-26.05 (stable). Slightly behind unstable for some packages (uv 0.11.21 vs 0.11.28, zoxide 0.9.9 vs 0.10.0). Trade-off for stability vs HM/nixpkgs drift.

## Reference

- Design doc: `docs/specs/2026-07-26-nix-dotfiles-design.md`
- Implementation plan: `docs/plans/2026-07-26-nix-dotfiles-setup.md`
- Video walkthrough: https://youtu.be/5N-okeDdIuI
- Video's config: https://github.com/kunchenguid/dotfiles
- nix-portable: https://github.com/DavHau/nix-portable

## License

MIT No Attribution (matching the reference repo).
