# Preset: the Linux desktop-environment bundle (Hyprland session + the GUI
# apps it composes). Imported on top of `shell` by the bryan-with-de profile.
{config, ...}: {
  flake.modules.homeManager.de = {
    imports = with config.flake.modules.homeManager; [
      chromium
      hyprland
      kitty
      wofi
    ];
  };
}
