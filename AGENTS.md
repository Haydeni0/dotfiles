# AGENTS.md - dotfiles

Guidance for AI coding agents (Claude Code, opencode) working in this repository.
Read `MEMORY.md` at session start for accumulated lessons learned; append to it
when you discover or fix something non-obvious (read it first, then edit - don't
duplicate the README or AGENTS.md).

## What this repo is

A cross-platform dotfiles repo managed by chezmoi. Plain config files in
`configs/` are the source of truth, deployed to `$HOME` via chezmoi templates
(`dot_*.tmpl` with `{{ include }}`). Tools installed via mise (16 CLI tools),
micromamba (zsh), and curl (herdr). No Nix, no bwrap, no proot, no namespaces.

The chezmoi source dir IS the working repo. `chezmoi init` clones it to
`~/.local/share/chezmoi`; edit, commit, and `chezmoi apply` from there. Do not
keep a separate working clone (e.g. `~/gitrepos/dotfiles`) - it drifts from the
source dir and `chezmoi apply` will not see your edits. `~/.dotfiles` is a
symlink to the source dir for easy access (created during setup).

## How to make changes

1. **Edit the source file in `configs/`** (NOT the deployed file in `$HOME`).
   The source dir is `~/.local/share/chezmoi` (= `chezmoi source-path`).
2. **Check for drift**: `chezmoi diff` - shows any local edits to deployed files that
   would be lost. Always run this before applying.
3. **Apply**: `chezmoi apply`
4. **Test in a new shell** - start a new zsh/tmux pane to pick up changes.
5. **Commit + push** - the repo is the source of truth.

Never edit deployed files directly - edit `configs/` and `chezmoi apply`.

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

## Detecting drift

chezmoi deploys **real files** (not read-only symlinks like Nix/HM used). This means
deployed files can be edited directly, but those edits will be **overwritten on the
next `chezmoi apply`** and are not in the repo.

- **Check for drift**: `chezmoi diff` shows differences between deployed files and source.
  Run this before `chezmoi apply` to catch accidental direct edits.
- **Edit source, not deployed files**: `chezmoi edit ~/.zshrc` opens the source file
  (`configs/zshrc`) in `$EDITOR`. This is the correct way to make changes.
- **If a tool installer modifies a deployed file** (e.g. fzf tries to append to `.zshrc`):
  the change is local only. Handle it in `configs/` or `run_once_install-tools.sh.tmpl`
  instead. The install script already uses `--no-update-rc` flags where possible.
- **Revert accidental edits**: `chezmoi apply` overwrites deployed files with source.
  Anything not in `configs/` is lost.

## Testing changes

After `chezmoi apply`, in a new shell:
- `z <tab>` - zoxide completion (frecency db entries, not local subdirs)
- `which starship` - resolves via mise to `~/.local/share/mise/installs/starship/latest/`
- `alias g` - shows `git`
- `herdr` - launches, panes spawn with zsh
- `nvim` - launches, plugins load (lazy.nvim)

Rollback: `chezmoi apply` from a previous git commit, or `git checkout` the
previous state and `chezmoi apply`.
