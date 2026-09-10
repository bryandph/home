{
  flake.modules.homeManager.i3-idle = {
    config,
    pkgs,
    ...
  }: {
    services.screen-locker = {
      enable = true;
      lockCmd = config.de.keymap.commands.lock;
      inactiveInterval = 15;
      xautolock.enable = false;
      xss-lock.extraOptions = ["--transfer-sleep-lock"];
    };
    xsession.initExtra = "${pkgs.xset}/bin/xset dpms 0 0 1200";
  };
}
