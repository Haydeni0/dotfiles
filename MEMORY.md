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
