{
  flake.modules.homeManager.sesh = _: {
    programs.fzf.tmux.enableShellIntegration = true;

    programs.sesh = {
      enable = true;
      enableAlias = false;
      enableTmuxIntegration = true;
      tmuxKey = "s";
      icons = true;

      settings = {
        default_session = {
          startup_command = "hx .";
        };

        session = [
          {
            name = "nixspace";
            path = "~/BPH/profile/nixspace";
            windows = ["editor" "git"];
          }
          {
            name = "home";
            path = "~/BPH/profile/nixspace/home";
            windows = ["editor" "git"];
          }
        ];

        window = [
          {
            name = "editor";
            startup_script = "hx .";
          }
          {
            name = "git";
            startup_script = "lazygit";
          }
        ];
      };
    };
  };
}
