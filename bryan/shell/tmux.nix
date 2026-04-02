{pkgs, ...}: {
  programs.tmux = {
    enable = true;
    prefix = "C-a";
    keyMode = "vi";
    mouse = true;
    terminal = "tmux-256color";
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 50000;
    clock24 = true;
    sensibleOnTop = true;
    disableConfirmationPrompt = true;

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      vim-tmux-navigator
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '10'
        '';
      }
    ];

    extraConfig = ''
      # ── True color & undercurl ──────────────────────────────────
      set -ag terminal-overrides ",xterm-256color:RGB"
      set -as terminal-overrides ',*:Smulx=\E[4::%p1%dm'
      set -as terminal-overrides ',*:Setulc=\E[58::2::%p1%{65536}%/%d::%p1%{256}%/%{255}%&%d::%p1%{255}%&%d%;m'

      # ── Window titles ───────────────────────────────────────────
      set-window-option -g automatic-rename on
      set-option -g set-titles on

      # ── Behavior ────────────────────────────────────────────────
      set -g renumber-windows on
      setw -g monitor-activity on
      set -g visual-activity off
      set -g focus-events on
      set -g set-clipboard on
      set -g detach-on-destroy off

      # ── Vi copy mode ────────────────────────────────────────────
      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi C-v send-keys -X rectangle-toggle
      bind -T copy-mode-vi y send-keys -X copy-selection-and-cancel

      # ── Splits (vim-style v/s) ──────────────────────────────────
      bind-key v split-window -h -c "#{pane_current_path}"
      bind-key s split-window -v -c "#{pane_current_path}"
      bind c new-window -c "#{pane_current_path}"

      # ── Pane resizing ───────────────────────────────────────────
      bind-key J resize-pane -D 5
      bind-key K resize-pane -U 5
      bind-key H resize-pane -L 5
      bind-key L resize-pane -R 5

      bind-key M-j resize-pane -D
      bind-key M-k resize-pane -U
      bind-key M-h resize-pane -L
      bind-key M-l resize-pane -R

      # ── Pane selection (prefix + vim keys) ──────────────────────
      bind h select-pane -L
      bind j select-pane -D
      bind k select-pane -U
      bind l select-pane -R

      # ── No-prefix pane switching (Alt+vim / Alt+arrows) ─────────
      bind -n M-h select-pane -L
      bind -n M-j select-pane -D
      bind -n M-k select-pane -U
      bind -n M-l select-pane -R

      bind -n M-Left select-pane -L
      bind -n M-Right select-pane -R
      bind -n M-Up select-pane -U
      bind -n M-Down select-pane -D

      # ── No-prefix window switching (Shift+arrows) ──────────────
      bind -n S-Left previous-window
      bind -n S-Right next-window

      # ── Window swapping ─────────────────────────────────────────
      bind -r "<" swap-window -d -t -1
      bind -r ">" swap-window -d -t +1

      # ── Quick actions ───────────────────────────────────────────
      bind r source-file ~/.config/tmux/tmux.conf \; display "◎ reloaded"
      bind f display-popup -E -w 80% -h 80% "tmux list-sessions | fzf --reverse | cut -d: -f1 | xargs tmux switch-client -t"
      bind g display-popup -E -w 90% -h 90% -d "#{pane_current_path}" lazygit
      bind b display-popup -E -w 90% -h 90% -d "#{pane_current_path}" btop

      # ── Status bar ── geometric aesthetic ───────────────────────
      set -g status-position top
      set -g status-interval 2
      set -g status-justify centre

      set -g status-style "bg=black,fg=white"

      # Pane borders
      set -g pane-border-style "fg=brightblack"
      set -g pane-active-border-style "fg=blue,bold"
      set -g pane-border-indicators arrows
      set -g pane-border-lines heavy

      # Messages
      set -g message-style "bg=black,fg=yellow,bold,italics"
      set -g message-command-style "bg=black,fg=magenta,bold"

      # Popup
      set -g popup-border-style "fg=blue"
      set -g popup-border-lines rounded

      # Mode (copy mode highlight)
      set -g mode-style "bg=blue,fg=black,bold"

      # ── Status left: session + user ─────────────────────────────
      set -g status-left-length 50
      set -g status-left "#[fg=green,bold,italics] ◎ #S #[fg=brightblack,nobold]│ #[fg=green]#(whoami)"

      # ── Status right: load + time ───────────────────────────────
      set -g status-right-length 80
      set -g status-right "#[fg=brightblack]│ #[fg=cyan,italics]#{?pane_in_mode,◇ COPY ,}#[fg=yellow]#(cut -d ' ' -f 1-3 /proc/loadavg) #[fg=brightblack]│#[fg=white,bold] %H:%M "

      # ── Window tabs ─────────────────────────────────────────────
      set -g window-status-format "#[fg=brightblack,italics]  #I·#W "
      set -g window-status-current-format "#[fg=white,bg=black,bold]  #I·#W #[fg=yellow]◆"
      set -g window-status-separator ""
      set -g window-status-activity-style "fg=magenta,italics"
      set -g window-status-bell-style "fg=red,bold"
    '';
  };
}
