# Check for the herdr ssh/scp shim (_herdr-ssh-shim.nix): `-C` is removed only
# for matching destinations, other arguments survive verbatim, and the shim
# hands off to the next ssh/scp on PATH rather than to itself.
{
  perSystem = {
    pkgs,
    lib,
    ...
  }: let
    shim = import ./_herdr-ssh-shim.nix {
      inherit lib pkgs;
      noCompressionHosts = ["openshell-*"];
      posixHosts = ["nuhost"];
    };
  in {
    checks.herdr-ssh-shim = pkgs.runCommand "herdr-ssh-shim-check" {} ''
      fake=$PWD/fake
      mkdir -p "$fake"
      for prog in ssh scp; do
        printf '#!%s\nprintf "%%s|" "$@"\n' ${pkgs.runtimeShell} > "$fake/$prog"
        chmod +x "$fake/$prog"
      done
      export PATH=${shim}/bin:$fake:$PATH
      expect() {
        got=$("$@")
        [ "$got" = "$want" ] || { echo "FAIL: $* -> $got (want $want)"; exit 1; }
      }
      want='-T|openshell-w1.default|/bin/sh -c '"'"'echo a b'"'"'|'
      expect ssh -C -T openshell-w1.default "/bin/sh -c 'echo a b'"
      want='-C|-T|workbox|true|'
      expect ssh -C -T workbox true
      want='-q|f|sandbox@openshell-w1.default:/tmp/f|'
      expect scp -C -q f sandbox@openshell-w1.default:/tmp/f
      want='-C|f|you@build:/tmp/f|'
      expect scp -C f you@build:/tmp/f
      # posixHosts: the command arrives as one /bin/sh-wrapped word that
      # decodes back to the original; options after the host stay options.
      got=$(ssh -C -T nuhost -n "printf '%s' a" "b c")
      cmd=''${got#-C|-T|nuhost|-n|}
      case "$cmd" in "/bin/sh -c 'eval \"\$(printf %s "*" | base64 -d)\"'|") ;; *) echo "FAIL posix: $got"; exit 1 ;; esac
      b64=''${cmd#"/bin/sh -c 'eval \"\$(printf %s "}; b64=''${b64%% *}
      [ "$(printf %s "$b64" | base64 -d)" = "printf '%s' a b c" ] || { echo "FAIL decode"; exit 1; }
      sh -c "eval \"\$(printf %s $b64 | base64 -d)\"" > decoded
      [ "$(cat decoded)" = "abc" ] || { echo "FAIL run: $(cat decoded)"; exit 1; }
      want='-C|-T|nuhost|'
      expect ssh -C -T nuhost
      touch "$out"
    '';
  };
}
