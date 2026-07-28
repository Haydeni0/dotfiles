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

## How to make changes

1. **Edit the source file in `configs/`** (NOT the deployed file in `$HOME`).
2. **Apply**: `chezmoi apply`
3. **Test in a new shell** - start a new zsh/tmux pane to pick up changes.
4. **Commit + push** - the repo is the source of truth.

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

## Testing changes

After `chezmoi apply`, in a new shell:
- `z <tab>` - zoxide completion (frecency db entries, not local subdirs)
- `which starship` - resolves via mise to `~/.local/share/mise/installs/starship/latest/`
- `alias g` - shows `git`
- `herdr` - launches, panes spawn with zsh
- `nvim` - launches, plugins load (lazy.nvim)

Rollback: `chezmoi apply` from a previous git commit, or `git checkout` the
previous state and `chezmoi apply`.
