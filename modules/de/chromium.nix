{
  flake.modules.homeManager.chromium = _: {
    programs.chromium = {
      enable = true;
      extensions = [];
    };
  };
}
