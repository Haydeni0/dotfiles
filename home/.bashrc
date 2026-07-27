# ~/.bashrc: slimmed - bash launches system tmux, then bwrap zsh inside it.
# tmux must run OUTSIDE bwrap (bwrap's namespace breaks pty creation by tmux).

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

# uv env (defensive - kept alongside Nix)
. "$HOME/.local/bin/env" 2>/dev/null

export AWS_PROFILE=coreweave

# Nix profile setup (nix-portable: /nix is virtualized via bwrap for the shell)
export NIX_PROFILES="$HOME/.nix-profile"
export PATH="$HOME/.nix-profile/bin:$PATH"

# Start system tmux FIRST (outside bwrap - tmux needs kernel pty access).
# Inside tmux, bash runs again, $TMUX is set, so it falls through to the zsh exec below.
# Set SKIP_TMUX=1 to bypass tmux for this session (e.g. to run herdr standalone).
if [ -n "$PS1" ] && \
   [ -z "$TMUX" ] && \
   [ -z "$SKIP_TMUX" ] && \
   [ "$TERM_PROGRAM" != "vscode" ] && \
   [ -z "${REMOTE_CONTAINERS_SOCKETS}" ] && \
   [ -z "${CURSOR_AGENT}" ] && \
   command -v /usr/bin/tmux &>/dev/null; then
    exec /usr/bin/tmux new-session -A -s main
fi

# Inside tmux (or tmux not available): launch Nix zsh via bwrap.
# bwrap creates a mount namespace with ~/.nix-portable/emptyroot as a root
# skeleton, overlays the real /usr, /bin, /etc, /mnt, $HOME, etc. on top, and
# binds ~/.nix-portable/nix -> /nix so HM-managed symlinks resolve.
# Why bwrap not proot: proot ptraces every child to virtualize paths, which
# (a) explicitly ignores SIGINT (proot event.c SIG_IGN), so Ctrl-C can't kill
# a frozen TUI, (b) cascades D-state on NFS stalls - one stuck proot freezes
# all traced children, (c) leaves orphaned tracers after a tmux server crash.
# bwrap uses user+mount namespaces instead - no syscall interception, no
# signal ignoring, no D-state cascade. Requires user namespaces (available
# on this cluster: unshare -U -m succeeds).
# Note: check bwrap binary (real file), NOT `command -v zsh` - the Nix zsh
# symlink dangles outside the namespace (/nix/store doesn't exist on real
# FS), so `command -v zsh` fails and the bridge never fires in new tmux tabs.
if [ -x ~/.nix-portable/bin/bwrap ] && \
   [[ $- == *i* ]] && \
   [[ -z "${REMOTE_CONTAINERS_SOCKETS}" ]] && \
   [[ -z "${CURSOR_AGENT}" ]]; then
    exec ~/.nix-portable/bin/bwrap \
        --bind ~/.nix-portable/emptyroot / \
        --dev-bind /dev /dev \
        --bind ~/.nix-portable/nix /nix \
        --bind /usr /usr --bind /bin /bin --bind /lib /lib --bind /lib64 /lib64 \
        --bind /etc /etc --bind /run /run --bind /var /var --bind /tmp /tmp \
        --bind /mnt /mnt --bind /proc /proc --bind /sys /sys \
        --bind "$HOME" "$HOME" \
        ~/.nix-profile/bin/zsh -l
fi
