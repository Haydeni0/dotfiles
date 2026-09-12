# Backlog

Deferred items for this project. Surfaced when starting work here; picked up on request.

## Open

- #1 [2026-09-12] WezTerm ctrl+shift+f scrollback search is buggy - investigate and fix. Careful: fix may require quitting WezTerm (this Claude session runs inside it) - plan around that before touching anything.
- #2 [2026-09-12] herdr remote session intermittently loses state on ssh in. Reliable repro: ssh into a different machine on the same cluster that shares the home dir - herdr resumes with the same panes/windows but blank terminals. Also happened once with gssh reconnecting after a long outage. Suspect shared-socket/session state across machines + reconnect handling.
