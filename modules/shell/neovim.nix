{
  flake.modules.homeManager.neovim = _: {
    programs.neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      defaultEditor = false;
    };
  };
}
