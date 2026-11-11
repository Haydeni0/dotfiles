# AGENTS.md - dotfiles

Guidance for AI coding agents (Claude Code, opencode) working in this repository.
Read `MEMORY.md` at session start for accumulated lessons learned; append to it
when you discover or fix something non-obvious (read it first, then edit - don't
duplicate the README or AGENTS.md).

## What this repo is

A cross-platform dotfiles repo managed by chezmoi. Config sources are plain
`dot_*` files (no template needed) or `configs/` fragments where a template
does real work, deployed to `$HOME` by chezmoi. Tools installed via mise
(defined in `dot_config/mise/config.toml`, exact versions + `mise.lock`),
micromamba (zsh), and a pinned, sha256-checked release download (herdr). No
Nix, no bwrap, no proot, no namespaces.

The chezmoi source dir IS the working repo. `chezmoi init` clones it to
`~/.local/share/chezmoi`; edit, commit, and `chezmoi apply` from there. Do not
keep a separate working clone (e.g. `~/gitrepos/dotfiles`) - it drifts from the
source dir and `chezmoi apply` will not see your edits. `~/.dotfiles` is a
symlink to the source dir for easy access (created during setup).

## How to make changes

1. **Edit the source file in the repo** (NOT the deployed file in `$HOME`).
   Source lives in `dot_*` files (plain, deployed directly), `configs/`
   (templated fragments a template does real work on), or `dot_*.tmpl`
   (template entry points). The source dir is
   `~/.local/share/chezmoi` (= `chezmoi source-path`).
2. **Check for drift**: `chezmoi diff` - shows any local edits to deployed files that
   would be lost. Always run this before applying.
3. **Run tests**: `mise run test` from the chezmoi source dir (tasks live in the
   repo-level `mise.toml`; or `./scripts/test` directly) - validates shell syntax
   (`zsh -n`, `bash -n`), JSON/TOML validity, CRLF prevention, keybinding parity,
   and template rendering for all supported platforms. Other tasks: `mise run sync`
   (pull + apply + test, the post-pull dance) and `mise run doctor` (chezmoi health +
   drift summary).
4. **Apply**: `chezmoi apply`
5. **Test in a new shell** - start a new zsh pane to pick up changes.
6. **Update the cheatsheet** if the change is user-facing (a new keybind,
   command, or default) - `docs/cheatsheet.md`, rules at its top.
7. **Commit + push** - the repo is the source of truth.

Never edit deployed files directly - edit the source in this repo, then
`chezmoi apply`. When adding a NEW config, write the source file in the repo
(e.g. `dot_config/<tool>/...`) first, then apply - never write the deployed
file first and backfill.

## Repo structure

- `configs/` - templated fragments a template does real work on (bashrc OS
  variants, herdr.toml, env.sh.tmpl) - NOT deployed to `$HOME`
- `dot_*` / `dot_config/` - plain config sources deployed directly
- `dot_*.tmpl` - template entry points needing per-platform rendering
- `dot_config/nvim/` - nvim config (plain files, deployed directly; `lazy-lock.json`
  is tracked in the repo - runtime updates by lazy.nvim show as drift to fold back in)
- `dot_config/mise/` - mise config (exact tool versions, same file on every platform) and
  `private_mise.lock` (per-platform URL + sha256 for each version; `mise install` rejects a
  mismatch). `mise upgrade --bump` rewrites both deployed files - fold them back with
  `chezmoi re-add ~/.config/mise/config.toml ~/.config/mise/mise.lock`
- `.chezmoiexternal.toml` - pinned zsh plugin archives vendored to `~/.local/share/zsh/`
- `Brewfile` - Mac: mise via Homebrew (plus btop, opencode, GUI casks; deployed to `~/Brewfile`)
- `run_once_install-tools.sh.tmpl` - tool installer (mise for tools, micromamba for zsh,
  git-clone for the NvChad starter; bootstrap downloads - Linux mise, micromamba, herdr -
  are pinned versions checked against sha256s recorded in the script)
- `.chezmoiignore` - files not deployed to `$HOME`
- `mise.toml` - repo-level mise tasks (test/sync/doctor), ignored from deployment
- `docs/setup.md` - setup guide for both platforms
- `~/.zshenv` is managed by the repo (`dot_zshenv.tmpl`: env/PATH via
  `configs/env.sh.tmpl`) and sources unmanaged `~/.zshenv.local` for machine-local
  vars. Env vars that should reach every machine go in `configs/env.sh.tmpl`
  (read by every shell via `~/.zshenv` and login bash).

## Principles

- **`configs/` holds only files a template does real work on.** Everything else is a
  plain `dot_*` source deployed directly. Never edit deployed files directly.
- **Runtime guards, not template-time.** Use `command -v` checks in `.zshrc`,
  not `lookPath` in chezmoi templates (lookPath runs at apply time, not shell startup).
- **Zero drift.** Same config files on Mac and Linux. Platform differences handled
  via chezmoi templates (`dot_bashrc.tmpl`, herdr `config.toml.tmpl`). Two documented
  platform-fact exceptions: WezTerm hardcodes `/bin/zsh` on the Mac (system zsh there),
  and `configs/bashrc.linux` PATH-resolves zsh at runtime for `exec zsh -l` (install
  location varies by machine).
- **No Nix.** No `/nix/store`, no bwrap, no proot, no namespaces. Tools via mise
  (managed in `~/.local/share/mise/installs/`), zsh via micromamba (`~/.local/bin/zsh`).
- **zsh plugins vendored** via `.chezmoiexternal.toml` archive externals
  to `~/.local/share/zsh/`, sourced with `[[ -r ]]` guards.
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
  Run this before `chezmoi apply` to catch accidental direct edits. Bootstrap caveat
  (owned here; the pager config comment points back): before the first `mise install`,
  the diff pager (the mise delta shim, `{{ .chezmoi.homeDir }}`-expanded at
  apply time - chezmoi fork/execs the string directly and never expands `~`)
  is absent and `chezmoi diff` aborts with a `fork/exec ... no such file or directory` error that
  never names the pager config. Apply is unaffected. Re-run diff after install.
- **Find unmanaged files**: `chezmoi unmanaged` lists `$HOME` files NOT tracked in
  the repo. Use it to discover configs that have drifted out of management (e.g.
  a tool wrote to `~/.config/` and were never added as source). Bring such files
  into the repo as source, don't edit the deployed copy.
- **Edit source, not deployed files**: `chezmoi edit ~/.zshrc` opens the source file
  (`dot_zshrc` - a plain source, the entry point itself) in `$EDITOR`. This is the
  correct way to make changes.
- **If a tool installer modifies a deployed file** (e.g. fzf tries to append to `.zshrc`):
  the change is local only. Handle it in the repo source or `run_once_install-tools.sh.tmpl`
  instead.
- **Revert accidental edits**: `chezmoi apply` overwrites deployed files with source.
  Anything not in the repo source is lost.
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
Run `mise run test` (or `./scripts/test`) from the chezmoi source dir. Validates:
- Syntax of all zsh and bash files, plain and rendered per platform (`zsh -n`, `bash -n`)
- Formats of all tracked and rendered JSON, TOML, and YAML config files
- No leftover placeholders in rendered templates
- No CRLF line endings in tracked files
- Keybinding parity in `dot_zshrc` (Mac `\e[1;3` Opt and Linux/WSL `\e[1;5` Ctrl)
- Multi-platform template compilation (`darwin/arm64`, `darwin/amd64`, `linux/amd64`, `linux/arm64`)
- Invariants: no template-time `lookPath`, no bare `command -v` in run_ scripts
  (repo-installed tools resolve by absolute path), no download piped into a
  shell or `tar` in run_ scripts (use `fetch_verified`), no floating
  (`latest`/`lts`) mise versions, `.tmpl` suffix on template
  entry points, externals keys paired with zshrc source guards, CLAUDE.md stays
  a tracked symlink to AGENTS.md (mode 120000 - one source, two names; never
  replace it with a real copy), `.chezmoiignore` keeps its non-deploy sections
  and renders per platform
- Validator presence (bash, zsh, git, rg, jq, uv, chezmoi) - a missing validator
  is a loud failure, never a silent skip
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
