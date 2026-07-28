# Design: Migrate from Nix/HM to chezmoi (no-namespace, cross-platform)

## Problem

The current Nix + nix-portable + bwrap setup has fundamental issues on the HPC cluster:
- Login nodes block mount namespaces, so bwrap can't run, so `/nix/store` doesn't resolve, so HM-managed symlinks dangle, so zsh can't load config
- bwrap adds startup overhead to every shell
- proot (the fallback) has documented issues: SIGINT ignored, D-state cascade, nix segfaults
- The entire namespace virtualization layer exists only because `/nix` can't be created without root

Nix-built binaries hardcode `/nix/store/...` paths in their ELF interpreter. Without root to create `/nix`, or mount namespaces to bind-mount it, these binaries cannot run. No config manager changes this.

## Decision

Drop Nix entirely. Use chezmoi for config deployment (real files, not store symlinks) on both Mac and Linux. Install tools via platform-native methods (Homebrew on Mac, curl/git-clone on Linux). No `/nix/store` dependency anywhere.

## Architecture

**Single source of truth:** plain config files in `configs/`, deployed by chezmoi on both platforms via `{{ include }}` templates. Same files, same content, zero drift. Tools installed via declarative package lists (Brewfile on Mac, install script on Linux). Runtime `command -v` guards in `.zshrc` handle tool availability gracefully.

## Package list (from current Nix config, translated)

### CLI tools (both platforms)
- ripgrep, fd, fzf, jq, lazygit, neovim, bat, gh, delta, yazi, gdu, rsync, uv
- starship (prompt), zoxide (directory jumping), btop (process monitor), rclone (cloud sync)
- herdr (agent multiplexer)

### zsh plugins (both platforms, git-cloned to ~/.local/share/zsh/)
- zsh-autosuggestions
- zsh-syntax-highlighting
- zsh-history-substring-search

### Mac-only (via Homebrew)
- git, tmux, zsh (macOS system versions may be old; brew provides current)

### Linux-only (system packages or curl install)
- git, tmux, zsh (system-provided on HPC cluster)

## Repo structure

```
dotfiles/
├── configs/                              # Plain files - THE source of truth (NOT deployed directly)
│   ├── zshrc                             # .zshrc content (runtime guards, both platforms)
│   ├── zsh/
│   │   └── aliases.zsh                    # Sourced by zshrc (~90 omz-style aliases)
│   ├── bashrc.linux                      # Linux .bashrc (tmux launch, no bwrap)
│   ├── bashrc.darwin                     # Mac .bashrc (minimal)
│   ├── zprofile                          # PATH setup (both platforms, login shells)
│   ├── tmux.conf                         # Same everywhere
│   ├── starship.toml                     # Same everywhere
│   ├── herdr.toml                        # herdr config
│   ├── gitconfig                         # git config
│   └── nvim/                             # nvim config (lua)
├── dot_zshrc.tmpl                        # chezmoi: {{ include "configs/zshrc" }}
├── dot_bashrc.tmpl                       # chezmoi: platform-conditional via include
├── dot_zprofile.tmpl                     # chezmoi: {{ include "configs/zprofile" }}
├── dot_tmux.conf.tmpl                    # chezmoi: {{ include "configs/tmux.conf" }}
├── dot_gitconfig.tmpl                    # chezmoi: {{ include "configs/gitconfig" }}
├── dot_config/
│   ├── starship.toml.tmpl                # chezmoi: {{ include "configs/starship.toml" }}
│   └── herdr/
│       └── config.toml.tmpl              # chezmoi: {{ include "configs/herdr.toml" }}
├── dot_zsh/
│   └── aliases.zsh.tmpl                  # chezmoi: {{ include "configs/zsh/aliases.zsh" }}
├── dot_config_nvim/                      # chezmoi: nvim config (via include or symlink)
├── Brewfile                              # Mac: brew bundle install (declarative package list)
├── run_once_install-tools.sh.tmpl        # BOTH platforms: curl/git-clone tools + zsh plugins
├── .chezmoiignore                        # Ignore non-deploy files (configs/, docs/, etc.)
├── docs/
│   └── setup.md                          # Non-sudo setup guide (both platforms)
├── AGENTS.md                             # Agent guidance (reworked)
└── README.md                             # Full setup docs (reworked)
```

## Config file contents

### .chezmoiignore

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

# nvim lazy-lock.json is auto-managed by lazy.nvim, don't manage with chezmoi
.config/nvim/lazy-lock.json
```

### configs/zprofile (PATH setup, both platforms)

```zsh
# PATH setup - runs for login shells on both platforms.
# Linux: bash login -> .bashrc sets PATH -> exec zsh -l -> zsh inherits.
# Mac: zsh is default shell, .zprofile runs directly.
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"

# pi-node (user-specific, remove if not needed)
export PATH="$HOME/.local/share/pi-node/node-v22.23.1-linux-x64/bin:$PATH"
```

### configs/zshrc

The .zshrc uses runtime `command -v` guards (not chezmoi `lookPath` template-time checks) so it works correctly regardless of when `chezmoi apply` was run vs when the shell starts.

```zsh
# History
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS HIST_FIND_NO_DUPS EXTENDED_HISTORY HIST_REDUCE_BLANKS SHARE_HISTORY

# Editor
export EDITOR=nvim

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

### configs/bashrc.linux

```bash
# Return early for non-interactive shells
case $- in
    *i*) ;;
      *) return;;
esac

# SSH agent - adds all private keys
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null
    find ~/.ssh -maxdepth 1 -type f -name "*.pub" -exec basename {} .pub \; | while read key; do
        ssh-add ~/.ssh/"$key" 2>/dev/null
    done
fi

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

### configs/bashrc.darwin

```bash
# Mac .bashrc - minimal (zsh is default shell on macOS, .bashrc rarely runs)
case $- in
    *i*) ;;
      *) return;;
esac

# SSH agent
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null
    find ~/.ssh -maxdepth 1 -type f -name "*.pub" -exec basename {} .pub \; | while read key; do
        ssh-add ~/.ssh/"$key" 2>/dev/null
    done
fi
```

### dot_bashrc.tmpl

```go
{{ if eq .chezmoi.os "darwin" -}}
{{   include "configs/bashrc.darwin" -}}
{{ else -}}
{{   include "configs/bashrc.linux" -}}
{{ end -}}
```

### dot_zshrc.tmpl, dot_zprofile.tmpl, dot_tmux.conf.tmpl, etc.

Each is a one-liner include:
```go
{{ include "configs/zshrc" -}}
```

### Brewfile (Mac)

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

# herdr (if available via brew; otherwise curl install on both platforms)
# brew "herdr"
```

### run_once_install-tools.sh.tmpl (BOTH platforms)

Installs tools to `~/.local/bin` and zsh plugins to `~/.local/share/zsh/`. Uses file existence checks (not `command -v`, which is PATH-dependent and unreliable when `~/.local/bin` isn't on PATH yet).

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
    YAZI_VER=$(curl -s https://api.github.com/repos/sxyazi/yazi/releases/latest | grep -oP '"tag_name": "\K[^"]+' | head -1)
    curl -sSL "https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-musl.zip" -o /tmp/yazi.zip
    unzip -o /tmp/yazi.zip -d /tmp/yazi-extract >/dev/null
    mv /tmp/yazi-extract/yazi-x86_64-unknown-linux-musl/yazi ~/.local/bin/
    rm -rf /tmp/yazi.zip /tmp/yazi-extract
}

# gdu (disk usage)
[[ -x ~/.local/bin/gdu ]] || \
    curl -sSL -o ~/.local/bin/gdu https://github.com/dundee/gdu/releases/latest/download/gdu_linux_amd64.tgz && \
    tar xzf ~/.local/bin/gdu -C ~/.local/bin/ && \
    chmod +x ~/.local/bin/gdu

# btop (process monitor)
[[ -x ~/.local/bin/btop ]] || {
    BTOP_VER=$(curl -s https://api.github.com/repos/aristocratos/btop/releases/latest | grep -oP '"tag_name": "\K[^"]+' | head -1)
    curl -sSL "https://github.com/aristocratos/btop/releases/latest/download/btop-x86_64-linux-musl.tbz" -o /tmp/btop.tbz
    tar xjf /tmp/btop.tbz -C /tmp
    mv /tmp/btop/bin/btop ~/.local/bin/
    rm -rf /tmp/btop /tmp/btop.tbz
}

# rclone
[[ -x ~/.local/bin/rclone ]] || \
    curl -sSL https://rclone.org/install.sh | bash

# rsync - likely system-provided, skip if not available
[[ -x /usr/bin/rsync ]] || [[ -x ~/.local/bin/rsync ]] || \
    echo "Warning: rsync not found. Install via conda or system package manager."

# uv (Python package manager)
[[ -x ~/.local/bin/uv ]] || \
    curl -LsSf https://astral.sh/uv/install.sh | sh

echo "Linux tools installed to ~/.local/bin"
{{ end -}}
```

### configs/zsh/aliases.zsh

The full alias set from `home/aliases.nix` + `home/shell.nix` shellAliases, translated from Nix attrset syntax to plain zsh. The `cat` alias is guarded to avoid breaking if bat isn't installed.

```zsh
# ls family (from omz lib/directories.zsh + common-aliases)
alias lsa='ls -lah'
alias lr='ls -tRFh'
alias lt='ls -ltFh'
alias lS='ls -1FSsh'
alias lart='ls -1Fcart'
alias lrt='ls -1Fcrt'
alias lsr='ls -lARFh'
alias lsn='ls -1'
alias ldot='ls -ld .*'

# directory navigation
alias ..='cd ..'
alias ...='../..'
alias ....='../../..'
alias .....='../../../..'
alias md='mkdir -p'
alias rd=rmdir

# common misc
alias grep='grep --color'
alias h=history
alias p='ps -f'
alias dud='du -d 1 -h'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# cat -> bat (guarded - bat may not be installed on fresh systems)
if command -v bat >/dev/null 2>&1; then
    alias cat='bat -p'
fi

# git: core
alias g=git
alias gst='git status'
alias gss='git status --short'
alias gsb='git status --short --branch'

# git: add
alias ga='git add'
alias gaa='git add --all'
alias gau='git add --update'

# git: branch
alias gb='git branch'
alias gba='git branch --all'
alias gbd='git branch --delete'
alias gbD='git branch --delete --force'
alias gbm='git branch --move'
alias gbr='git branch --remote'
alias gbl='git blame -w'

# git: checkout / switch
alias gco='git checkout'
alias gcb='git checkout -b'
alias gcm='git checkout main'
alias gsw='git switch'
alias gswc='git switch --create'
alias gswm='git switch main'

# git: clone
alias gcl='git clone --recurse-submodules'

# git: commit
alias gc='git commit --verbose'
alias gca='git commit --verbose --all'
alias gcam='git commit --all --message'
alias gcmsg='git commit --message'
alias 'gca!'='git commit --verbose --all --amend'
alias 'gc!'='git commit --verbose --amend'

# git: diff
alias gd='git diff'
alias gdc='git diff --cached'
alias gds='git diff --staged'
alias gdw='git diff --word-diff'

# git: fetch
alias gf='git fetch'
alias gfo='git fetch origin'

# git: log
alias glo='git log --oneline --decorate'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'
alias glg='git log --stat'
alias glgp='git log --stat --patch'

# git: merge
alias gm='git merge'
alias gma='git merge --abort'
alias gmff='git merge --ff-only'

# git: pull / push
alias gl='git pull'
alias gpr='git pull --rebase'
alias gp='git push'
alias gpd='git push --dry-run'
alias gpf='git push --force-with-lease'
alias gpv='git push --verbose'

# git: rebase
alias grb='git rebase'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'
alias grbi='git rebase --interactive'

# git: remote / reset / restore / revert
alias gr='git remote'
alias grv='git remote --verbose'
alias gra='git remote add'
alias grrm='git remote remove'
alias grh='git reset'
alias grhh='git reset --hard'
alias grs='git restore'
alias grst='git restore --staged'
alias grev='git revert'

# git: stash
alias gsta='git stash push'
alias gstp='git stash pop'
alias gstl='git stash list'
alias gstd='git stash drop'

# git: tag
alias gta='git tag --annotate'
alias gtv='git tag | sort -V'

# git: misc
alias gcount='git shortlog --summary --numbered'
alias gsh='git show'
alias gsi='git submodule init'
alias gsu='git submodule update'
alias gignore='git update-index --assume-unchanged'
alias gunignore='git update-index --no-assume-unchanged'
alias gignored='git ls-files -v | grep "^[[:lower:]]"'
alias gfg='git ls-files | grep'

# personal aliases
alias cc='~/.local/bin/local-claude'
alias oc='~/.local/bin/local-opencode'
alias add='git add .'
alias push='git push'
alias pull='git pull'
alias m='git switch main'
```

### configs/starship.toml

```toml
add_newline = false
format = "$directory$git_branch$git_status$cmd_duration$line_break$character"

[character]
success_symbol = "[❯](purple)"
error_symbol = "[❯](red)"

[cmd_duration]
format = "[$duration]($style) "
```

### configs/gitconfig

```ini
[push]
    autoSetupRemote = true
[rerere]
    enabled = true
```

### configs/herdr.toml

herdr's `default_shell` needs to work on both platforms. The spec uses a chezmoi template to resolve the correct zsh path per platform (herdr may require an absolute path).

**configs/herdr.toml** (the source, uses a placeholder):
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

**dot_config/herdr/config.toml.tmpl** (replaces placeholder with platform-correct path):
```go
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

## docs/setup.md

```markdown
# Setup Guide

## Linux (HPC, no sudo)

### Prerequisites
- zsh installed (`which zsh` - if not available, ask admin or use bash)
- tmux installed (`which tmux`)
- git installed (`which git`)
- unzip installed (for yazi install: `which unzip`)

### Install
```sh
# 1. Install chezmoi
sh -c "$(curl -fsLS get.chezmoi.io)"

# 2. Apply dotfiles (deploys configs + installs tools to ~/.local/bin)
chezmoi init --apply <repo-url>

# 3. Verify
zsh -c 'echo $SHELL; which starship; which zoxide; zoxide query --list'
```

### What gets installed
- starship, zoxide, fzf, nvim, bat, ripgrep, fd, jq, lazygit, gh, delta, yazi, gdu, btop, rclone, uv, herdr → ~/.local/bin
- zsh plugins → ~/.local/share/zsh/
- Configs → ~ (real files, not symlinks to /nix/store)

### Notes
- No /nix/store dependency
- No bwrap/proot/namespace overhead
- Works on login nodes AND compute nodes (same NFS home)
- nvim installed via appimage extraction (no FUSE needed)

## macOS

### Prerequisites
- Homebrew installed (https://brew.sh)
- unzip installed (macOS has it by default)

### Install
```sh
# 1. Install chezmoi
brew install chezmoi

# 2. Apply dotfiles (deploys configs + installs zsh plugins + herdr)
chezmoi init --apply <repo-url>

# 3. Install packages via Homebrew
brew bundle --file=~/Brewfile

# 4. Verify
zsh -c 'echo $SHELL; which starship; which zoxide; zoxide query --list'
```

## Updating
```sh
chezmoi update    # pull + apply
# or
chezmoi git pull && chezmoi apply
```

## Adding new tools
- Mac: add to Brewfile, `brew bundle install`
- Linux: add to run_once_install-tools.sh.tmpl, `chezmoi state delete-bucket --bucket=entryState && chezmoi apply`
- Both: commit + push

## What stays manual (not managed by chezmoi)
- `~/.ssh/` - keys, config, authorized_keys (secrets, never in repo)
- `~/.config/rclone/rclone.conf` - cloud credentials (secrets)
- `~/.local/bin/local-claude`, `local-opencode` - CoreWeave proxies
- uv-managed tools (task, nvitop, hf, evo, graphify) - installed via `uv tool install`
```

## AGENTS.md outline (reworked)

```markdown
# AGENTS.md - dotfiles

## What this repo is
A cross-platform dotfiles repo managed by chezmoi. Plain config files in
`configs/` are the source of truth, deployed to `$HOME` via chezmoi templates.
Tools installed via Homebrew (Mac) or curl/git-clone (Linux). No Nix.

## How to make changes
1. Edit the source file in `configs/` (NOT the deployed file in $HOME)
2. Apply: `chezmoi apply`
3. Test in a new shell
4. Commit + push

## Repo structure
- `configs/` - source of truth (plain files, NOT deployed directly)
- `dot_*.tmpl` - chezmoi entry points (include from configs/)
- `Brewfile` - Mac package list
- `run_once_install-tools.sh.tmpl` - Linux tool installer
- `.chezmoiignore` - files not deployed to $HOME

## Principles
- **configs/ is the single source of truth.** Never edit deployed files
  directly - edit `configs/` and `chezmoi apply`.
- **Runtime guards, not template-time.** Use `command -v` checks in .zshrc,
  not `lookPath` in templates (lookPath runs at apply time, not shell startup).
- **Zero drift.** Same config files on Mac and Linux. Platform differences
  handled via chezmoi templates (dot_bashrc.tmpl, herdr config.toml.tmpl).
- **No Nix.** No /nix/store, no bwrap, no proot, no namespaces. System tools
  + curl-installed binaries in ~/.local/bin.
- **zsh plugins git-cloned**, not package-managed. Source with `[[ -r ]]`
  guards in .zshrc.

## Testing changes
After `chezmoi apply`, in a new shell:
- `z <tab>` - zoxide completion
- `which starship` - resolves to ~/.local/bin/starship
- `alias g` - shows git
- `herdr` - launches, panes spawn with zsh
- `nvim` - launches, plugins load (lazy.nvim)

Rollback: `chezmoi apply` from a previous git commit.
```

## README.md outline (reworked)

```markdown
# dotfiles

Cross-platform dotfiles managed by chezmoi. No Nix, no bwrap, no root.

## Quick start
- Linux: `sh -c "$(curl -fsLS get.chezmoi.io)" && chezmoi init --apply <repo>`
- Mac: `brew install chezmoi && chezmoi init --apply <repo> && brew bundle --file=~/Brewfile`

## What's included
- zsh: history, completion, ~90 aliases, starship prompt, zoxide, fzf
- zsh plugins: autosuggestions, syntax-highlighting, history-substring-search
- tmux: dracula theme, custom keybindings
- neovim: lazy.nvim plugin manager
- herdr: agent multiplexer with tmux-compatible keybindings
- git: autoSetupRemote, rerere

## Architecture
- `configs/` - source of truth (plain files)
- `dot_*.tmpl` - chezmoi templates (include from configs/)
- Runtime `command -v` guards handle tool availability gracefully
- Platform differences via chezmoi templates (.bashrc, herdr config)

## Customize before using
- Username/git identity: edit configs/gitconfig
- AWS_PROFILE: edit configs/bashrc.linux
- pi-node PATH: edit configs/zprofile
- local-claude/local-opencode aliases: edit configs/zsh/aliases.zsh
```

## Migration plan

### Pre-migration
1. **Backup current working setup**: tag the current commit
   ```sh
   git tag pre-chezmoi-migration
   git push --tags
   ```
2. **Create migration branch**: `git switch -c hayden/chezmoi-migration`

### Create new files
3. Create `configs/` directory with all source files (zshrc, zsh/aliases.zsh, bashrc.linux, bashrc.darwin, zprofile, tmux.conf, starship.toml, herdr.toml, gitconfig, nvim/)
4. Create chezmoi entry points (`dot_*.tmpl` files with `{{ include }}`)
5. Create `.chezmoiignore`
6. Create `Brewfile` (Mac)
7. Create `run_once_install-tools.sh.tmpl` (both platforms)
8. Write `docs/setup.md`
9. Rework `README.md` (remove all Nix/bwrap/proot docs, add chezmoi setup)
10. Rework `AGENTS.md` (remove Nix/bwrap rules, add chezmoi guidance)
11. Rewrite `MEMORY.md` (remove Nix/bwrap entries, add chezmoi-specific learnings)

### Test (before removing old files)
12. **Test on Linux**: SSH to login node, clean up HM symlinks, `chezmoi init --apply`, verify
    ```sh
    # Clean up HM-managed symlinks (dangling without /nix/store)
    rm -f ~/.zshrc ~/.gitconfig ~/.zshenv ~/.zprofile ~/.profile
    rm -f ~/.config/starship.toml ~/.config/herdr/config.toml
    rm -f ~/.tmux.conf ~/.bashrc ~/.dotfiles
    rm -rf ~/.nix-profile ~/.local/state/nix
    rm -rf ~/.nix-portable
    # Apply chezmoi
    chezmoi init --apply <repo-url>
    ```
13. **Test on Mac**: clean up HM symlinks, `chezmoi init --apply`, `brew bundle`, verify
14. **Verification checklist** (both platforms):
    - zsh starts with starship prompt
    - `z <tab>` shows zoxide completions
    - `alias g` shows `git`
    - fzf Ctrl+R works
    - tmux launches, prefix key works
    - herdr launches, panes spawn with zsh
    - nvim launches, plugins load
    - `which starship` / `which zoxide` / `which bat` resolve to ~/.local/bin
    - `diff <(chezmoi cat ~/.zshrc) <(chezmoi cat ~/.zshrc)` identical on both platforms

### Clean up
15. Remove old Nix files: `flake.nix`, `flake.lock`, `home/`, `hosts/`, `rebuild.sh`
16. Remove `docs/specs/` (design docs, not needed in final repo)
17. Commit + push
18. Merge migration branch

## What gets removed

- `flake.nix`, `flake.lock` - Nix flake
- `home/*.nix` - all HM modules (packages.nix, shell.nix, aliases.nix, zoxide.nix, herdr.nix, git.nix, editor.nix, tmux.nix, btop.nix, rclone.nix)
- `hosts/remote.nix`, `hosts/nix-zsh` - platform-specific Nix
- `rebuild.sh` - Nix rebuild script
- `home/.bashrc` - replaced by `configs/bashrc.linux` (no bwrap)
- `home/.local/bin/nix-zsh` - bwrap wrapper (no longer needed)
- `home/.config/herdr/config.toml` - replaced by `configs/herdr.toml`
- `home/.tmux.conf` - replaced by `configs/tmux.conf`
- `home/.config/nvim/` - moved to `configs/nvim/`
- All bwrap/proot/namespace references in docs
- `~/.nix-portable/` directory (on Linux, manual cleanup during migration)
- `~/.dotfiles` symlink (no longer needed - chezmoi manages files directly)
- `~/.nix-profile/` (HM profile, removed during migration)

## Reproducibility

- **Config files**: byte-identical on both platforms (same git commit = same files via `{{ include }}`)
- **Package list**: declarative (Brewfile on Mac, install script on Linux) - same list of tools
- **Setup**: `chezmoi init --apply <repo>` + platform package install = identical workspace on any machine
- **Rollback**: `git checkout pre-chezmoi-migration` to restore the Nix setup
