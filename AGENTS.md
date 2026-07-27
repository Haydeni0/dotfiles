# AGENTS.md - dotfiles

Guidance for AI coding agents (Claude Code, opencode) working in this repository.
Read the README for architecture, setup, and the bwrap bridge - this file is about
**how to work here**, not what the repo is. Read `MEMORY.md` at session start for
accumulated lessons learned; append to it when you discover or fix something
non-obvious (read it first, then edit - don't duplicate the README or AGENTS.md).

## What this repo is

A reproducible developer environment managed by Nix flakes + home-manager. One
`./rebuild.sh` from a fresh Linux box reproduces the full shell, toolset, editor,
and multiplexer. Linux runs rootless (nix-portable + bwrap, no `/nix`, no sudo);
Mac is deferred (`hosts/mac.nix` not yet written).

Everything in `home/` is shared across platforms. Platform-specific bits live in
`hosts/`. Linux is the constrained platform (no root) - changes that touch the
bridge or platform conditionals must be verified on Linux.

## How to make changes

1. **Edit the Nix file** in `home/` (shared) or `hosts/` (platform-specific).
2. **Stage new files** - flakes only see git-tracked files. `git add <new-file>`
   before rebuild, or the flake fails with "path does not exist".
3. **Apply**: `./rebuild.sh` (runs `home-manager switch --flake .#hayden@remote`).
4. **Test in a new tmux pane** - existing shells keep their old env; a fresh pane
   re-launches bwrap zsh and picks up the change.
5. **Commit + push** - the repo is the source of truth.

Config that's a direct symlink (tmux, `.bashrc`) is edit-in-place - no
rebuild. HM-managed config needs `./rebuild.sh`.

## Reproducibility rules

- **Everything goes in the repo.** A setup step is either a HM module or a tracked
  file with a symlink command in the README. No untracked config.
- **flake.lock is committed.** Don't `nix flake update` unless deliberately
  bumping inputs; if you do, it gets its own commit.
- **No secrets in the repo.** SSH keys, rclone credentials, API keys stay manual
  (README "What's NOT managed by Nix").
- **Platform differences stay in `hosts/`.** Don't add Mac-specific packages
  unconditionally - gate with `isDarwin` or wait for the Mac session.

## Commit conventions

- Imperative mood: "Add herdr via Nix", "Fix zoxide completion".
- Subject ≤72 chars; body explains the **why** (the what is in the diff).
- One logical change per commit - don't bundle unrelated fixes.
- Reference issues/commits when relevant.

## Principles (non-obvious rules agents must respect)

- **Never reintroduce proot.** The bwrap bridge replaced it for real reasons
  (SIGINT ignored, D-state cascade on NFS, orphaned tracers). See README "Why
  bwrap not proot". Don't swap bwrap for proot in `.bashrc` or wrappers.
- **tmux runs outside bwrap.** System `/usr/bin/tmux`, launched by `.bashrc`
  before the namespace exists. Panes then spawn bwrap zsh. Don't run tmux inside
  bwrap - it segfaults on pty creation.
- **herdr panes need the `nix-zsh` wrapper (bwrap/Linux only).** A Nix binary
  fork+exec'ing another Nix binary inside bwrap segfaults; the system-bash
  wrapper works around it. Don't point herdr's `default_shell` at Nix zsh
  directly on Linux. The wrapper is HM-managed (`hosts/remote.nix` →
  `home.file`, Linux-gated by living in `hosts/`); Mac has no bwrap so no
  segfault and no wrapper - herdr config points directly at Nix zsh there.
- **`enableZshIntegration` defaults to true.** HM's ordering can break manual
  `compinit` ordering (zoxide hit this). To disable one integration, set it
  explicitly `false` and run the init yourself after compinit.
- **Nix segfaults inside proot.** If a pane has TracerPid != 0, `nix` crashes.
  Run rebuilds from a bwrap pane, not a leftover proot pane.

## Testing changes

After `./rebuild.sh`, in a **new** tmux pane:
- `z <tab>` - zoxide completion (compinit + zoxide ordering)
- `which <tool>` - resolves to `~/.nix-profile/bin/<tool>`
- `alias g` - shows `git` (aliases.nix merge works)
- `herdr` - launches, panes don't segfault

Rollback: `home-manager generations` + `home-manager rollback`.
