# herdr learnings

Investigation into running herdr (agent multiplexer) alongside a rootless Nix setup (nix-portable + proot) on a shared Linux cluster (Ubuntu 22.04, no root).

## Update (2026-07-27): RESOLVED by bwrap migration

The proot → bwrap migration fixed all herdr issues. bwrap uses user+mount namespaces instead of ptrace, so fork+exec into PTYs works natively (verified: `pty.fork()` + `execvp(zsh)` inside bwrap succeeds, proot segfaulted here). herdr is now installed via the flake (`flake.nix` input `github:ogulcancelik/herdr/v0.7.5` → `packages.nix`) and runs inside bwrap. Panes inherit the namespace and spawn Nix zsh directly (no wrapper needed). Config at `home/.config/herdr/config.toml`. The investigation below is preserved as historical context.

## TL;DR (historical - proot era)

herdr doesn't work with nix-portable/proot on this remote. The Nix herdr segfaults when spawning panes (proot's fork+exec bug). The standalone herdr (outside proot) also can't spawn panes that use Nix tools (proot segfaults in PTY context). herdr is removed from the setup for now. On Mac (no proot), herdr would work via Nix directly.

## What is herdr

herdr (https://herdr.dev, v0.7.5) is a terminal multiplexer built for AI coding agents. Like tmux but with agent state awareness: shows `blocked`/`working`/`done`/`idle` at a glance for claude/codex/opencode, has a socket API, plugins, remote attach, mobile-responsive TUI. The reference video (https://youtu.be/5N-okeDdIuI) uses it instead of tmux.

## The setup

- Linux x86_64, Ubuntu 22.04, CoreWeave Slurm cluster, **no root**
- nix-portable (rootless Nix, no `/nix`, no daemon) - store at `~/.nix-portable/nix/store/`
- proot virtualizes `/nix` via ptrace+seccomp syscall interception (the `.bashrc` bridge: `exec proot -b ~/.nix-portable/nix:/nix zsh -l`)
- home-manager tools in `~/.nix-profile/bin/` (Nix store paths, only resolve inside proot)

## What we tried

### Attempt 1: Nix herdr (inside proot)

Installed herdr via flake input (`github:ogulcancelik/herdr/v0.7.5`), passed as `herdrPkg` in `home.packages`. The binary is at `~/.nix-profile/bin/herdr` -> `/nix/store/...` (resolves inside proot).

**Result:** herdr's TUI launches fine. But every pane it spawns **segfaults**: `signal: Some("Segmentation fault")` in a crash loop (spawn → segfault → respawn → segfault). herdr logs show:
```
pane child exited event="pane.exit" status="ExitStatus { code: 1, signal: Some("Segmentation fault") }"
```

**Root cause:** proot uses ptrace to intercept syscalls. When herdr (a proot tracee) forks and execs a Nix-built zsh into a new PTY, proot's execve-after-fork handling is buggy (proot issues #119, #332, #129). The direct `proot ... zsh` works because proot performs that initial exec itself (well-tested path); fork-then-exec-by-a-tracee is the broken one.

### Attempt 2: Standalone herdr + proot wrapper (panes enter proot fresh)

Installed herdr standalone via `curl -fsSL https://herdr.dev/install.sh | sh` to `~/.local/bin/herdr` (outside Nix/proot). Created `~/.local/bin/nix-zsh` wrapper:
```sh
exec env SKIP_TMUX=1 ~/.nix-portable/bin/proot -b ~/.nix-portable/nix:/nix ~/.nix-profile/bin/zsh
```
Configured herdr to use this as `default_shell`.

**Result:** herdr runs (outside proot), but panes still segfault. The wrapper runs proot, and proot segfaults when spawned in a PTY by a non-proot process. Tested with a Python `pty.fork()` simulation: proot zsh produces no output and exits in a PTY context.

**Root cause:** proot's ptrace doesn't work correctly when the proot process itself is spawned into a PTY by a non-proot parent. The PTY + ptrace + fork+exec combination breaks.

### Attempt 3: PROOT_NO_SECCOMP=1

Added `PROOT_NO_SECCOMP=1` to the proot bridge in `.bashrc` (disables seccomp filtering, falls back to ptrace-only).

**Result:** Panes still segfault. Disabling seccomp dodges the seccomp-mode fork+syscall bug (proot #332) but not the ptrace-mode execve-after-fork bug (proot #119).

### Attempt 4: bwrap instead of proot

This node has user namespaces (verified: `unshare -U` works). nix-portable ships bwrap and auto-selected it (not proot) for its own nix commands. bwrap uses namespaces (no ptrace), so fork+exec is native.

Tested bwrap with Nix binaries directly: works (`nix --version` runs, fork+exec works, PTY creation works). Tried replacing the proot bridge in `.bashrc` with bwrap.

**Result:** bwrap bridge broke SSH login entirely (`[exited]` immediately). The bwrap namespace setup is more verbose than proot's one-liner and something in the setup (likely missing binds or TTY handling) caused the login shell to exit. Also tested bwrap in the herdr `nix-zsh` wrapper: also produced no output in PTY context.

**Root cause:** bwrap works for direct execution but the namespace setup + PTY fork interaction has its own issues. Didn't fully debug - the complexity wasn't worth it for a multiplexer.

### Attempt 5: Platform-conditional (Nix on Mac, standalone on Linux)

Made herdr in `home/packages.nix` conditional on `pkgs.stdenv.hostPlatform.isDarwin` - only installed via Nix on Mac. On Linux, rely on the standalone install. This fixed `which herdr` finding the Nix version (segfaults) instead of the standalone one.

**Result:** `which herdr` now finds `~/.local/bin/herdr` (standalone). But panes still segfault for the same proot-in-PTY reason as Attempt 2.

## Root cause summary

proot virtualizes `/nix` via ptrace+seccomp syscall interception. Terminal multiplexers that spawn panes need to:
1. Create a PTY (proot doesn't translate `/dev/pts` fds - proot #134)
2. Fork+exec a shell into that PTY (proot's execve-after-fork is buggy - proot #119, #332, #129)

These are **proot limitations**, not herdr or nix-portable bugs. Any terminal multiplexer that spawns panes under proot hits this. tmux has the same issue (solved by running system `/usr/bin/tmux` outside proot).

The difference: tmux can run outside proot because it doesn't need Nix tools to function (it just manages panes; the shells inside panes enter proot via `.bashrc`). herdr, as a standalone binary, also runs outside proot, but its panes need to spawn proot to get Nix tools - and proot segfaults in that PTY context.

## What would fix it

1. **Standard Nix install (with root):** real `/nix/store`, no proot, herdr works directly. Not available on this cluster (no root).
2. **bwrap bridge (if the SSH login issue is debugged):** bwrap doesn't use ptrace, so fork+exec in PTYs works. The bwrap bridge broke SSH login in our testing - needs more investigation (likely missing binds or TTY setup). Would also require user namespaces on every node (compute nodes may not have them).
3. **herdr with system shell panes (no Nix tools):** herdr panes run system bash/zsh without Nix tools. Agents (`cc`/`oc` in `~/.local/bin`) would work, but Nix tools (rg, fzf, nvim, etc.) wouldn't. Not useful for this setup.
4. **Wait for proot/herdr fix:** file an issue with proot about PTY + fork+exec, or with herdr about proot compatibility. Unlikely to be a quick fix.

## What we kept

- herdr removed from `home/packages.nix` (was platform-conditional, now gone entirely)
- herdr flake input removed from `flake.nix`
- herdr config removed from `home/.config/herdr/`
- This learnings doc at `docs/herdr-learnings.md`
- The README references this doc in the proot limitations section

## For Mac

On Mac (no proot, standard Nix install with root), herdr works via Nix directly. To add it back for Mac:
1. Add `herdr.url = "github:ogulcancelik/herdr/v0.7.5"` to `flake.nix` inputs
2. Add `herdrPkg` to `extraSpecialArgs` in the darwinConfiguration
3. Add `herdrPkg` to `home/packages.nix` (unconditional, or `isDarwin` only)
4. No standalone install or wrapper needed

## References

- herdr: https://herdr.dev
- herdr install docs: https://herdr.dev/docs/install/
- herdr config docs: https://herdr.dev/docs/configuration/
- nix-portable: https://github.com/DavHau/nix-portable
- proot #119 (execve after fork): https://github.com/proot-me/proot/pull/119
- proot #332 (fork+syscall in seccomp): https://github.com/proot-me/proot/issues/332
- proot #129 (nix binaries signal 11): https://github.com/proot-me/proot/issues/129
- proot #134 (/dev/pts not translated): https://github.com/proot-me/proot/issues/134
- proot #106 (SEGSEGV with seccomp, PROOT_NO_SECCOMP=1): https://github.com/proot-me/proot/issues/106
- Full research report: `.superpowers/sdd/2026-07-26-nix-dotfiles-setup/research-proot-segfault.md`
