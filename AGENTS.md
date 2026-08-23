# AGENTS.md - dotfiles

Guidance for AI coding agents (Claude Code, opencode) working in this repository.
Read `MEMORY.md` at session start for accumulated lessons learned; append to it
when you discover or fix something non-obvious (read it first, then edit - don't
duplicate the README or AGENTS.md).

## What this repo is

A cross-platform dotfiles repo managed by chezmoi. Plain config files in
`configs/` are the source of truth, deployed to `$HOME` via chezmoi templates
(`dot_*.tmpl` with `{{ include }}`). Tools installed via mise (17 CLI tools),
micromamba (zsh), and curl (herdr). No Nix, no bwrap, no proot, no namespaces.

The chezmoi source dir IS the working repo. `chezmoi init` clones it to
`~/.local/share/chezmoi`; edit, commit, and `chezmoi apply` from there. Do not
keep a separate working clone (e.g. `~/gitrepos/dotfiles`) - it drifts from the
source dir and `chezmoi apply` will not see your edits. `~/.dotfiles` is a
symlink to the source dir for easy access (created during setup).

## How to make changes

1. **Edit the source file in the repo** (NOT the deployed file in `$HOME`).
   Source lives in `configs/` (templated includes), `dot_config/<tool>/` (plain
   files deployed directly), or `dot_*.tmpl` (entry points). The source dir is
   `~/.local/share/chezmoi` (= `chezmoi source-path`).
2. **Check for drift**: `chezmoi diff` - shows any local edits to deployed files that
   would be lost. Always run this before applying.
3. **Run tests**: `mise run test` (or `./scripts/test`) - validates shell syntax (`zsh -n`,
   `bash -n`), JSON/TOML validity, CRLF prevention, keybinding parity, and template
   rendering for all supported platforms.
4. **Apply**: `chezmoi apply`
5. **Test in a new shell** - start a new zsh/tmux pane to pick up changes.
6. **Commit + push** - the repo is the source of truth.

Never edit deployed files directly - edit the source in this repo, then
`chezmoi apply`. When adding a NEW config, write the source file in the repo
(e.g. `dot_config/<tool>/...`) first, then apply - never write the deployed
file first and backfill.

## Repo structure

- `configs/` - source of truth (plain files, NOT deployed to `$HOME`)
- `dot_*.tmpl` - chezmoi entry points (include from `configs/`)
- `dot_config/nvim/` - nvim config (plain files, deployed directly - exception to the
  configs/ pattern because nvim lua doesn't need templating and `lazy-lock.json` is
  auto-managed by lazy.nvim)
- `Brewfile` - Mac: mise + zsh via Homebrew (deployed to `~/Brewfile`)
- `run_once_install-tools.sh.tmpl` - tool installer (mise for 16 tools, micromamba for zsh, curl for herdr, git-clone for zsh plugins)
- `.chezmoiignore` - files not deployed to `$HOME`
- `docs/setup.md` - setup guide for both platforms

## Principles

- **configs/ is the single source of truth.** Never edit deployed files directly.
- **Runtime guards, not template-time.** Use `command -v` checks in `.zshrc`,
  not `lookPath` in chezmoi templates (lookPath runs at apply time, not shell startup).
- **Zero drift.** Same config files on Mac and Linux. Platform differences handled
  via chezmoi templates (`dot_bashrc.tmpl`, herdr `config.toml.tmpl`).
- **No Nix.** No `/nix/store`, no bwrap, no proot, no namespaces. Tools via mise
  (managed in `~/.local/share/mise/installs/`), zsh via micromamba (`~/.local/bin/zsh`).
- **zsh plugins git-cloned** to `~/.local/share/zsh/`, sourced with `[[ -r ]]` guards.
- **Install scripts use file existence checks** (`[[ -x ~/.local/bin/tool ]]`),
  not `command -v` (PATH may not include `~/.local/bin` when chezmoi runs scripts).
- **mise activate** in `.zshrc` and `.bashrc` puts mise-managed tools on PATH.
- **chezmoi's own config is managed here too.** `~/.config/chezmoi/` is not
  exempt or "meta" - its source lives at `dot_config/chezmoi/`. Edit there,
  never the deployed copy.

## Detecting drift

chezmoi deploys **real files** (not read-only symlinks like Nix/HM used). This means
deployed files can be edited directly, but those edits will be **overwritten on the
next `chezmoi apply`** and are not in the repo.

- **Check for drift**: `chezmoi diff` shows differences between deployed files and source.
  Run this before `chezmoi apply` to catch accidental direct edits.
- **Find unmanaged files**: `chezmoi unmanaged` lists `$HOME` files NOT tracked in
  the repo. Use it to discover configs that have drifted out of management (e.g.
  a tool wrote to `~/.config/` and were never added as source). Bring such files
  into the repo as source, don't edit the deployed copy.
- **Edit source, not deployed files**: `chezmoi edit ~/.zshrc` opens the source file
  (`configs/zshrc`) in `$EDITOR`. This is the correct way to make changes.
- **If a tool installer modifies a deployed file** (e.g. fzf tries to append to `.zshrc`):
  the change is local only. Handle it in `configs/` or `run_once_install-tools.sh.tmpl`
  instead. The install script already uses `--no-update-rc` flags where possible.
- **Revert accidental edits**: `chezmoi apply` overwrites deployed files with source.
  Anything not in `configs/` is lost.
- **Never blindly `chezmoi apply` when `chezmoi diff` shows changes.** When a
  diff appears, **surface it to the user and work through it together** - do not
  resolve it unilaterally. Present the diff, state the likely cause, and let the
  user decide incorporate-vs-overwrite. Common causes:
  - **Hand-edited deployed file** (e.g. a tool appended to `~/.zshrc`): incorporate
    into `configs/` or a `run_once` script, then apply. Do not overwrite real work.
  - **Template resolves differently than last apply** (e.g. `lookPath` finding a
    different binary): fix the template to be deterministic (prefer hardcoded
    paths or `stat`/`isExecutable` over PATH lookups), then apply. Non-deterministic
    templates cause flip-flop drift - they are bugs, not state to preserve.
  - **Intentional local experiment**: safe to overwrite once the user confirms the
    local change isn't worth keeping.
  Only when the cause is known and the user has made the call should `chezmoi apply`
  run. `chezmoi diff` should be empty after a clean apply; if it isn't, the
  remaining diff is an unresolved cause to investigate with the user, not noise to
  ignore.

## Testing changes

### Automated checks
Run `mise run test` (or `./scripts/test`). Validates:
- Syntax of all zsh and bash files (`zsh -n`, `bash -n`)
- Formats of JSON and TOML config files
- No CRLF line endings in tracked files
- Keybinding parity in `configs/zshrc` (Mac `\e[1;3` Opt and Linux/WSL `\e[1;5` Ctrl)
- Multi-platform template compilation (`darwin/arm64`, `darwin/amd64`, `linux/amd64`, `linux/arm64`)
- `.chezmoiignore` invariants

### Manual checks in a new shell
After `chezmoi apply`, in a new shell:
- `z <tab>` - zoxide completion (frecency db entries, not local subdirs)
- `which starship` - resolves via mise to `~/.local/share/mise/installs/starship/latest/`
- `alias g` - shows `git`
- `herdr` - launches, panes spawn with zsh
- `nvim` - launches, plugins load (lazy.nvim)

Rollback: `chezmoi apply` from a previous git commit, or `git checkout` the
previous state and `chezmoi apply`.
