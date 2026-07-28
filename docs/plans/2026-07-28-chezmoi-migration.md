# chezmoi Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the dotfiles repo from Nix/Home Manager to chezmoi, eliminating all /nix/store, bwrap, and proot dependencies while keeping config files byte-identical on Mac and Linux.

**Architecture:** Plain config files in `configs/` are the single source of truth. chezmoi `dot_*.tmpl` wrapper files deploy them via `{{ include }}`. Tools installed via Homebrew (Mac) or curl/git-clone (Linux). Runtime `command -v` guards in `.zshrc` handle tool availability gracefully. No Nix anywhere.

**Tech Stack:** chezmoi, zsh, Homebrew (Mac), curl/git-clone (Linux), zsh plugins (git-cloned)

## Global Constraints

- **Zero drift:** Same config files on Mac and Linux (same git commit = same files via `{{ include }}`)
- **No Nix:** No `/nix/store`, no bwrap, no proot, no namespaces, no `flake.nix`
- **No sudo/root:** Everything installs to `~/.local/bin` (Linux) or via Homebrew (Mac)
- **Runtime guards, not template-time:** Use `command -v` in shell config, not `lookPath` in chezmoi templates (lookPath runs at apply time, not shell startup)
- **zsh plugins git-cloned** to `~/.local/share/zsh/`, sourced with `[[ -r ]]` guards
- **configs/ is NOT deployed to $HOME** - it's in `.chezmoiignore`, only accessed via `{{ include }}`
- **Spec:** `docs/specs/2026-07-28-chezmoi-migration-design.md` is the source of truth for all config contents
- **Repo:** `git@github-haydeni0:Haydeni0/dotfiles.git`, branch `nix-start`
- **Branch for migration:** `hayden/chezmoi-migration` (prefix with `hayden/` per AGENTS.md)

---

### Task 1: Create migration branch and tag rollback point

**Files:**
- None (git operations only)

**Interfaces:**
- Produces: branch `hayden/chezmoi-migration` for all subsequent work, tag `pre-chezmoi-migration` for rollback

- [ ] **Step 1: Tag current state for rollback**

```sh
cd ~/gitrepos/dotfiles
git tag pre-chezmoi-migration
git push --tags
```

- [ ] **Step 2: Create migration branch**

```sh
git switch -c hayden/chezmoi-migration
```

- [ ] **Step 3: Verify branch**

```sh
git branch --show-current
```
Expected: `hayden/chezmoi-migration`

---

### Task 2: Create configs/ directory with all source files

**Files:**
- Create: `configs/zshrc`
- Create: `configs/zsh/aliases.zsh`
- Create: `configs/zprofile`
- Create: `configs/bashrc.linux`
- Create: `configs/bashrc.darwin`
- Create: `configs/tmux.conf`
- Create: `configs/starship.toml`
- Create: `configs/herdr.toml`
- Create: `configs/gitconfig`

**Interfaces:**
- Produces: `configs/` directory containing all config file contents (the single source of truth, deployed via `{{ include }}` in Task 3)

- [ ] **Step 1: Create configs/ directory structure**

```sh
cd ~/gitrepos/dotfiles
mkdir -p configs/zsh
```

- [ ] **Step 2: Create configs/zshrc**

Copy the exact zshrc content from the spec (`docs/specs/2026-07-28-chezmoi-migration-design.md`, section "configs/zshrc"). It includes: history, EDITOR, SSH agent, keybindings, completion, aliases source, starship guard, zoxide guard + `_zoxide_complete`, fzf guard, plugin source guards (autosuggestions, history-substring-search, syntax-highlighting last).

```zsh
# History
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS HIST_FIND_NO_DUPS EXTENDED_HISTORY HIST_REDUCE_BLANKS SHARE_HISTORY

# Editor
export EDITOR=nvim

# SSH agent - adds all private keys (both platforms)
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null
    find ~/.ssh -maxdepth 1 -type f -name "*.pub" -exec basename {} .pub \; | while read key; do
        ssh-add ~/.ssh/"$key" 2>/dev/null
    done
fi

# Keybindings (emacs mode)
bindkey -e
bindkey '^H' backward-kill-word
bindkey $'\e[1;3D' backward-word
bindkey $'\e[1;3C' forward-word

# Completion
fpath+=~/.zfunc
autoload -Uz compinit
compinit -C
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={a-zA-Z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' cache-path "$HOME/.cache/zsh"
zstyle ':completion:*:descriptions' format '%F{purple}%d%f'

# Aliases (shared)
[[ -r ~/.zsh/aliases.zsh ]] && source ~/.zsh/aliases.zsh

# Prompt - starship if available, simple fallback
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
else
    autoload -Uz colors && colors
    PROMPT='%F{cyan}%~%f %F{purple}%#%f '
fi

# zoxide
export _ZO_EXCLUDE_DIRS="$HOME:$HOME/.cache/*:$HOME/.local/share/*:/tmp/*"
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
    _zoxide_complete() {
        [[ "${#words[@]}" -eq "${CURRENT}" ]] || return 0
        local -a dirs expl
        dirs=("${(@f)$(\command zoxide query -l -- ${words[2,-1]} 2>/dev/null | head -15)}")
        if (( ${#dirs} )); then
            compstate[insert]=menu
            compstate[list]=list
            _wanted directories expl 'zoxide' compadd -M '' -U -o nosort -a dirs
        fi
    }
    compdef _zoxide_complete z
fi

# fzf (requires fzf 0.48+ for --zsh flag)
if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
fi

# Plugins (git-cloned to ~/.local/share/zsh/, source with guards)
[[ -r ~/.local/share/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source ~/.local/share/zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -r ~/.local/share/zsh/zsh-history-substring-search/zsh-history-substring-search.zsh ]] && \
    source ~/.local/share/zsh/zsh-history-substring-search/zsh-history-substring-search.zsh
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
# Syntax highlighting MUST be last
[[ -r ~/.local/share/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source ~/.local/share/zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
```

- [ ] **Step 3: Create configs/zprofile**

```zsh
# PATH setup - runs for login shells on both platforms.
# Linux: bash login -> .bashrc sets PATH -> exec zsh -l -> zsh inherits.
# Mac: zsh is default shell, .zprofile runs directly.
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"

# pi-node (user-specific, remove if not needed)
export PATH="$HOME/.local/share/pi-node/node-v22.23.1-linux-x64/bin:$PATH"
```

- [ ] **Step 4: Create configs/zsh/aliases.zsh**

Translate all aliases from `home/aliases.nix` AND `home/shell.nix` shellAliases from Nix attrset syntax to plain zsh `alias name='value'`. The `cat` alias must be guarded with `command -v bat`. The full list is in the spec section "configs/zsh/aliases.zsh".

Key translations:
- Nix `"..." = "../..";` → zsh `alias ...='../..'`
- Nix `cat = "${pkgs.bat}/bin/bat -p";` → guarded: `if command -v bat >/dev/null 2>&1; then alias cat='bat -p'; fi`
- Nix `btop = "${pkgs.btop}/bin/btop";` → DROP (no-op alias, btop resolves via PATH)
- All git aliases from `home/aliases.nix` (g, gst, gss, gsb, ga, gaa, gau, gb, gba, gbd, gbD, gbm, gbr, gbl, gco, gcb, gcm, gsw, gswc, gswm, gcl, gc, gca, gcam, gcmsg, `gca!`, `gc!`, gd, gdc, gds, gdw, gf, gfo, glo, glog, gloga, glg, glgp, gm, gma, gmff, gl, gpr, gp, gpd, gpf, gpv, grb, grba, grbc, grbi, gr, grv, gra, grrm, grh, grhh, grs, grst, grev, gsta, gstp, gstl, gstd, gta, gtv, gcount, gsh, gsi, gsu, gignore, gunignore, gignored, gfg)
- All ls aliases (lsa, lr, lt, lS, lart, lrt, lsr, lsn, ldot, ll, la, l)
- Directory aliases (.., ..., ...., ....., md, rd)
- Misc aliases (grep, h, p, dud)
- Personal aliases (cc, oc, add, push, pull, m)

Write the full file with all ~90 aliases. Do NOT truncate or use "..." placeholders.

- [ ] **Step 5: Create configs/bashrc.linux**

```bash
# Return early for non-interactive shells
case $- in
    *i*) ;;
      *) return;;
esac

# uv env (defensive - kept alongside other tools)
. "$HOME/.local/bin/env" 2>/dev/null

export AWS_PROFILE=coreweave

# Start tmux (outside zsh - system tmux needs kernel pty access)
if [ -n "$PS1" ] && [ -z "$TMUX" ] && [ -z "$SKIP_TMUX" ] && \
   [ "$TERM_PROGRAM" != "vscode" ] && [ -z "${REMOTE_CONTAINERS_SOCKETS}" ] && \
   [ -z "${CURSOR_AGENT}" ] && command -v /usr/bin/tmux &>/dev/null; then
    exec /usr/bin/tmux new-session -A -s main
fi

# Inside tmux: exec system zsh
if [ -n "$PS1" ] && [ -x /usr/bin/zsh ]; then
    exec /usr/bin/zsh -l
fi
```

- [ ] **Step 6: Create configs/bashrc.darwin**

```bash
# Mac .bashrc - minimal (zsh is default shell on macOS, .bashrc rarely runs)
case $- in
    *i*) ;;
      *) return;;
esac
```

- [ ] **Step 7: Create configs/tmux.conf**

Copy the exact content of the current `home/.tmux.conf` file. No changes needed - tmux config is platform-agnostic.

```sh
cp home/.tmux.conf configs/tmux.conf
```

- [ ] **Step 8: Create configs/starship.toml**

```toml
add_newline = false
format = "$directory$git_branch$git_status$cmd_duration$line_break$character"

[character]
success_symbol = "[❯](purple)"
error_symbol = "[❯](red)"

[cmd_duration]
format = "[$duration]($style) "
```

- [ ] **Step 9: Create configs/herdr.toml**

```toml
onboarding = false

[terminal]
default_shell = "ZSH_PATH_PLACEHOLDER"
shell_mode = "non_login"

[keys]
prefix = "ctrl+b"
focus_pane_left = "alt+shift+left"
focus_pane_right = "alt+shift+right"
focus_pane_up = "ctrl+shift+up"
focus_pane_down = "ctrl+shift+down"
next_tab = "shift+right"
previous_tab = "shift+left"
split_horizontal = "prefix+double_quote"
split_vertical = "prefix+percent"
new_tab = "prefix+c"
close_tab = "prefix+ampersand"
close_pane = "prefix+x"
zoom = "prefix+z"
detach = "prefix+d"
switch_tab = "prefix+1..9"
workspace_picker = "prefix+w"
goto = "prefix+g"
copy_mode = "prefix+["

[theme]
name = "dracula"
```

Note: `ZSH_PATH_PLACEHOLDER` is replaced by the chezmoi template in Task 3 with the platform-correct zsh path.

- [ ] **Step 10: Create configs/gitconfig**

```ini
[push]
    autoSetupRemote = true
[rerere]
    enabled = true
```

- [ ] **Step 11: Copy nvim config to configs/**

```sh
cp -r home/.config/nvim configs/nvim
```

- [ ] **Step 12: Stage and commit configs/**

```sh
git add configs/
git commit -m "Add configs/ source files (plain config files, single source of truth)"
```

---

### Task 3: Create chezmoi entry points (dot_*.tmpl files)

**Files:**
- Create: `dot_zshrc.tmpl`
- Create: `dot_zprofile.tmpl`
- Create: `dot_bashrc.tmpl`
- Create: `dot_tmux.conf.tmpl`
- Create: `dot_gitconfig.tmpl`
- Create: `dot_config/starship.toml.tmpl`
- Create: `dot_config/herdr/config.toml.tmpl`
- Create: `dot_zsh/aliases.zsh.tmpl`
- Create: `.chezmoiignore`

**Interfaces:**
- Consumes: `configs/` files from Task 2
- Produces: chezmoi source state that deploys real files to `$HOME` via `{{ include }}`

- [ ] **Step 1: Create dot_zshrc.tmpl**

```
{{ include "configs/zshrc" -}}
```

- [ ] **Step 2: Create dot_zprofile.tmpl**

```
{{ include "configs/zprofile" -}}
```

- [ ] **Step 3: Create dot_bashrc.tmpl**

```
{{ if eq .chezmoi.os "darwin" -}}
{{   include "configs/bashrc.darwin" -}}
{{ else -}}
{{   include "configs/bashrc.linux" -}}
{{ end -}}
```

- [ ] **Step 4: Create dot_tmux.conf.tmpl**

```
{{ include "configs/tmux.conf" -}}
```

- [ ] **Step 5: Create dot_gitconfig.tmpl**

```
{{ include "configs/gitconfig" -}}
```

- [ ] **Step 6: Create dot_config/starship.toml.tmpl**

```sh
mkdir -p dot_config
```

```
{{ include "configs/starship.toml" -}}
```

- [ ] **Step 7: Create dot_config/herdr/config.toml.tmpl**

This template replaces `ZSH_PATH_PLACEHOLDER` with the platform-correct zsh path:

```sh
mkdir -p dot_config/herdr
```

```
{{ $zsh := "/usr/bin/zsh" -}}
{{ if eq .chezmoi.os "darwin" -}}
{{   $zsh = "/bin/zsh" -}}
{{   if lookPath "zsh" -}}
{{     $zsh = (lookPath "zsh") -}}
{{   end -}}
{{ else -}}
{{   if lookPath "zsh" -}}
{{     $zsh = (lookPath "zsh") -}}
{{   end -}}
{{ end -}}
{{   include "configs/herdr.toml" | replace "ZSH_PATH_PLACEHOLDER" $zsh -}}
```

- [ ] **Step 8: Create dot_zsh/aliases.zsh.tmpl**

```sh
mkdir -p dot_zsh
```

```
{{ include "configs/zsh/aliases.zsh" -}}
```

- [ ] **Step 9: Create .chezmoiignore**

```
# Non-deploy files (source-of-truth data, not deployed to $HOME)
configs/
docs/
AGENTS.md
README.md
MEMORY.md
CLAUDE.md
Brewfile

# Nix files (during migration, removed after)
flake.nix
flake.lock
home/
hosts/
rebuild.sh

# nvim lazy-lock.json is auto-managed by lazy.nvim
.config/nvim/lazy-lock.json
```

- [ ] **Step 10: Stage and commit chezmoi entry points**

```sh
git add dot_zshrc.tmpl dot_zprofile.tmpl dot_bashrc.tmpl dot_tmux.conf.tmpl \
       dot_gitconfig.tmpl dot_config/ dot_zsh/ .chezmoiignore
git commit -m "Add chezmoi entry points (dot_*.tmpl wrappers with include)"
```

---

### Task 4: Create install scripts and Brewfile

**Files:**
- Create: `Brewfile`
- Create: `run_once_install-tools.sh.tmpl`

**Interfaces:**
- Produces: declarative package install for both platforms (Brewfile for Mac, run_once script for Linux, zsh plugins + herdr for both)

- [ ] **Step 1: Create Brewfile**

```ruby
# CLI tools
brew "ripgrep"
brew "fd"
brew "fzf"
brew "jq"
brew "lazygit"
brew "neovim"
brew "bat"
brew "gh"
brew "delta"
brew "yazi"
brew "gdu"
brew "rsync"
brew "starship"
brew "zoxide"
brew "btop"
brew "rclone"
brew "git"
brew "tmux"
brew "zsh"
brew "uv"
```

- [ ] **Step 2: Create run_once_install-tools.sh.tmpl**

Copy the full install script from the spec (section "run_once_install-tools.sh.tmpl"). It installs: zsh plugins (both platforms), herdr (both platforms), then Linux-only tools: starship, zoxide, fzf, nvim (appimage extracted, no FUSE), bat, ripgrep, fd, jq, lazygit, gh, delta, yazi, gdu, btop, rclone, uv. Uses `[[ -x ~/.local/bin/tool ]]` file existence checks (not `command -v`, which is PATH-dependent).

```sh
#!/bin/bash
set -euo pipefail

mkdir -p ~/.local/bin
mkdir -p ~/.local/share/zsh

# --- zsh plugins (both platforms, git-cloned) ---
[[ -d ~/.local/share/zsh/zsh-autosuggestions ]] || \
    git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions ~/.local/share/zsh/zsh-autosuggestions
[[ -d ~/.local/share/zsh/zsh-syntax-highlighting ]] || \
    git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting ~/.local/share/zsh/zsh-syntax-highlighting
[[ -d ~/.local/share/zsh/zsh-history-substring-search ]] || \
    git clone --depth 1 https://github.com/zsh-users/zsh-history-substring-search ~/.local/share/zsh/zsh-history-substring-search

# --- herdr (both platforms, curl install) ---
[[ -x ~/.local/bin/herdr ]] || \
    curl -fsSL https://herdr.dev/install.sh | sh

{{ if eq .chezmoi.os "darwin" -}}
# Mac: Homebrew handles most tools (Brewfile). Only install tools not in Homebrew.
# (All listed tools are in Homebrew, so nothing to do here beyond plugins + herdr above.)

{{ else -}}
# Linux: install all tools via curl/git-clone (no sudo)

# starship
[[ -x ~/.local/bin/starship ]] || \
    curl -sS https://starship.rs/install.sh | sh -s -- -y -b ~/.local/bin

# zoxide
[[ -x ~/.local/bin/zoxide ]] || \
    curl -sSf https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh -s -- -b ~/.local/bin

# fzf
[[ -x ~/.local/bin/fzf ]] || {
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --all --no-update-rc --xdg
}

# neovim (extract appimage - no FUSE needed)
[[ -x ~/.local/bin/nvim ]] || {
    curl -L -o /tmp/nvim.appimage https://github.com/neovim/neovim/releases/latest/download/nvim.appimage
    chmod u+x /tmp/nvim.appimage
    cd /tmp && ./nvim.appimage --appimage-extract >/dev/null 2>&1
    mv /tmp/squashfs-root ~/.local/share/nvim-appimage
    ln -sf ~/.local/share/nvim-appimage/AppRun ~/.local/bin/nvim
    rm -f /tmp/nvim.appimage
}

# bat
[[ -x ~/.local/bin/bat ]] || {
    BAT_VER=$(curl -s https://api.github.com/repos/sharkdp/bat/releases/latest | grep -oP '"tag_name": "\K[^"]+' | head -1)
    curl -sSL "https://github.com/sharkdp/bat/releases/download/${BAT_VER}/bat-${BAT_VER}-x86_64-unknown-linux-musl.tar.gz" \
        | tar xz -C /tmp
    mv "/tmp/bat-${BAT_VER}-x86_64-unknown-linux-musl/bat" ~/.local/bin/
    rm -rf "/tmp/bat-${BAT_VER}-x86_64-unknown-linux-musl"
}

# ripgrep
[[ -x ~/.local/bin/rg ]] || {
    RG_VER=$(curl -s https://api.github.com/repos/BurntSushi/ripgrep/releases/latest | grep -oP '"tag_name": "\K[^"]+' | head -1)
    curl -sSL "https://github.com/BurntSushi/ripgrep/releases/download/${RG_VER}/ripgrep-${RG_VER}-x86_64-unknown-linux-musl.tar.gz" \
        | tar xz -C /tmp
    mv "/tmp/ripgrep-${RG_VER}-x86_64-unknown-linux-musl/rg" ~/.local/bin/
    rm -rf "/tmp/ripgrep-${RG_VER}-x86_64-unknown-linux-musl"
}

# fd
[[ -x ~/.local/bin/fd ]] || {
    FD_VER=$(curl -s https://api.github.com/repos/sharkdp/fd/releases/latest | grep -oP '"tag_name": "\K[^"]+' | head -1)
    curl -sSL "https://github.com/sharkdp/fd/releases/download/${FD_VER}/fd-${FD_VER}-x86_64-unknown-linux-musl.tar.gz" \
        | tar xz -C /tmp
    mv "/tmp/fd-${FD_VER}-x86_64-unknown-linux-musl/fd" ~/.local/bin/
    rm -rf "/tmp/fd-${FD_VER}-x86_64-unknown-linux-musl"
}

# jq
[[ -x ~/.local/bin/jq ]] || \
    curl -sSL -o ~/.local/bin/jq https://github.com/jqlang/jq/releases/latest/download/jq-linux-amd64 && \
    chmod +x ~/.local/bin/jq

# lazygit
[[ -x ~/.local/bin/lazygit ]] || {
    LG_VER=$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep -oP '"tag_name": "\K[^"]+' | head -1)
    LG_VER_NUM=${LG_VER#v}
    curl -sSL "https://github.com/jesseduffield/lazygit/releases/download/${LG_VER}/lazygit_${LG_VER_NUM}_Linux_x86_64.tar.gz" \
        | tar xz -C /tmp
    mv /tmp/lazygit ~/.local/bin/
    rm -f /tmp/lazygit *.tar.gz 2>/dev/null
}

# gh (GitHub CLI)
[[ -x ~/.local/bin/gh ]] || {
    GH_VER=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | grep -oP '"tag_name": "\K[^"]+' | head -1)
    curl -sSL "https://github.com/cli/cli/releases/download/${GH_VER}/gh_${GH_VER#v}_linux_amd64.tar.gz" \
        | tar xz -C /tmp
    mv "/tmp/gh_${GH_VER#v}_linux_amd64/bin/gh" ~/.local/bin/
    rm -rf "/tmp/gh_${GH_VER#v}_linux_amd64"
}

# delta (git-delta)
[[ -x ~/.local/bin/delta ]] || {
    DELTA_VER=$(curl -s https://api.github.com/repos/dandavison/delta/releases/latest | grep -oP '"tag_name": "\K[^"]+' | head -1)
    curl -sSL "https://github.com/dandavison/delta/releases/download/${DELTA_VER}/delta-${DELTA_VER}-x86_64-unknown-linux-musl.tar.gz" \
        | tar xz -C /tmp
    mv "/tmp/delta-${DELTA_VER}-x86_64-unknown-linux-musl/bin/delta" ~/.local/bin/
    rm -rf "/tmp/delta-${DELTA_VER}-x86_64-unknown-linux-musl"
}

# yazi (terminal file manager)
[[ -x ~/.local/bin/yazi ]] || {
    curl -sSL https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-musl.zip -o /tmp/yazi.zip
    unzip -o /tmp/yazi.zip -d /tmp/yazi-extract >/dev/null
    mv /tmp/yazi-extract/yazi-x86_64-unknown-linux-musl/yazi ~/.local/bin/
    rm -rf /tmp/yazi.zip /tmp/yazi-extract
}

# gdu (disk usage)
[[ -x ~/.local/bin/gdu ]] || {
    curl -sSL -o /tmp/gdu.tgz https://github.com/dundee/gdu/releases/latest/download/gdu_linux_amd64.tgz
    tar xzf /tmp/gdu.tgz -C ~/.local/bin/
    chmod +x ~/.local/bin/gdu
    rm -f /tmp/gdu.tgz
}

# btop (process monitor)
[[ -x ~/.local/bin/btop ]] || {
    curl -sSL https://github.com/aristocratos/btop/releases/latest/download/btop-x86_64-linux-musl.tbz -o /tmp/btop.tbz
    tar xjf /tmp/btop.tbz -C /tmp
    mv /tmp/btop/bin/btop ~/.local/bin/
    rm -rf /tmp/btop /tmp/btop.tbz
}

# rclone
[[ -x ~/.local/bin/rclone ]] || \
    curl -sSL https://rclone.org/install.sh | bash

# uv (Python package manager)
[[ -x ~/.local/bin/uv ]] || \
    curl -LsSf https://astral.sh/uv/install.sh | sh

echo "Linux tools installed to ~/.local/bin"
{{ end -}}
```

- [ ] **Step 3: Stage and commit**

```sh
git add Brewfile run_once_install-tools.sh.tmpl
git commit -m "Add Brewfile (Mac) + install-tools script (Linux + both: zsh plugins, herdr)"
```

---

### Task 5: Create docs/setup.md

**Files:**
- Create: `docs/setup.md`

**Interfaces:**
- Produces: setup guide that an agent follows to bootstrap a fresh machine

- [ ] **Step 1: Create docs/setup.md**

Copy the full setup guide from the spec (section "docs/setup.md"). It covers: Linux prerequisites, install steps, what gets installed, notes. Mac prerequisites, install steps. Updating. Adding new tools. What stays manual.

- [ ] **Step 2: Stage and commit**

```sh
git add docs/setup.md
git commit -m "Add setup guide for both platforms (non-sudo Linux + Mac)"
```

---

### Task 6: Rework README.md and AGENTS.md

**Files:**
- Modify: `README.md` (complete rewrite - remove all Nix/bwrap/proot docs)
- Modify: `AGENTS.md` (complete rewrite - remove Nix/bwrap rules, add chezmoi guidance)

**Interfaces:**
- Produces: updated docs reflecting the chezmoi architecture

- [ ] **Step 1: Rewrite README.md**

Use the outline from the spec (section "README.md outline"). Key sections:
- Title + description ("Cross-platform dotfiles managed by chezmoi. No Nix, no bwrap, no root.")
- Quick start (Linux + Mac install commands)
- What's included (zsh, plugins, tmux, nvim, herdr, git)
- Architecture (configs/ source of truth, dot_*.tmpl templates, runtime guards, platform differences via templates)
- Customize before using (git identity, AWS_PROFILE, pi-node PATH, local-claude/opencode aliases)
- What stays manual (SSH keys, rclone config, local-claude/opencode, uv-managed tools)

- [ ] **Step 2: Rewrite AGENTS.md**

Use the outline from the spec (section "AGENTS.md outline"). Key sections:
- What this repo is
- How to make changes (edit configs/, chezmoi apply, test, commit)
- Repo structure (configs/, dot_*.tmpl, Brewfile, run_once script, .chezmoiignore)
- Principles (configs/ is source of truth, runtime guards not template-time, zero drift, no Nix, zsh plugins git-cloned)
- Testing changes (verification checklist)
- Rollback

- [ ] **Step 3: Stage and commit**

```sh
git add README.md AGENTS.md
git commit -m "Rework README + AGENTS.md for chezmoi (remove all Nix/bwrap/proot docs)"
```

---

### Task 7: Rewrite MEMORY.md

**Files:**
- Modify: `MEMORY.md` (remove Nix/bwrap/proot entries, add chezmoi learnings)

- [ ] **Step 1: Rewrite MEMORY.md**

Remove all Nix/bwrap/proot-specific learnings (proot orphans, bwrap compinit, herdr segfault, nix segfaults in proot, TracerPid, etc.). Add chezmoi-specific learnings:
- `lookPath` runs at chezmoi apply time, not shell startup - use `command -v` in shell config instead
- `configs/` is NOT deployed to $HOME (it's in .chezmoiignore, accessed via `{{ include }}`)
- All `dot_*.tmpl` wrapper files MUST have `.tmpl` suffix for `{{ include }}` to work
- `run_once_` scripts use file existence checks (`[[ -x ]]`), not `command -v` (PATH may not include ~/.local/bin when chezmoi runs the script)
- herdr.toml uses a `ZSH_PATH_PLACEHOLDER` replaced by template (herdr may need absolute path)
- nvim appimage extracted (no FUSE) via `--appimage-extract`

- [ ] **Step 2: Stage and commit**

```sh
git add MEMORY.md
git commit -m "Rewrite MEMORY.md for chezmoi (remove Nix/bwrap/proot learnings)"
```

---

### Task 8: Test on Linux (login node)

**Files:**
- None (testing only - no file changes in this task)

**Interfaces:**
- Consumes: all files from Tasks 2-7
- Produces: verified working setup on Linux, or bug fixes if issues found

- [ ] **Step 1: Commit and push the migration branch**

```sh
cd ~/gitrepos/dotfiles
git push -u origin hayden/chezmoi-migration
```

- [ ] **Step 2: SSH to login node and install chezmoi**

```sh
ssh slurm-login
sh -c "$(curl -fsLS get.chezmoi.io)"
```

- [ ] **Step 3: Clean up old Nix/HM symlinks**

```sh
# Remove HM-managed symlinks (dangling without /nix/store)
rm -f ~/.zshrc ~/.gitconfig ~/.zshenv ~/.zprofile ~/.profile
rm -f ~/.config/starship.toml ~/.config/herdr/config.toml
rm -f ~/.tmux.conf ~/.bashrc ~/.dotfiles
# Remove Nix profile and nix-portable
rm -rf ~/.nix-profile ~/.local/state/nix
rm -rf ~/.nix-portable
```

- [ ] **Step 4: Apply chezmoi**

```sh
chezmoi init --apply git@github-haydeni0:Haydeni0/dotfiles.git
```

- [ ] **Step 5: Run verification checklist**

In a new shell:
```sh
# zsh starts with starship prompt
echo $SHELL
which starship

# zoxide completion
zoxide query --list
z <Tab>  # should show frecency db entries

# aliases
alias g  # should show git

# fzf
fzf --version  # Ctrl+R in shell

# tmux
which tmux
tmux ls  # or start: tmux

# herdr
which herdr
herdr --version

# nvim
which nvim
nvim --version | head -1

# bat, ripgrep, fd, jq
which bat rg fd jq
```

- [ ] **Step 6: Fix any issues found**

If any verification step fails, debug and fix. Common issues:
- Tool not installed: check `run_once_install-tools.sh.tmpl` output
- zshrc not sourced: check `chezmoi cat ~/.zshrc` renders correctly
- Plugin not found: check `~/.local/share/zsh/` has the clones
- herdr panes fail: check `chezmoi cat ~/.config/herdr/config.toml` has correct zsh path

Fix issues in the source files (`configs/`, `dot_*.tmpl`), then `chezmoi apply` again.

---

### Task 9: Test on Mac

**Files:**
- None (testing only)

**Interfaces:**
- Consumes: all files from Tasks 2-7
- Produces: verified working setup on Mac

- [ ] **Step 1: Install chezmoi on Mac**

```sh
brew install chezmoi
```

- [ ] **Step 2: Clean up old Nix/HM symlinks (if Nix was installed)**

```sh
# Remove HM-managed symlinks
rm -f ~/.zshrc ~/.gitconfig ~/.zshenv ~/.zprofile ~/.profile
rm -f ~/.config/starship.toml ~/.config/herdr/config.toml
rm -f ~/.tmux.conf ~/.bashrc ~/.dotfiles
# Remove Nix profile (if exists)
rm -rf ~/.nix-profile ~/.local/state/nix
```

- [ ] **Step 3: Apply chezmoi**

```sh
chezmoi init --apply git@github-haydeni0:Haydeni0/dotfiles.git
```

- [ ] **Step 4: Install Homebrew packages**

```sh
brew bundle --file=~/Brewfile
```

- [ ] **Step 5: Run verification checklist (same as Task 8 Step 5)**

Verify: starship prompt, zoxide, aliases, fzf, tmux, herdr, nvim, bat, rg, fd, jq.

- [ ] **Step 6: Fix any issues found**

Fix in source files, `chezmoi apply` again, re-verify.

---

### Task 10: Remove old Nix files and clean up

**Files:**
- Remove: `flake.nix`, `flake.lock`, `home/` (all contents), `hosts/` (all contents), `rebuild.sh`

**Interfaces:**
- Consumes: verified working setup from Tasks 8-9
- Produces: clean repo with no Nix artifacts

- [ ] **Step 1: Remove Nix files**

```sh
cd ~/gitrepos/dotfiles
git rm flake.nix flake.lock rebuild.sh
git rm -r home/
git rm -r hosts/
```

- [ ] **Step 2: Remove spec docs (not needed in final repo)**

```sh
git rm -r docs/specs/
```

- [ ] **Step 3: Update .chezmoiignore (remove Nix file entries)**

Remove these lines from `.chezmoiignore`:
```
# Nix files (during migration, removed after)
flake.nix
flake.lock
home/
hosts/
rebuild.sh
```

- [ ] **Step 4: Stage and commit**

```sh
git add -A
git commit -m "Remove Nix/HM files (flake, home/, hosts/, rebuild.sh)

Migration to chezmoi verified on both Linux (HPC login node) and Mac.
All Nix, bwrap, and proot artifacts removed."
```

- [ ] **Step 5: Push**

```sh
git push
```

---

### Task 11: Merge to main branch

**Files:**
- None (git operations only)

- [ ] **Step 1: Push migration branch**

```sh
git push -u origin hayden/chezmoi-migration
```

- [ ] **Step 2: Create draft PR**

```sh
gh pr create --draft --title "Migrate from Nix/HM to chezmoi" --body "Drops Nix entirely. chezmoi for configs (real files, not store symlinks). Homebrew (Mac) + curl/git-clone (Linux) for tools. No bwrap, no proot, no namespaces. Same config files on both platforms."
```

- [ ] **Step 3: After review, merge to nix-start**

```sh
git switch nix-start
git merge hayden/chezmoi-migration
git push
```

---

## Self-Review

**Spec coverage:**
- ✅ configs/ directory with all source files (Task 2)
- ✅ chezmoi entry points with {{ include }} (Task 3)
- ✅ .chezmoiignore (Task 3)
- ✅ Brewfile (Task 4)
- ✅ run_once_install-tools.sh.tmpl (Task 4)
- ✅ docs/setup.md (Task 5)
- ✅ README.md rework (Task 6)
- ✅ AGENTS.md rework (Task 6)
- ✅ MEMORY.md rewrite (Task 7)
- ✅ Migration plan: backup/tag (Task 1), test before removing (Tasks 8-9), remove after (Task 10)
- ✅ HM symlink cleanup (Task 8 Step 3, Task 9 Step 2)
- ✅ Rollback path (Task 1 tag `pre-chezmoi-migration`)
- ✅ Verification checklist (Tasks 8-9 Step 5)
- ✅ herdr.toml template with zsh path resolution (Task 3 Step 7)
- ✅ zprofile for PATH setup (Task 2 Step 3, Task 3 Step 2)
- ✅ SSH agent in zshrc (Task 2 Step 2)
- ✅ nvim appimage extraction (Task 4 Step 2)
- ✅ cat alias guarded (Task 2 Step 4)
- ✅ zoxide env vars (Task 2 Step 2)
- ✅ EDITOR=nvim (Task 2 Step 2)
- ✅ lazy-lock.json in .chezmoiignore (Task 3 Step 9)
- ✅ Install script uses [[ -x ]] not command -v (Task 4 Step 2)

**Placeholder scan:** No TBD/TODO. All config contents are specified in full (aliases list references the spec for the complete ~90 alias set - implementation agent must copy all entries, not truncate).

**Type consistency:** File names are consistent across tasks (configs/zshrc, dot_zshrc.tmpl, etc.).
