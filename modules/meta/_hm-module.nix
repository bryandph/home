# Home Manager-level `meta.user.*` identity options, mirroring the option
# names of nixspace's flake-level `modules/meta.nix` (name, email, fullname,
# gpgFingerprint). Feature modules (git, nushell, ...) read these from the HM
# eval's own `config.meta.user.*` instead of the legacy `globals` specialArg,
# so consumers can override identity per-configuration with plain module
# definitions.
#
# Kept as a path-imported file (referenced by `flake.modules.homeManager.meta`
# AND by the lib compat shim) so the module system deduplicates it by path —
# importing it via two routes in one eval must not redeclare the options.
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
}
