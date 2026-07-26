{ pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    baseIndex = 1;
    escapeTime = 50;
    historyLimit = 10000;
    keyMode = "vi";
    mouse = true;
    prefix = "C-Space";
    terminal = "screen-256color";
    extraConfig = ''
      # =================================
      # ===       Key bindings        ===
      # =================================

      # Forward prefix
      bind C-Space send-prefix

      # Use Ctrl+Shift-arrow keys without prefix key to switch panes.
      # Left/Right: Karabiner remaps Ctrl->Option even with Shift held, so
      # Ctrl+Shift+Left/Right arrives as Option+Shift+Left/Right = \e[1;4D/C (modifier 4).
      # Up/Down: Karabiner doesn't remap these, so they arrive as Ctrl+Shift+Up/Down
      # = \e[1;6A/B (modifier 6). xterm-keys on lets tmux parse both.
      bind -n M-S-Left select-pane -L
      bind -n M-S-Right select-pane -R
      bind -n C-S-Up select-pane -U
      bind -n C-S-Down select-pane -D

      # Use Shift-arrow keys without prefix to switch windows
      bind -n S-Left previous-window
      bind -n S-Right next-window

      # Use Ctrl-Alt-arrow keys without prefix to switch sessions
      bind -n C-M-Left switch-client -p
      bind -n C-M-Right switch-client -n

      # Rename session and window
      unbind "\$"
      unbind ,
      bind R command-prompt -I "#{session_name}" "rename-session '%%'"
      bind r command-prompt -I "#{window_name}" "rename-window '%%'"

      # Start new panes at the current path
      bind '"' split-window -v -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"

      # Start new windows at home
      bind c new-window -c "$HOME"

      # Keep mouse drag-selection highlighted after release
      bind-key -T copy-mode MouseDragEnd1Pane send-keys -X copy-selection-no-clear
      bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-selection-no-clear

      # pane-base-index + renumber-windows (baseIndex is in the attr above; pane-base-index here)
      set-window-option -g pane-base-index 1
      set-option -g renumber-windows on

      # Set parent terminal title to reflect current window in tmux session
      set -g set-titles on
      set -g set-titles-string "#I:#W"

      # extended-keys (tmux 3.5+ csi-u format note: on 3.2a uses default xterm format)
      set -g extended-keys on

      # When destroying a session, attach to the next available session instead of detaching
      set -g detach-on-destroy off

      # Other options
      setw -g allow-rename off
      setw -g automatic-rename off
      setw -g aggressive-resize on
      set -g remain-on-exit off
      set -g status-position bottom

      # ==========================
      # ===       Theme        ===
      # ==========================

      # VSCode colors for tmux
      set -g window-active-style 'bg=black,fg=colour253'
      set -g window-style 'bg=black,fg=colour253'
      set -g pane-border-style 'bg=black, fg=colour59'
      set -g pane-active-border-style 'bg=black, fg=colour59'
      set -g status-style 'bg=colour32, fg=colour15'
      set -g window-status-style 'bg=default, fg=default'
      set -g window-status-current-style 'bg=colour39, fg=default'

      # Dracula theme options
      set -g @dracula-plugins "time"
      set -g @dracula-show-empty-plugins false
      set -g @dracula-refresh-rate 20
      set -g @dracula-day-month true
      set -g @dracula-gpu-ram-usage-colors "light_purple dark_gray"

      # ===============================================
      # ===   Nesting local and remote sessions     ===
      # ===============================================

      # Toggle key bindings on and off with F11 (e.g. when in nested/remote tmux)
      # And set a different status bar style/position to notify the user
      bind -T root F11 \
          set prefix None \;\
          set key-table off \;\
          set status-position top \;\
          set status-right "(F12) Bindings toggled off" \;\
          set status-style fg=colour9 \;\
          if -F '#{pane_in_mode}' 'send-keys -X cancel' \;\
          refresh-client -S

      bind -T off F11 \
        set -u prefix \;\
        set -u key-table \;\
        set -u status-position \;\
        set -u status-right \;\
        set -u status-style \;\
        refresh-client -S
    '';
    plugins = with pkgs.tmuxPlugins; [
      dracula
      sensible
    ];
  };
}
