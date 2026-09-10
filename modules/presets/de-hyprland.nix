{config, ...}: {
  flake.modules.homeManager.de-hyprland = {
    imports = with config.flake.modules.homeManager; [de-common de-keymap hyprland rofi waybar];
  };
}
