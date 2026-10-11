# `ssh`/`scp` shims for herdr's PATH (programs.herdr.ssh*Hosts). The shim
# finds the destination (`[user@]host[:path]`, matched as shell globs) and:
#
# * noCompressionHosts: removes the `-C` herdr hard-codes. OpenShell 0.1.2's
#   sandbox SSH server drops the connection once compressible client data
#   passes ~2 KB.
# * posixHosts (ssh only): runs the remote command under /bin/sh. herdr sends
#   some commands (the machine API bridge) unwrapped, assuming a POSIX login
#   shell; a nushell login shell rejects them. The command travels base64
#   encoded inside `/bin/sh -c 'eval "$(printf %s B64 | base64 -d)"'`, which
#   nushell and POSIX shells parse identically, and stdin is left alone.
#
# Everything else passes through unchanged; the shim then execs the next
# ssh/scp on PATH after its own directory.
{
  lib,
  pkgs,
  noCompressionHosts ? [],
  posixHosts ? [],
}: let
  safe = lib.all (h: builtins.match "[A-Za-z0-9.*?_-]+" h != null) (noCompressionHosts ++ posixHosts);
  globs = hosts:
    if hosts == []
    then "''"
    else lib.concatStringsSep " | " hosts;
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

      # Locate the destination: the first operand, skipping options and
      # the values of OpenSSH's value-taking flags.
      dest_index=0 i=0 skip=0
      for arg in "$@"; do
        i=$((i + 1))
        if [ "$skip" = 1 ]; then skip=0; continue; fi
        case "$arg" in
          -[BbcDEeFIiJLlmOoPpQRSWw]) skip=1 ;;
          -*) ;;
          *) dest_index=$i; break ;;
        esac
      done
      dest=""
      if [ "$dest_index" -gt 0 ]; then
        dest=''${!dest_index}
        dest=''${dest#*@}
        dest=''${dest%%:*}
      fi
      # scp names hosts in its file operands rather than a destination.
      if [ "$prog" = scp ]; then
        for arg in "$@"; do
          case "$arg" in *:*) dest=''${arg#*@}; dest=''${dest%%:*} ;; esac
        done
      fi

      strip=0 posix=0
      case "$dest" in ${globs noCompressionHosts}) strip=1 ;; esac
      [ "$prog" = ssh ] && case "$dest" in ${globs posixHosts}) posix=1 ;; esac

      if [ "$posix" = 1 ]; then
        # Options may follow the destination; the command is what remains.
        head=("''${@:1:dest_index}") tail=("''${@:dest_index+1}") opts=()
        while [ "''${#tail[@]}" -gt 0 ]; do
          case "''${tail[0]}" in
            -[BbcDEeFIiJLlmOoPpQRSWw]) opts+=("''${tail[@]:0:2}"); tail=("''${tail[@]:2}") ;;
            -*) opts+=("''${tail[0]}"); tail=("''${tail[@]:1}") ;;
            *) break ;;
          esac
        done
        if [ "''${#tail[@]}" -gt 0 ]; then
          # ssh joins command words with spaces before the remote shell sees them.
          b64=$(printf '%s' "''${tail[*]}" | base64 | tr -d '\n')
          set -- "''${head[@]}" "''${opts[@]}" "/bin/sh -c 'eval \"\$(printf %s $b64 | base64 -d)\"'"
        fi
      fi

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
  assert lib.assertMsg (noCompressionHosts ++ posixHosts != [] && safe) "herdr ssh shim: hosts must be non-empty globs of [A-Za-z0-9.*?_-]";
    pkgs.runCommand "herdr-ssh-shim" {} ''
      mkdir -p "$out/bin"
      ln -s ${lib.getExe shim} "$out/bin/ssh"
      ln -s ${lib.getExe shim} "$out/bin/scp"
    ''
