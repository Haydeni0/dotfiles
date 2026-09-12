# Backlog

Deferred items for this project. Surfaced when starting work here; picked up on request.

## Open

- #1 [2026-09-12] WezTerm ctrl+shift+f scrollback search is buggy - investigate and fix. Careful: fix may require quitting WezTerm (this Claude session runs inside it) - plan around that before touching anything.
- #2 [2026-09-12] herdr remote session intermittently loses state on ssh in. Reliable repro: ssh into a different machine on the same cluster that shares the home dir - herdr resumes with the same panes/windows but blank terminals. Also happened once with gssh reconnecting after a long outage. Suspect shared-socket/session state across machines + reconnect handling.
  - Root cause (verified in herdrdev/herdr source, 2026-09-12): all session identity lives in `$HOME` - `~/.config/herdr/herdr-client.sock`, `herdr.sock`, `session.json`. No hostname/machine component in the socket or data paths (`session.rs data_dir_for`). Two machines sharing NFS home = one socket path, one session.json:
    - B's client connects through the NFS-backed socket file to A's live server; NFS timeouts make `is_server_listening_at` misjudge (hang → not listening) → B spawns its own local server.
    - `prepare_socket_path` then sees A's socket as stale/removable, or fails AddrInUse - divergence or clobber.
    - Both servers write `session.json` with no file locking (`persist/io.rs save()`) - last writer wins.
    - Fresh server restores from last-persisted session.json: same layout, panes re-spawned blank (only supported agents resume via `agent_resume.rs`; scrollback only if history persistence enabled).
  - Confirmed live (2026-09-12, slurm-b200-201-219): TWO herdr servers running on the same machine (PIDs from Sep 7 and Sep 9) + stale socket files dated Jul 28; `herdr status` reports "not running" while servers exist. Root cause is active, not theoretical.
  - DECIDED FIX - option A, per-host session name. Change `configs/zshrc` herdr auto-boot from `exec herdr --session main` to:
    ```zsh
    local _herdr_session=main
    [[ -n "$SSH_TTY" || -n "$SSH_CONNECTION" ]] && _herdr_session="main-$(hostname -s)"
    exec herdr --session "$_herdr_session"
    ```
    Each machine then owns `~/.config/herdr/sessions/main-<host>/` - own sockets, own session.json, no cross-machine collision. Trade-off accepted: no "walk to another node, see same panes" - but that never truly worked (blank panes = layout restore, not live attach). Rejected option B (attach-only on remote - friction, semantics unverified). Option C (file upstream issue with herdrdev/herdr - clean two-servers-one-socket repro) still worth doing as a side quest.
  - Rollout constraint: do NOT disrupt current live herdr sessions. Deploy when okay to restart remote herdr: first `ssh <node> 'kill <server-pids>'` to clear the stale duplicates, then `chezmoi apply` on remote (or git pull + apply), then next attach spawns one clean per-host server.
  - Possible fixes to explore: per-host session naming (DECIDED, above), or only ever attach to A's server (socket reachable = attach, never spawn). Upstream may also have guidance - the "several machines, one window" feature (`--remote`) is a separate, deliberate federation mechanism, not this accidental socket sharing.
