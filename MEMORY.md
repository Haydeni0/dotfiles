---
summary: "Agent long-term memory — tool setup and lessons learned"
read_when:
  - Starting work in this repo
  - Hitting a gotcha that might recur
  - Adding a new tool, wrapper, or integration
---

# MEMORY.md - dotfiles

Long-term memory for AI agents working in this repo. Read at session start;
append to when you discover or fix something non-obvious. This is the
*distilled* memory - if a fact is already in the README or AGENTS.md, don't
duplicate it here. Entries below should be things you'd only know from having
worked in this repo and hit a snag.

Rules:
- One entry per learning, newest at top.
- Date + one-line summary as a `###` heading, then the detail.
- Only verified facts you confirmed this session - no guesses.
- Reference the commit that fixed it.

## Tool Setup

Environment specifics an agent needs to know. Add as discovered.

### Linux cluster (no root)
- Nix store: `~/.nix-portable/nix/store/` (NFS-backed)
- bwrap binary: `~/.nix-portable/bin/bwrap`
- nix-portable: `~/.local/bin/nix-portable` (orchestrator, auto-selects bwrap)
- Rebuild must run from a bwrap pane (nix segfaults in proot - TracerPid != 0)

## Learnings

### 2026-07-27 - zoxide completion needs compinit before init
HM's `enableZshIntegration` places `zoxide init zsh` at mkOrder 851, but our
manual `compinit -C` runs later in `initContent`. `compdef` fails silently
without compinit, so `z <tab>` never registered. Fix: disable the HM
integration (`enableZshIntegration = false`), run `zoxide init zsh` manually
after compinit. Commit `94760b7`.

### 2026-07-27 - herdr panes segfault without the nix-zsh wrapper
herdr (Nix binary) fork+exec'ing Nix zsh inside bwrap segfaults every pane.
System bash exec'ing Nix zsh works. Fix: `~/.local/bin/nix-zsh` wrapper
(system bash script) that `exec`s Nix zsh. Don't point herdr's
`default_shell` at Nix zsh directly. Commit `b36ca63`.

### 2026-07-27 - proot orphans survive tmux server crash
When the tmux server dies, proot pane processes reparent to init but keep
ptracing their children indefinitely. They're invisible (no pane) but hold
tracees frozen. After a tmux crash, check for orphans:
`ps -eo pid,ppid,stat,comm | awk '$4=="proot" && $2==1'`
and kill them (only works when they're out of D-state). Commit `d93ce85`.
