{ config, pkgs, ... }:

{
  imports = [ ./aliases.nix ];

  programs.zsh = {
    enable = true;
    enableCompletion = false;  # HM's compinit is slow (stats every fpath file). We run a cached one below.
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = ''
      # Force emacs keymap. zsh 5.9 picks the default interactive keymap from
      # $EDITOR: a value containing "vi" (e.g. nvim) selects vi-insert, which
      # changes Ctrl+Backspace (^H) to single-char delete and lets stray
      # keystrokes enter vi-cmd mode (letters become operators like ~ = toggle case).
      bindkey -e

      # Ctrl+Backspace deletes the word to the left (emacs keymap default is ^W,
      # but terminals send ^H for Ctrl+Backspace, which is single-char by default).
      bindkey '^H' backward-kill-word

      # tmux startup is owned solely by .bashrc (it must run OUTSIDE bwrap -
      # bwrap's namespace breaks pty creation). Do NOT re-launch tmux from zsh: zsh only
      # runs without $TMUX in paths where .bashrc intentionally skipped it
      # (devcontainer, cursor), and exec'ing tmux inside bwrap segfaults.

      # Cursor sends Ctrl+Left/Ctrl+Right as escape sequences ending in D/C.
      # Bind them to zle word movement so Ctrl+Left/Ctrl+Right move by word.
      bindkey $'\e[1;3D' backward-word
      bindkey $'\e[1;3C' forward-word

      # compinit - cached, skip security check (the slow part - stats every fpath file).
      # -C skips the insecure-dir check. .zcompdump caches completions; refreshed when zsh/completions change.
      fpath+=~/.zfunc
      autoload -Uz compinit
      compinit -C

      # zstyle completion tuning (menu select, case-insensitive, caching).
      zstyle ':completion:*' menu select
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={a-zA-Z}' 'r:|=*' 'l:|=* r:|=*'
      zstyle ':completion:*' cache-path "$HOME/.cache/zsh"
      zstyle ':completion:*:descriptions' format '%F{purple}%d%f'

      # fzf: Ctrl+R fuzzy history, Ctrl+T file paste, Alt+C cd.
      source <(${pkgs.fzf}/bin/fzf --zsh)

      # history-substring-search: up/down arrow search history by typed prefix.
      # Type "my_" then up-arrow -> jumps to most recent command starting with "my_".
      source ${pkgs.zsh-history-substring-search}/share/zsh-history-substring-search/zsh-history-substring-search.zsh
      bindkey '^[[A' history-substring-search-up
      bindkey '^[[B' history-substring-search-down

      # History: HM defaults disable these; user setopt runs after HM's, so wins.
      setopt HIST_IGNORE_ALL_DUPS HIST_FIND_NO_DUPS EXTENDED_HISTORY HIST_REDUCE_BLANKS
      HISTSIZE=50000
      SAVEHIST=50000
    '';
    shellAliases = {
      # user's aliases (kept - not the video's cc/co)
      cc = "~/.local/bin/local-claude";
      oc = "~/.local/bin/local-opencode";
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";
      cat = "${pkgs.bat}/bin/bat -p";
      btop = "${pkgs.btop}/bin/btop";  # real btop, not the bpytop alias
      # video's non-conflicting aliases
      ".." = "cd ..";
      add = "git add .";
      push = "git push";
      pull = "git pull";
      m = "git switch main";
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      format = "$directory$git_branch$git_status$cmd_duration$line_break$character";
      character = {
        success_symbol = "[❯](purple)";
        error_symbol = "[❯](red)";
      };
      cmd_duration.format = "[$duration]($style) ";
    };
  };

  home.sessionVariables = {
    EDITOR = "nvim";
  };
}
