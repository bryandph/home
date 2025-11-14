{
  pkgs,
  globals,
  ...
}: let
  isMac = pkgs.stdenv.isDarwin; # Checks if the system is macOS (Darwin)
  # have to do some crazy shit to get env working on mac with nushell...
  macExtraConfig = ''
    $env.__NIX_DARWIN_SET_ENVIRONMENT_DONE = 1
    $env.PATH = [
      $"($env.HOME)/.nix-profile/bin"
      $"/etc/profiles/per-user/($env.USER)/bin"
      "/run/current-system/sw/bin"
      "/nix/var/nix/profiles/default/bin"
      "/usr/local/bin"
      "/usr/bin"
      "/usr/sbin"
      "/bin"
      "/sbin"
      "/opt/homebrew/bin/"
      "/opt/homebrew/sbin/"
    ]
    $env.NIX_PATH = [
      $"darwin-config=($env.HOME)/.nixpkgs/darwin-configuration.nix"
      "/nix/var/nix/profiles/per-user/root/channels"
    ]
    $env.NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt"
    $env.PAGER = "less -R"
    $env.TERMINFO_DIRS = [
      $"($env.HOME)/.nix-profile/share/terminfo"
      $"/etc/profiles/per-user/($env.USER)/share/terminfo"
      "/run/current-system/sw/share/terminfo"
      "/nix/var/nix/profiles/default/share/terminfo"
      "/usr/share/terminfo"
    ]
    $env.XDG_CONFIG_DIRS = [
      $"($env.HOME)/.nix-profile/etc/xdg"
      $"/etc/profiles/per-user/($env.USER)/etc/xdg"
      "/run/current-system/sw/etc/xdg"
      "/nix/var/nix/profiles/default/etc/xdg"
    ]
    $env.XDG_DATA_DIRS = [
      $"($env.HOME)/.nix-profile/share"
      $"/etc/profiles/per-user/($env.USER)/share"
      "/run/current-system/sw/share"
      "/nix/var/nix/profiles/default/share"
    ]
    $env.NIX_USER_PROFILE_DIR = $"/nix/var/nix/profiles/per-user/($env.USER)"
    $env.NIX_PROFILES = [
      "/nix/var/nix/profiles/default"
      "/run/current-system/sw"
      $"/etc/profiles/per-user/($env.USER)"
      $"($env.HOME)/.nix-profile"
    ]

    if ($"($env.HOME)/.nix-defexpr/channels" | path exists) {
      $env.NIX_PATH = ($env.PATH | split row (char esep) | append $"($env.HOME)/.nix-defexpr/channels")
    }

    if (false in (ls -l `/nix/var/nix` | where type == dir | where name == "/nix/var/nix/db" | get mode | str contains "w")) {
      $env.NIX_REMOTE = "daemon"
    }
    # Returns a record of changed env variables after running a non-nushell script's contents (passed via stdin), e.g. a bash script you want to "source"
    def capture-foreign-env [
        --shell (-s): string = /bin/sh
        # The shell to run the script in
        # (has to support '-c' argument and POSIX 'env', 'echo', 'eval' commands)
        --arguments (-a): list<string> = []
        # Additional command line arguments to pass to the foreign shell
    ] {
        let script_contents = $in;
        let env_out = with-env { SCRIPT_TO_SOURCE: $script_contents } {
            ^$shell ...$arguments -c `
            env
            echo '<ENV_CAPTURE_EVAL_FENCE>'
            eval "$SCRIPT_TO_SOURCE"
            echo '<ENV_CAPTURE_EVAL_FENCE>'
            env -u _ -u _AST_FEATURES -u SHLVL` # Filter out known changing variables
        }
        | split row '<ENV_CAPTURE_EVAL_FENCE>'
        | {
            before: ($in | first | str trim | lines)
            after: ($in | last | str trim | lines)
        }

        # Unfortunate Assumption:
        # No changed env var contains newlines (not cleanly parseable)
        $env_out.after
        | where { |line| $line not-in $env_out.before } # Only get changed lines
        | parse "{key}={value}"
        | transpose --header-row --as-record
        | if $in == [] { {} } else { $in }
    }
    load-env (open /etc/profiles/per-user/${globals.user}/etc/profile.d/hm-session-vars.sh | capture-foreign-env)
  '';
in {
  programs.nushell = {
    enable = true;
    extraEnv = ''
      ${
        if isMac
        then macExtraConfig
        else ""
      }
      $env.EDITOR = "hx"
      $env.VAULT_ADDR = "https://vault.core.bph:8200"
      $env.OPENAI_API_KEY = "ollama"
      $env.OPENAI_API_BASE = "https://ollama.k8s.bph/v1"
      $env.XMR_URL = "http://xmr.crypto.bph"
      $env.XMRIG_PROXY_TOKEN = "hello"
    '';
    extraConfig = ''
      $env.config = {
        hooks: {
          pre_prompt: [{ ||
            if (which direnv | is-empty) {
              return
            }

            direnv export json | from json | default {} | load-env
            if 'ENV_CONVERSIONS' in $env and 'PATH' in $env.ENV_CONVERSIONS {
              $env.PATH = do $env.ENV_CONVERSIONS.PATH.from_string $env.PATH
            }
          }]
        }
      }
      # Conditional inclusion based on platform
      let carapace_completer = {|spans|
      carapace $spans.0 nushell ...$spans | from json
      }
      $env.config = {
        show_banner: false,
        completions: {
        case_sensitive: false # case-sensitive completions
        quick: true    # set to false to prevent auto-selecting completions
        partial: true    # set to false to prevent partial filling of the prompt
        algorithm: "fuzzy"    # prefix or fuzzy
        external: {
        # set to false to prevent nushell looking into $env.PATH to find more suggestions
            enable: true
        # set to lower can improve completion performance at the cost of omitting some options
            max_results: 100
            completer: $carapace_completer # check 'carapace_completer'
          }
        }
      }
    '';
    shellAliases = {
      kubectl = "kubecolor";
      cat = "bat";
      vi = "hx";
      vim = "hx";
      nano = "hx";
      tf = "terraform";
      k = "kubecolor";
      ktx = "kubectx";
      htop = "btop";
      neofetch = "fastfetch";
      # override uname for zed
      # uname = "^uname";
    };
  };
}
