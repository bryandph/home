# Flake-level identity options (`config.meta.user.*`) — consumed by the apps
# and the lib compat shims — plus the HM-class `meta` feature that declares the
# same options inside Home Manager evaluations (see ./_hm-module.nix).
{lib, ...}: let
  defaults = import ./_defaults.nix;
  inherit (lib) mkOption types;
in {
  options.meta.user = {
    name = mkOption {
      type = types.str;
      default = defaults.name;
      description = "Primary user account name.";
    };
    email = mkOption {
      type = types.str;
      default = defaults.email;
      description = "Primary user email.";
    };
    fullname = mkOption {
      type = types.str;
      default = defaults.fullname;
      description = "Display name.";
    };
    gpgFingerprint = mkOption {
      type = types.str;
      default = defaults.gpgFingerprint;
      description = "GPG primary key fingerprint (uppercase hex, no spaces).";
    };
  };

  config.flake.modules.homeManager.meta = ./_hm-module.nix;
}
