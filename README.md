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
3. **Direct symlink, outside HM** (tmux, `.bashrc`) - `~/.tmux.conf` -> `~/.dotfiles/home/.tmux.conf` directly. System tmux runs outside bwrap (needs kernel pty access); HM's store-resident symlinks don't resolve there, so tmux config is managed manually like `.bashrc`. Tracked in the repo, edit-in-place.

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

Also create the tmux config symlink (tmux runs outside bwrap, so it's managed manually like `.bashrc`):
```sh
ln -sfn ~/.dotfiles/home/.tmux.conf ~/.tmux.conf
```

And the herdr config symlink (herdr runs inside bwrap, but the config is managed as a direct symlink like tmux/.bashrc):
```sh
mkdir -p ~/.config/herdr
ln -sfn ~/.dotfiles/home/.config/herdr/config.toml ~/.config/herdr/config.toml
ln -sfn ~/.dotfiles/home/.local/bin/nix-zsh ~/.local/bin/nix-zsh
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

The login shell is bash. `.bashrc` must: set up `NIX_PROFILES`/PATH, then `exec` zsh through bwrap (so `/nix/store` resolves). The file is tracked in the repo at `home/.bashrc` - symlink it into place (matching the `~/.tmux.conf` pattern):

```sh
ln -sfn ~/.dotfiles/home/.bashrc ~/.bashrc
```

What `home/.bashrc` does:
1. Sets up `NIX_PROFILES`/PATH so HM-managed tools resolve once the namespace is up.
2. Starts system tmux **outside** bwrap (tmux needs kernel pty access; bwrap's namespace breaks that).
3. Inside tmux, `exec`s Nix zsh through bwrap, which creates a mount namespace with `~/.nix-portable/emptyroot` as root skeleton, overlays the real `/usr`/`/bin`/`/etc`/`/mnt`/`$HOME` on top, and binds `~/.nix-portable/nix` to `/nix` so HM symlinks resolve.

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
- **bwrap bridge** - HM-managed symlinks point to `/nix/store/...` paths, which don't exist on the real filesystem. `.bashrc` runs zsh through `bwrap`, which creates a mount namespace with `~/.nix-portable/emptyroot` as a root skeleton, overlays the real top-level dirs (`/usr`, `/bin`, `/etc`, `/mnt`, `$HOME`, etc.) on top, and binds `~/.nix-portable/nix` to `/nix`. All `/nix/store/...` paths resolve inside the namespace. bwrap is used because we can't create the real `/nix` directory (no root) and bwrap's namespace approach avoids the ptrace problems of the proot fallback (see "Why bwrap not proot" below).
- **No nix-env by default** - nix-portable only provides `nix`. HM's activation script needs `nix-env`, so we create symlinks (`nix-env` -> `nix-portable`; it's a multi-call binary).
- **Profile dir** - `~/.local/state/nix/profiles/` must exist before `switch` (nix-portable doesn't create it).
- **bwrap + terminal multiplexers** - bwrap creates a mount namespace, which breaks tmux's pty creation. tmux is run outside bwrap (system `/usr/bin/tmux`); `.bashrc` handles the two-stage launch (tmux first, then bwrap zsh inside tmux). herdr (agent multiplexer, installed via the flake) runs inside bwrap - panes spawn via a system-bash wrapper (`~/.local/bin/nix-zsh`) that execs Nix zsh, because a Nix binary fork+exec'ing another Nix binary inside bwrap segfaults (system-binary-spawning-Nix-binary works fine). See `docs/herdr-learnings.md` for the full investigation.

### Why bwrap not proot

nix-portable supports three runtimes (auto-selected: `nix --store` > `bwrap` > `proot`). This cluster has user namespaces (`unshare -U -m` succeeds), so nix-portable auto-selects `bwrap`. `.bashrc` invokes bwrap directly (the same runtime nix-portable's selector would pick) rather than calling `nix-portable` itself, because nix-portable has a path-concatenation bug when passed an absolute binary path.

proot (the last-resort fallback) was the previous bridge. It uses ptrace to intercept every syscall and rewrite paths, which causes three problems this cluster hit:
1. **SIGINT ignored** - proot explicitly sets `SIG_IGN` for SIGINT/SIGTERM/SIGHUP (`event.c:332-336`), so Ctrl-C can't kill a frozen TUI. ([proot#146](https://github.com/proot-me/proot/issues/146))
2. **D-state cascade on NFS stalls** - proot's main loop blocks in `waitpid`; when proot itself stalls on an NFS read (D-state, uninterruptible), all traced children freeze until NFS recovers. No fix possible without abandoning ptrace.
3. **Orphaned tracers after tmux crash** - if the tmux server dies, proot processes get reparented to init but keep ptracing their children indefinitely. ([proot#78](https://github.com/proot-me/proot/issues/78), filed by proot's original author, open since 2014)

bwrap uses user+mount namespaces instead of ptrace - no syscall interception, no signal ignoring, no D-state cascade, no orphan problem. The tradeoff: bwrap creates a namespace (slightly more isolation than proot's transparent overlay), but the binds in `.bashrc` make the namespace functionally equivalent to proot's view for shell use.

## What's NOT managed by Nix (stays manual)

- **tmux config (`~/.tmux.conf`)** - managed manually (direct symlink to `~/.dotfiles/home/.tmux.conf`), NOT via HM. System tmux runs outside bwrap; HM's store-resident symlinks don't resolve there. The config file IS tracked in the repo at `home/.tmux.conf` - edit-in-place. TPM (plugin manager) auto-installs dracula/sensible on first launch.
- **`.bashrc`** - managed manually (direct symlink to `~/.dotfiles/home/.bashrc`), NOT via HM. Runs outside bwrap (it *launches* bwrap), so HM's store-resident symlinks don't resolve there. Tracked in the repo at `home/.bashrc` - edit-in-place.
- **herdr config (`~/.config/herdr/config.toml`)** - managed manually (direct symlink to `~/.dotfiles/home/.config/herdr/config.toml`), NOT via HM. herdr runs inside bwrap (so HM-managed config would resolve), but kept as a direct symlink for edit-in-place convenience (matches the tmux/.bashrc pattern). herdr binary IS managed by HM (via `packages.nix` + flake input). Tracked in the repo at `home/.config/herdr/config.toml`.
- **`~/.ssh/`** - keys, config, authorized_keys. The SSH agent setup in `.bashrc` stays manual.
- **`~/.config/rclone/rclone.conf`** - holds cloud credentials. The HM module installs rclone + completion only; config stays manual (never in the flake - public GitHub repo).
- **uv-managed tools** (`task`, `nvitop`, `hf`, `evo`, `graphify`) - these stay as `uv tool install` in `~/.local/bin`. Nix doesn't fight uv for Python-based tools.
- **`micro`** - fallback editor kept in `~/.local/bin` (EDITOR=nvim, but micro invokable directly).
- **`local-claude`/`local-opencode`/etc.** - CoreWeave local model proxies in `~/.local/bin`.

## Mac (deferred)

This repo currently only defines `homeConfigurations."hayden@remote"` (Linux). A separate session will add `hosts/mac.nix` (and possibly a `darwinConfiguration` via nix-darwin) to the same repo, reusing the shared `home/` module. See `docs/specs/2026-07-26-nix-dotfiles-design.md` for the design.

## Notes

- **bwrap overhead**: bwrap creates a mount namespace at shell startup (one-time, ~ms). Inside the namespace there's no per-syscall interception overhead (unlike proot's ptrace). The nix store is on NFS, so cold store reads pay NFS latency, but bwrap itself adds no runtime overhead.
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
