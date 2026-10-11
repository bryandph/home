# `ssh`/`scp` shims for herdr's PATH (programs.herdr.sshNoCompressionHosts).
# Herdr hard-codes `-C` on every ssh/scp call; servers with broken zlib
# support (OpenShell 0.1.2's sandbox SSH) drop the connection once
# compressible client data passes ~2 KB. For a destination matching one of
# `hosts` (shell globs on the host part of `[user@]host[:path]`) the shim
# removes `-C`; everything else passes through unchanged. Either way it then
# execs the next ssh/scp on PATH after its own directory.
{
  lib,
  pkgs,
  hosts,
}: let
  safe = lib.all (h: builtins.match "[A-Za-z0-9.*?_-]+" h != null) hosts;
  shim = pkgs.writeShellApplication {
    name = "herdr-ssh-shim";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      prog=$(basename "$0")
      here=$(cd "$(dirname "$0")" && pwd)
      rest=""
      IFS=:
      for dir in $PATH; do
        [ "$dir" = "$here" ] || rest="''${rest:+$rest:}$dir"
      done
      unset IFS
      PATH=$rest
      strip=0
      for arg in "$@"; do
        dest=''${arg#*@}
        dest=''${dest%%:*}
        case "$dest" in
          ${lib.concatStringsSep " | " hosts}) strip=1 ;;
        esac
      done
      if [ "$strip" = 1 ]; then
        for arg in "$@"; do
          shift
          [ "$arg" = -C ] || set -- "$@" "$arg"
        done
      fi
      exec "$prog" "$@"
    '';
  };
in
  assert lib.assertMsg (hosts != [] && safe) "herdr ssh shim: hosts must be non-empty globs of [A-Za-z0-9.*?_-]";
    pkgs.runCommand "herdr-ssh-shim" {} ''
      mkdir -p "$out/bin"
      ln -s ${lib.getExe shim} "$out/bin/ssh"
      ln -s ${lib.getExe shim} "$out/bin/scp"
    ''
