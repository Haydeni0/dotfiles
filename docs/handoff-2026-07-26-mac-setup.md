# Handoff: Mac setup (next session)

**Date:** 2026-07-26
**Picking up from:** `nix-start` branch (pushed to origin, 10 commits)
**Repo:** `~/gitrepos/dotfiles` (GitHub: `Haydeni0/dotfiles`)

## State

Remote (rootless Linux, CoreWeave) is **done and working**. 16 Nix tools, zsh + starship, nvim, tmux (outside proot). All pushed to `origin/nix-start`. See the prior handoff and `README.md` for the full remote state.

Mac is **not started**. Only `hosts/remote.nix` exists; no `hosts/mac.nix`, no darwin flake input, no `darwinConfiguration`. The shared `home/` modules are structured for reuse but currently hardcode remote assumptions (see Portability findings below).

## Goal

Add Mac as a second host in this same repo, reusing the shared `home/` module. One flake, two hosts: `hayden@remote` (Linux, proot) and `hayden@mac` (Darwin, standard Nix).

## Open decisions (resolve before implementing)

These are unsettled. The spec (`docs/specs/2026-07-26-nix-dotfiles-design.md` lines 175-189) lists them but doesn't pick. Brainstorm first.

1. **nix-darwin vs standalone home-manager.** Full system management (nix-darwin + nix-homebrew + macOS defaults, like the reference video `kunchenguid/dotfiles`) vs lighter HM-standalone. Affects flake shape: nix-darwin adds a `darwinConfiguration` output and a `darwin` flake input; standalone HM just adds another `homeConfigurations."hayden@mac"`.
2. **Nix install method on Mac.** Determinate installer (recommended, no root changes to `/etc`) vs official Nix installer vs nix-portable (not needed on Mac - has root). Determinate is the common choice.
3. **Homebrew.** nix-homebrew (declarative brews/casks in the flake) vs manual `brew install`. Casks: Cursor, WezTerm (if not via Nix), fonts.
4. **WezTerm.** Nix `programs.wezterm` (config in `home/`, builds on Darwin) vs brew cask + manual config. The reference repo uses Nix.
5. **nerd-fonts.** `pkgs.nerd-fonts.<font>` via HM `fonts.fontconfig.enable` vs brew cask. HM is cleaner if it builds fast on Mac.
6. **AGENTS.md symlink trick.** The reference repo symlinks `AGENTS.md` into project dirs via `mkOutOfStoreSymlink`. Spec line 182 notes "likely still skip - user's sync setup." Confirm with user.
7. **herdr re-add.** `docs/herdr-learnings.md` "For Mac" section (lines 92-97) has steps: add herdr flake input, `herdrPkg` to `extraSpecialArgs`, `herdrPkg` to `home/packages.nix` (unconditional or `isDarwin` only). herdr works on Mac (no proot). Decision: unconditional or Darwin-gated.
8. **Mac username and home.** `/Users/hayden`? Confirm the actual short username and home path on the Mac.
9. **launchd services.** Any daemons to manage (e.g. rclone mount, ssh-agent)? nix-darwin has `launchd.*`; standalone HM does not.

## Portability findings the Mac session MUST address

A portability audit (`docs/handoff-2026-07-26-mac-setup.md` is the doc you are reading; the audit ran 2026-07-26) found these. Verified against source. The Mac session fixes them as part of adding the Mac host - they are not separable from the Mac work.

### BLOCKER (Mac won't build/work without these)

- **B1 `flake.nix:12`** - `system = "x86_64-linux"` hardcoded. Add Darwin systems (`aarch64-darwin` for Apple Silicon, optionally `x86_64-darwin` for Intel). Use `forAllSystems` or per-host `system` attr. Shape depends on decision 1 (nix-darwin handles system itself; standalone HM needs it explicit).
- **B2 `flake.nix:16`** - only `homeConfigurations."hayden@remote"`. Add the Mac output (`homeConfigurations."hayden@mac"` and/or `darwinConfigurations."hayden@mac"`), and the `darwin` flake input if nix-darwin.
- **B3 `home/default.nix:2-3`** - `home.username = "hayden.dorahy"` and `home.homeDirectory = "/mnt/home/hayden.dorahy"` are in the **shared** module. Move both into per-host modules (`hosts/remote.nix`, `hosts/mac.nix`). Shared `home/default.nix` should only import submodules and set `home.stateVersion`.
- **B5 `home/tmux.nix`** - empty `{}` for all platforms (proot workaround). On Mac, HM's `programs.tmux` works (Nix store resolves normally). Make conditional: empty for remote, `programs.tmux` with settings + plugins for Mac. Or use separate host modules.
- **B6 `home/shell.nix:6`** - `enableCompletion = false` global (proot-slow). On Mac, enable HM completion. Move to host module or gate with `lib.mkIf`.
- **B7 `README.md:117-171`** - the `.bashrc` bridge is hardcoded to `/usr/bin/tmux` + proot. Mac has neither. Add a Mac-specific shell setup section (or split README into per-platform setup docs). Mac likely doesn't need the bash→tmux→proot→zsh chain at all - standard Nix + zsh as login shell.
- **B8 `home/shell.nix:38-39`** - `cc`/`oc` aliases point at `~/.local/bin/local-claude`/`local-opencode` (CoreWeave proxies). In shared module. Move to `hosts/remote.nix` or gate.
- **B9 (root cause)** - zero `lib.optionalAttrs` / `lib.mkIf` / `isDarwin` / `isLinux` anywhere in `home/`. No platform conditionals exist. Adding them is the mechanism for B3/B5/B6/B8. Decide the pattern (per-host modules vs conditionals in shared modules) - this shapes all the other fixes.

### MINOR

- **M2 `docs/specs/2026-07-26-nix-dotfiles-design.md`** - stale. Still describes herdr flake input (lines 29, 50, 56, 80) and `programs.tmux` with plugins (lines 61, 83). herdr was removed; tmux is empty + direct symlink. Update or mark "SUPERSEDED - see README for current state."
- **M3 `docs/plans/2026-07-26-nix-dotfiles-setup.md`** - stale. Task 3 flake template includes herdr input (lines 301-314); Task 5 packages.nix template includes `herdrPkg` (lines 601, 620-621); Task 5 tmux.nix template uses `programs.tmux` (line 646). Mark "IMPLEMENTED AS" notes or superseded.
- **M4 `hosts/remote.nix:14`** - hardcoded `node-v22.23.1-linux-x64` path. Isolated to remote (correct pattern) but fragile. Low priority.

### Already fixed (no action)

- B4 `rebuild.sh` - now platform-detects (Darwin/Linux, nix vs nix-portable, host label). Mac path will work once `hayden@mac` flake output exists.
- M1 `~/.local/bin/nix-zsh` - deleted (orphaned herdr wrapper).
- C1 `README.md:240-241` - duplicate nvim line removed.
- C2 `home/.tmux.conf:109,115` - F11/F12 mismatch fixed (bind is F11, comment + status now say F11).

## Files to read for context

- **Remote state (canonical):** `README.md` - the "how to reproduce" doc, current as of the last commit.
- **Design spec:** `docs/specs/2026-07-26-nix-dotfiles-design.md` - full design. Read lines 175-189 for the Mac section, but note M2 above (parts are stale).
- **herdr on Mac:** `docs/herdr-learnings.md` lines 92-97 - the steps to re-add herdr for Mac.
- **Remote host module:** `hosts/remote.nix` - the pattern to mirror for `hosts/mac.nix`.
- **Shared modules:** `home/default.nix`, `home/shell.nix`, `home/packages.nix`, `home/tmux.nix`, `home/git.nix`, `home/editor.nix`, `home/zoxide.nix`, `home/btop.nix`, `home/rclone.nix`.
- **Reference repo:** `github.com/kunchenguid/dotfiles` (walkthrough: `youtu.be/5N-okeDdIuI`) - Mac-only nix-darwin + HM setup. The shared `home/` content was adopted from here; the Mac session can re-adopt the darwin layer.
- **Prior handoff (remote):** `/tmp/opencode/handoff-nix-dotfiles-2026-07-26.md` - the handoff that produced the remote setup. May not persist across machines.

## Suggested approach

1. **brainstorming** - resolve the open decisions (1-9 above) with the user before any code.
2. **writing-plans** - produce `docs/plans/<date>-mac-setup.md` from the resolved design.
3. **subagent-driven-development** - execute the plan.
4. **code-review** - review before merging to `main`.

## Branch

Start from `nix-start` (or `main` if it has caught up). New branch: `hayden/mac-setup` per the `hayden/` prefix convention in `~/.claude/CLAUDE.md`.
