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
#
# Declarations only — no defaults. Values arrive from the mandala-bph fleet
# contract via the `meta` feature wrapper (./options.nix), from the factory
# injection (infrastructure/home-manager.nix), or from the globals shim
# (infrastructure/exports.nix).
{lib, ...}: let
  inherit (lib) mkOption types;
in {
  options.meta.user = {
    name = mkOption {
      type = types.str;
      description = "Primary user account name.";
    };
    email = mkOption {
      type = types.str;
      description = "Primary user email.";
    };
    fullname = mkOption {
      type = types.str;
      description = "Display name.";
    };
    gpgFingerprint = mkOption {
      type = types.str;
      description = "Full GPG primary key fingerprint (uppercase hex, no spaces).";
    };
  };
}
