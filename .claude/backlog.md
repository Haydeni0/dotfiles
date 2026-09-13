# Backlog

Deferred items for this project. Surfaced when starting work here; picked up on request.

## Open

- #4 [2026-09-13] herdr 0.9.0 bug: workspace picker (prefix+w) ignores up/down - navigate_workspace_up/down binds have no effect there (explicit config binds tested too), while navigate_pane_* (h/j/k/l, arrows) work in the same picker. UI hint promises arrow navigation. Repro'd in Terminal.app too - not terminal/Karabiner. Workaround: goto mode (prefix+g) navigates workspaces fine. Config binds added in configs/herdr.toml [keys] can stay or be reverted when upstream fixes.

## Done

- #1 [2026-09-12] WezTerm ctrl+shift+f scrollback search is buggy - CLOSED 2026-09-13: works after herdr 0.9.0 update. Bug was observed with the 0.7.5 client (WezTerm itself unchanged since before the report; no config fix needed). Root cause not established - vanished on herdr upgrade, never reproduced under 0.9.0. If it recurs, reopen and define the exact failure mode (no matches vs garbage matches vs input glitches) before investigating.

- #2 [2026-09-13] herdr remote session intermittently loses state on ssh in - FIXED and verified.
  - Root cause: NFS-shared home + session identity keyed on `$HOME` with no hostname component. Multiple `herdr server` processes ended up bound to the same socket path (7 at peak on slurm-b200-201-219, from Aug 29 to Sep 13); connects reached an arbitrary one, `prepare_socket_path`'s connect-test-then-remove is not NFS-atomic, `herdr status` misreported "not running" while servers were live. A new ssh could silently attach to an empty/freshly-restored server - the "reset session" experience.
  - Fix shipped (commits f7a7c81 + 80536df, deployed 2026-09-13):
    1. Per-host session name over ssh: `main-$(hostname -s)` in BOTH zshrc and bashrc.linux (remote login shell is bash - bashrc is the actual boot path; zshrc-only was the first attempt and missed).
    2. Attach-only boot: probe `herdr --session <name> status` before booting; no live server -> plain shell + message, never a silent spawn. Spawn allowed only with `LC_HERDR_ALLOW_SPAWN=1` (LC_ prefix passes sshd AcceptEnv).
    3. gssh sends `LC_HERDR_ALLOW_SPAWN=1` on first connection only; reconnects always attach.
  - Verified: stub-harness branch matrices for both shells (4 cases each), gssh loop flag toggling, live on remote - single server, `sessions/main-slurm-b200-201-219/`, plain ssh attaches same session. Old 7 servers killed, stale sockets cleaned.
  - Remaining follow-ups: upstream issue draft at `~/.claude/jobs/98ce5ce0/tmp/herdr-nfs-socket-race-issue.md` - NOT yet filed with herdrdev/herdr (user to approve publishing).
  - 2026-09-13 superseded: herdr 0.9 multi-machine replaced the entire remote-boot workflow (commit fcb2e4e). WezTerm launches plain zsh; `machine add` manages remote servers; shell boot blocks + gssh/sshh deleted. Stale `sessions/main/` deleted from cluster home. The per-host session names live on as `--remote-session` values in the machine profiles (`main-slurm-b200-201-219`, `main-coreweave`) - distinct names still required on the NFS-shared home.
