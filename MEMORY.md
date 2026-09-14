---
summary: "Agent long-term memory - tool setup and lessons learned"
read_when:
  - Starting work in this repo
  - Hitting a gotcha that might recur
  - Adding a new tool, wrapper, or integration
---

# MEMORY.md - dotfiles

Long-term memory for AI agents working in this repo. Read at session start;
append to when you discover or fix something non-obvious. Don't duplicate
README architecture here. An entry may expand on an AGENTS.md Principle with
the evidence - commit ref, what broke, the fix - since that provenance is the
value MEMORY.md adds over the rule alone.

Rules:
- One entry per learning, newest at top.
- Date + one-line summary as a `###` heading, then the detail.
- Only verified facts you confirmed this session - no guesses.
- Reference the commit that fixed it.

## Tool Setup

Environment specifics an agent needs to know. Add as discovered.

### Linux cluster (no root)
- Tools installed to `~/.local/bin` (curl/git-clone, no sudo)
- zsh plugins git-cloned to `~/.local/share/zsh/`
- Configs deployed by chezmoi as real files (not store symlinks)
- Login nodes block mount namespaces (but no longer relevant - no bwrap/proot)

### macOS
- Tools installed via Homebrew (Brewfile)
- zsh plugins also git-cloned to `~/.local/share/zsh/` (same as Linux)

## Learnings

### 2026-09-14 - `#!/bin/sh` run_ scripts cannot use `set -o pipefail` on Linux
dash (= /bin/sh on Debian/Ubuntu/HPC nodes) has no pipefail, so `set -euo pipefail`
crashed `chezmoi apply` with `set: Illegal option -o pipefail`
(run_onchange_yazi-plugins.sh, triggered when git.yazi pin change re-ran it).
Fix: `set -eu` - the script had no pipes anyway. Rule for run_ scripts: want
pipefail → `#!/bin/bash`; want POSIX `/bin/sh` → `set -eu` only.
run_onchange_reload-karabiner.sh keeps `#!/bin/sh` + pipefail deliberately:
macOS-only, where /bin/sh is bash-as-sh and accepts pipefail - user decision
2026-09-14, not a bug.

### 2026-09-13 - herdr 0.9 multi-machine replaced the shell-boot herdr workflow
herdr 0.9 (`machine add`) lets one Mac client manage remote servers over ssh in
a single TUI; agents persist because the remote `herdr server` owns them, not
the ssh connection. So all shell-level boot machinery went (commit fcb2e4e):
WezTerm launches plain zsh, herdr runs on demand, remotes never boot herdr from
zshrc/bashrc (`machine add` starts their servers). Machine profiles are
per-machine state (`~/.local/state/herdr/client/endpoints.json`) - deliberately
NOT in this repo; the repo stays portable to non-work machines. gssh/sshh and
the NFS-safe boot guards (per-host session names, attach-only, LC_HERDR_ALLOW_SPAWN)
were deleted with the boot path. Distinct session names remain mandatory on the
NFS-shared cluster home - now via `--remote-session` in the machine profiles.
Gotchas: `herdr update` refuses while any herdr process lives (kill stale
servers first, including ones on remotes); `machine add` needs a TTY (user runs
it, not the agent); no keybindings exist for machine switching yet (mouse-only,
no machine actions in the binary's keymap).

### 2026-09-11 - WORDCHARS controls zsh word-delete granularity; terminal apps have own logic
zsh default `WORDCHARS` (`*?_-.[]~=/&;!#$%^(){}<>`) counts `/ . - _` as word
chars, so ctrl+backspace (`backward-kill-word`) ate whole paths like
`asdasd/asdasd` in one press. Fixed with `WORDCHARS=''` in `configs/zshrc`
(commit db2ab37) - word = alphanumerics only, one press on `asdasd/asdasd`
leaves `asdasd/`. "Weird inconsistency" across apps is expected: zle uses
WORDCHARS, but terminal apps (Claude Code, nvim) parse keys themselves - their
behavior is not fixable from dotfiles. Also learned: pty repro must run AFTER
`chezmoi apply` - spawned zsh reads deployed `~/.zshrc`, not the source dir.
Oracle tip: killed text assertions on trailing-space lines fail - terminal
never renders the trailing space; assert on the executed output instead.

### 2026-09-04 - completion matcher-list `{a-zA-Z}={a-zA-Z}` is an identity no-op
`zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={a-zA-Z}'` looks like
case-insensitive completion but maps each char to itself (m:src=dst is
positional) - zero case folding, `readm`-TAB fails against README.md. Correct
form (what oh-my-zsh ships): `m:{a-zA-Z}={A-Za-z}` (dst swapped: a->A, A->a).
Fixed in `configs/zshrc` line 45. Verified via expect pty repro driving real
interactive zsh: `wc readm`-TAB went from "no such file" to completing
README.md. Repro technique: zpty drain blocks forever without `-t`; use
`expect` (macOS ships it) - spawn `env SKIP_HERDR=1 zsh -i`, sleep 4 for
startup, send prefix + \t, check oracle strings in buffer.

### 2026-08-22 - yazi on Linux requires musl release (gnu build requires glibc 2.39)
Upstream yazi builds `yazi-x86_64-unknown-linux-gnu` on Ubuntu 24.04 requiring GLIBC_2.39,
crashing on Ubuntu 22.04, Debian 12, and HPC nodes (glibc 2.35). Mise's aqua backend
defaults to selecting the gnu release on glibc hosts. Configure yazi as an http backend
installing the musl release (`yazi-...-unknown-linux-musl.zip`) in
`dot_config/mise/config.toml.tmpl` for Linux, while keeping `yazi = "latest"` on macOS.

### 2026-08-31 - gh credential helper in ~/.gitconfig drifts on gh auth login
`gh auth login` / `gh auth setup-git` writes a version-pinned absolute-path
credential helper (`!.../mise/installs/gh/<ver>/.../bin/gh auth git-credential`)
into `~/.gitconfig`. chezmoi-managed `~/.gitconfig` + repo source
`configs/gitconfig` carry the bare PATH-resolved form
(`helper = !gh auth git-credential`) instead. gh does NOT recognize the bare
form as already-configured, so re-login re-introduces the pinned block ->
`chezmoi diff` shows drift; fix = strip pinned blocks from deployed file,
re-apply. Verified live: bare form resolves via mise shims (interactive) and
~/.local/bin/gh (login shells, unmanaged artifact on this machine only -
fresh machines need mise activate on PATH). Identity note: [user] lives in
~/.config/git/config (XDG), NOT ~/.gitconfig.local - earlier entry below
stale on that point.

### 2026-08-22 - .gitattributes prevents CRLF corruption on Windows/WSL
Cloning on Windows or WSL with default `core.autocrlf = true` converts repo files to
CRLF. This breaks script execution (e.g. `run_once_install-tools.sh.tmpl` shebang fails
with `/bin/bash\r: no such file or directory`). Enforce `* text=auto eol=lf` in
`.gitattributes`.

### 2026-08-22 - chezmoi.yaml diff tool needs lookPath guard on bootstrap
Setting `diff: command: delta` in plain `chezmoi.yaml` causes `chezmoi apply -v` to
crash on initial bootstrap before `mise` has installed `delta`. Use
`dot_config/chezmoi/chezmoi.yaml.tmpl` with `{{ if lookPath "delta" }}` so chezmoi uses
the default diff until delta is on PATH.

### 2026-08-22 - git user identity isolated via ~/.gitconfig.local
Putting `[user]` name/email directly in shared `configs/gitconfig` clobbers local
identities across machines (e.g. personal vs work machines). Include
`~/.gitconfig.local` instead and configure identity per-machine.

### 2026-07-28 - chezmoi lookPath runs at apply time, not shell startup
`{{ if lookPath "starship" }}` in chezmoi templates evaluates when `chezmoi apply`
runs, NOT when the shell starts. If you apply on a machine where a tool is on PATH,
then log into a machine where it's not, the rendered config still has the tool line.
Fix: use runtime `command -v` guards in the shell config itself, not template-time
`lookPath` checks.

### 2026-07-28 - configs/ must be in .chezmoiignore
`configs/` is the source-of-truth directory, NOT deployed to `$HOME`. Without
`.chezmoiignore`, chezmoi deploys `~/configs/`, `~/docs/`, `~/README.md` etc.
`{{ include "configs/..." }}` still works when `configs/` is ignored - include
reads from source state, ignore only prevents deployment to the target.

### 2026-07-28 - dot_*.tmpl wrapper files MUST have .tmpl suffix
Without `.tmpl`, chezmoi treats files as plain files (no template processing).
`{{ include "configs/..." }}` silently fails - the file deploys empty. All
wrapper files must be `dot_zshrc.tmpl`, `dot_tmux.conf.tmpl`, etc.

### 2026-07-28 - install scripts should use [[ -x ]] not command -v
`command -v starship` checks PATH, but `~/.local/bin` may not be on PATH when
chezmoi runs `run_once_` scripts (chezmoi runs with the current environment,
not a fresh shell with .bashrc/.zshrc sourced). Use `[[ -x ~/.local/bin/starship ]]`
file existence checks instead.

### 2026-07-28 - herdr.toml needs absolute zsh path (template-resolved)
herdr's `default_shell` may require an absolute path, not a bare command name.
The config uses a `ZSH_PATH_PLACEHOLDER` replaced by the chezmoi template with
the platform-correct path via `lookPath "zsh"` (at apply time, which is correct
here since the path doesn't change between apply and runtime).

### 2026-07-28 - nvim appimage extracted (no FUSE)
AppImages require FUSE to mount the squashfs filesystem. On no-root HPC clusters,
FUSE is often unavailable (`/dev/fuse` missing). Fix: extract the appimage with
`--appimage-extract` and symlink to `AppRun`. No FUSE needed, slightly slower
startup but works everywhere.

### 2026-07-30 - yazi needs `file` cmd + opener override on headless linux
yazi file-open failed on headless CoreWeave box. Two causes:
1. `file` cmd missing → yazi can't detect MIME (uses `file -bL --mime-type` via
   yazi-plugin mime.lua) → everything tagged `null/file1-not-found` → hits
   fallback `open` rule.
2. Default `open` opener on linux = `xdg-open %s1`, but `xdg-open` not installed
   (no DE, no GUI apps, no `mimeapps.list`).
Fix: (a) install `file` via micromamba (`run_once_install-tools.sh.tmpl`, conda-forge
`file` pkg, symlink to `~/.local/bin/file` - binary finds libmagic via realpath so
symlink works). (b) override yazi `[opener].open` linux entry → `${EDITOR:-nvim} %s`
in `dot_config/yazi/yazi.toml`. yazi merges `[opener]` as HashMap<String, Vec> -
user config replaces only named opener (`open`); `edit`/`play`/`reveal` stay at
defaults. Text/code/json still route to `edit` (nvim); images/unknown now route
to `open` (nvim). Config now chezmoi-managed (was hand-created, untracked).
Note: do NOT install xdg-open - useless on headless box, nothing to launch.

### 2026-07-28 - zoxide completion: use db entries not local subdirs
zoxide's default `z <tab>` shows local subdirectories (`_cd -/`), NOT the frecency
database. The custom `_zoxide_complete` function queries `zoxide query -l` instead,
showing frecency-ranked db entries (matching omz z plugin behavior). Key flags:
`-M ''` (disable matcher-list, fixes `/` prefix issue), `-o nosort` (preserve
frecency order), `compstate[insert]=menu` (Tab cycling). From zoxide issue #513.
