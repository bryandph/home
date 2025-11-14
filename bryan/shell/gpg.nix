{
  lib,
  pkgs,
  ...
}: {
  services.gpg-agent = lib.mkIf pkgs.stdenv.isLinux {
    enable = true;
    pinentry.package = pkgs.pinentry-qt;
    maxCacheTtl = 43200;
    enableNushellIntegration = true;
  };
}
