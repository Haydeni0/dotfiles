{ config, pkgs, ... }:

{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = ''
      # Start tmux (ported verbatim from the user's .zshrc)
      if [ -n "$PS1" ] && \
        [ -z "$TMUX" ] && \
        [ "$TERM_PROGRAM" != "vscode" ] && \
        command -v tmux &>/dev/null; then
        exec tmux new-session -A -s main
      fi

      # Cursor sends Ctrl+Left/Ctrl+Right as escape sequences ending in D/C.
      # Bind them to zle word movement so Ctrl+Left/Ctrl+Right move by word.
      bindkey $'\e[1;3D' backward-word
      bindkey $'\e[1;3C' forward-word

      # compinit
      fpath+=~/.zfunc
      autoload -Uz compinit
      compinit -u

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
