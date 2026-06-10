# Flake-level identity options (`config.meta.user.*`) — consumed by the apps
# and the lib compat shims — plus the HM-class `meta` feature that declares the
# same options inside Home Manager evaluations (see ./_hm-module.nix).
#
# Defaults come from the mandala-bph fleet contract (single authored operator
# identity); nothing identity-shaped is hand-authored in this repo. The HM
# feature wraps the path-imported option module and injects the same defaults
# with mkDefault, so HM evals that never set meta.user (e.g. the nixspace
# parent's home-manager.sharedModules route) keep resolving.
{
  lib,
  inputs,
  ...
}: let
  operator = inputs.mandala-bph.data.operator;
  inherit (lib) mkOption types;
in {
  options.meta.user = {
    name = mkOption {
      type = types.str;
      default = operator.name;
      description = "Primary user account name.";
    };
    email = mkOption {
      type = types.str;
      default = operator.email;
      description = "Primary user email.";
    };
    fullname = mkOption {
      type = types.str;
      default = operator.fullname;
      description = "Display name.";
    };
    gpgFingerprint = mkOption {
      type = types.str;
      default = operator.gpg.fingerprint;
      description = "Full GPG primary key fingerprint (uppercase hex, no spaces).";
    };
  };

  config.flake.modules.homeManager.meta = {
    imports = [./_hm-module.nix];
    config.meta.user = {
      name = lib.mkDefault operator.name;
      email = lib.mkDefault operator.email;
      fullname = lib.mkDefault operator.fullname;
      gpgFingerprint = lib.mkDefault operator.gpg.fingerprint;
    };
  };
}
