# oh-my-zsh-style aliases, curated for daily use.
# Sourced from omz's common-aliases + git plugins, cherry-picked to avoid
# framework overhead. Plain zsh (not Nix attrsets) so it works everywhere.
# Reference: https://github.com/ohmyzsh/ohmyzsh/blob/master/lib/directories.zsh
#            https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/git/git.plugin.zsh

# ls family (from lib/directories.zsh + common-aliases)
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

# cat -> bat, but only for terminal output (not pipes/scripts).
# Falls back to real cat if bat isn't on PATH at call time.
# A plain alias (set once at load) breaks when bat is a lazy mise shim that
# resolves in interactive shells but not in the non-interactive subshells
# scripts spawn (e.g. `cat <<EOF` in a hook). A function checks at call time.
# [[ -t 1 ]] ensures bat only runs when stdout is a terminal - pipes and
# redirects get real cat so tool output parsing isn't affected.
cat() {
    if [[ -t 1 ]] && command -v bat >/dev/null 2>&1; then
        bat -p "$@"
    else
        command cat "$@"
    fi
}

# git: core
alias g=git
alias gst='git status'
alias gss='git status --short'
alias gsb='git status --short --branch'

# git: lazygit (TUI) - installed via mise
alias lg='lazygit'

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
