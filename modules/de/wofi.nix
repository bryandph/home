{
  flake.modules.homeManager.wofi = _: {
    programs.wofi = {
      enable = true;
      settings = {};
    };
  };
}
