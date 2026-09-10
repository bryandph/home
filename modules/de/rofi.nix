{
  flake.modules.homeManager.rofi = {
    config,
    lib,
    ...
  }: {
    de.keymap.commands.launcher = lib.mkDefault "${config.programs.rofi.package}/bin/rofi -config ${config.home.file.${config.programs.rofi.configPath}.source} -show drun";
    de.keymap.commands.switcher = lib.mkOptionDefault "${config.programs.rofi.package}/bin/rofi -config ${config.home.file.${config.programs.rofi.configPath}.source} -show window";
    programs.rofi = {
      enable = true;
      # The pinned rofi supports both X11 and Wayland.
      extraConfig = {
        modi = "drun,run,window";
        show-icons = true;
        display-drun = "Applications";
      };
    };
  };
}
