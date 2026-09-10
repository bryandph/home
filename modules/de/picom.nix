# i3 does not composite X11 windows itself. GLava needs alpha compositing.
{
  flake.modules.homeManager.picom = {
    config,
    pkgs,
    ...
  }: {
    home.packages = [pkgs.picom];
    xdg.configFile."picom/picom.conf".text = ''
      backend = "glx";
      vsync = true;
      shadow = false;
      fading = false;
    '';
    xsession.windowManager.i3.config.startup = [
      {
        command = "${pkgs.picom}/bin/picom --config ${config.xdg.configFile."picom/picom.conf".source}";
        notification = false;
      }
    ];
  };
}
