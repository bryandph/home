# Reusable session without workstation identity, browser or idle policy.
{config, ...}: {
  flake.modules.homeManager.desktop-i3 = {
    imports = with config.flake.modules.homeManager; [de-keymap kitty i3 rofi polybar picom];
  };
}
