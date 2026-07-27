{ config, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = false;  # HM's compinit is slow under proot (stats every fpath file via ptrace). We run a cached one below.
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

      # Start tmux (ported from the user's .zshrc, with SKIP_TMUX escape hatch).
      # Normally tmux is already started by .bashrc (outside proot); this block
      # only fires if zsh starts without tmux AND SKIP_TMUX isn't set.
      if [ -n "$PS1" ] && \
        [ -z "$TMUX" ] && \
        [ -z "$SKIP_TMUX" ] && \
        [ "$TERM_PROGRAM" != "vscode" ] && \
        command -v tmux &>/dev/null; then
        exec tmux new-session -A -s main
      fi

      # Cursor sends Ctrl+Left/Ctrl+Right as escape sequences ending in D/C.
      # Bind them to zle word movement so Ctrl+Left/Ctrl+Right move by word.
      bindkey $'\e[1;3D' backward-word
      bindkey $'\e[1;3C' forward-word

      # compinit - cached, skip security check (the slow part under proot).
      # -C skips the insecure-dir check (stats every fpath file via ptrace = 4s).
      # .zcompdump caches completions; refreshed when zsh/completions change.
      fpath+=~/.zfunc
      autoload -Uz compinit
      compinit -C

      # envman (defensive - kept from the user's setup)
      [ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"
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
