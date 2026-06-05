# Single source of the operator identity. Plain attrset (not a module):
# consumed by both the flake-level options (./options.nix) and the
# HM-level options (./_hm-module.nix). Underscore prefix keeps it out of
# import-tree's auto-import.
{
  name = "bryan";
  email = "bryan@pratherhuff.com";
  fullname = "Bryan Prather-Huff";
  gpgFingerprint = "6ADCBDDF44590F83";
}
