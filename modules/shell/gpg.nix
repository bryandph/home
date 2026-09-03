{
  flake.modules.homeManager.gpg = {
    lib,
    pkgs,
    ...
  }: {
    services.gpg-agent = lib.mkIf pkgs.stdenv.isLinux {
      enable = true;
      pinentry.package = pkgs.pinentry-qt;
      defaultCacheTtl = 21600;
      maxCacheTtl = 43200;
      enableNushellIntegration = true;
    };
  };
}
