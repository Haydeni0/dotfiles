# AGENTS.md - dotfiles

Guidance for AI coding agents (Claude Code, opencode) working in this repository.

## What this repo is

A reproducible developer-environment config managed by [Nix flakes](https://nixos.wiki/wiki/Flakes) + [home-manager](https://nix-community.github.io/home-manager/). One `./rebuild.sh` from a fresh machine reproduces the entire shell, toolset, editor, and multiplexer setup. Tracked in git, pushed to `origin/nix-start`.

## The two platforms

| | Linux (remote cluster) | Mac |
|---|---|---|
| Root | **No sudo** - shared compute cluster | Has sudo, brew |
| Nix install | nix-portable (rootless, no `/nix`, no daemon) | Proper Nix install |
| `/nix` virtualisation | **bwrap** (user+mount namespaces) | N/A - real `/nix` exists |
| flake host | `hayden@remote` | `hayden@mac` (deferred - `hosts/mac.nix` not yet written) |
| `rebuild.sh` NIX var | `~/.local/bin/nix-portable` (falls back if `nix` not on PATH) | `nix` (system) |

Everything in `home/` is shared across both platforms. Platform-specific bits live in `hosts/`.

## Architecture

```
flake.nix              inputs: nixpkgs-26.05, home-manager, herdr
  └─ home/default.nix   imports all modules:
       ├─ shell.nix      zsh config: keymaps, compinit, fzf, history, zoxide, plugins
       ├─ aliases.nix   oh-my-zsh-style aliases (git + ls family)
       ├─ packages.nix  home.packages (ripgrep, fzf, nvim, bat, herdr, etc.)
       ├─ git.nix       git config (delta, aliases, identity is NOT set)
       ├─ tmux.nix       (empty - tmux config is a manual symlink, see below)
       ├─ editor.nix     neovim + lazy.nvim bootstrap
       ├─ herdr.nix     xdg.configFile for herdr config
       ├─ zoxide.nix     zoxide (enableZshIntegration=false, init runs in shell.nix)
       ├─ btop.nix       btop config
       └─ rclone.nix     rclone (config stays manual - credentials)
  └─ hosts/remote.nix   Linux-specific: sessionPath, sessionVariables
```

## The bwrap bridge (Linux) - critical, do not break

On the Linux cluster, `/nix` doesn't exist on the real filesystem (no root to create it). `~/.bashrc` launches zsh through **bwrap**, which creates a mount namespace with `~/.nix-portable/emptyroot` as a root skeleton, overlays the real `/usr`/`/bin`/`/etc`/`/mnt`/`$HOME` on top, and binds `~/.nix-portable/nix` to `/nix`.

**Never reintroduce proot.** proot (nix-portable's last-resort fallback) uses ptrace to intercept syscalls, which:
- Explicitly ignores SIGINT (`event.c:332-336`) - Ctrl-C can't kill frozen TUIs
- Cascades D-state on NFS stalls - one stuck proot freezes all traced children
- Leaves orphaned tracers after tmux crash - proots keep ptracing indefinitely

bwrap uses user+mount namespaces - no syscall interception, no signal issues. Verified working: `unshare -U -m` succeeds on this cluster, TracerPid=0 inside bwrap zsh. See `docs/herdr-learnings.md` and the README "Why bwrap not proot" section for the full investigation.

## What's HM-managed vs manual (and why)

| File | HM-managed? | Why |
|---|---|---|
| `~/.zshrc`, `~/.gitconfig`, nvim plugins, etc. | Yes (HM `programs.<x>`) | Run inside bwrap, `/nix/store` resolves |
| `~/.config/herdr/config.toml` | Yes (HM `xdg.configFile`) | herdr runs inside bwrap |
| `~/.tmux.conf` | No - direct symlink to `home/.tmux.conf` | tmux runs **outside** bwrap; store symlinks dangle there |
| `~/.bashrc` | No - direct symlink to `home/.bashrc` | Runs **outside** bwrap (it launches bwrap) |
| `~/.local/bin/nix-zsh` | No - direct symlink to `home/.local/bin/nix-zsh` | System-bash wrapper script, edit-in-place |

The manual-symlink files are tracked in the repo but not managed by HM. They run outside bwrap where `/nix/store` doesn't exist, so HM's store-resident symlinks would dangle.

## How to make changes

1. **Edit the Nix file** (e.g. `home/shell.nix`, `home/packages.nix`)
2. **Stage new files** - flakes only see git-tracked files: `git add <new-file>` before rebuild
3. **Apply**: `./rebuild.sh` (runs `home-manager switch --flake .#hayden@remote`)
4. **Test in a new pane** - changes don't affect existing shells; open a new tmux pane (it launches bwrap zsh fresh)
5. **Commit + push** - keep the repo as the source of truth

For config that's a direct symlink (tmux, .bashrc, nix-zsh): edit the repo file directly, no rebuild needed (edit-in-place). For HM-managed config: edit the source in `home/`, run `./rebuild.sh`.

## Reproducibility rules

- **Everything goes in the repo.** If a setup step exists, it's either a HM module or a tracked file with a symlink command in the README. No untracked config.
- **flake.lock is committed.** Don't `nix flake update` unless deliberately bumping inputs.
- **No secrets in the repo.** SSH keys, rclone credentials, API keys stay manual (listed in README "What's NOT managed by Nix").
- **Platform differences stay in `hosts/`** - the `home/` modules are shared.
- **Verify on both platforms** if a change touches the bwrap bridge or platform-conditional logic. Linux is the constrained one (no root); Mac has more freedom.

## Commit conventions

- Imperative mood: "Add herdr via Nix", "Fix zoxide completion", not "Added" or "Fixing"
- Subject line ≤72 chars, body explains the **why** (the what is in the diff)
- One logical change per commit - don't bundle unrelated fixes
- Reference issues/commits when relevant: "proot → bwrap (fixes the freeze from d93ce85)"
- `flake.lock` updates get their own commit: `flake.lock: add herdr input (auto-updated by rebuild)`

## Gotchas

- **nix segfaults inside proot.** If you're in an old proot pane (TracerPid != 0), `nix` and `nix-instantiate` crash. Run rebuilds from a bwrap pane or a clean tmux pane (`tmux new-window '/bin/bash --noprofile --norc -c "./rebuild.sh"'`).
- **Flakes only see git-tracked files.** A new `.nix` file isn't visible to the flake until `git add`-ed, even if it exists on disk. Rebuild will fail with "path does not exist" if you forget to stage.
- **`enableZshIntegration` defaults to true** via `home.shell.enableZshIntegration`. To disable a specific integration, set it explicitly to `false` (see `zoxide.nix` - HM's default ordering broke zoxide completion because it ran before our manual compinit).
- **herdr panes need the nix-zsh wrapper.** herdr (Nix binary) fork+exec'ing Nix zsh inside bwrap segfaults. The `~/.local/bin/nix-zsh` wrapper (system bash script that `exec`s Nix zsh) works around this. Don't change herdr's `default_shell` to point directly at Nix zsh.
- **tmux runs outside bwrap.** It's the system `/usr/bin/tmux`, launched by `.bashrc` before the bwrap namespace exists. tmux panes then spawn bwrap zsh. Don't try to run tmux inside bwrap (it segfaults on pty creation).
- **Mac is deferred.** `hosts/mac.nix` doesn't exist yet. Don't add Mac-specific packages unconditionally - use `pkgs.stdenv.hostPlatform.isDarwin` guards if needed, or wait for the Mac setup session.

## Testing changes

After `./rebuild.sh`, verify in a **new** tmux pane (not the one you rebuilt from):
- `z <tab>` - zoxide completion (tests compinit + zoxide ordering)
- `which <tool>` - resolves to `~/.nix-profile/bin/<tool>` (tests HM packages)
- `alias g` - shows `git` (tests aliases.nix merge)
- `herdr` - launches, panes don't segfault (tests nix-zsh wrapper + bwrap)

If something breaks, the rollback is `home-manager generations` (HM keeps generations; `home-manager rollback` switches to the previous one).
