{
  pkgs,
  lib,
  globals,
  ...
}: let
  inherit (globals) user;
  isMac = pkgs.stdenv.isDarwin;
  homeDir = "/Users/${globals.user}";

  # nix-darwin sets up the environment via POSIX shell scripts (/etc/static/bashrc, /etc/zshenv)
  # which nushell can't source. We reconstruct the nix-darwin environment here using
  # nix-time interpolation (globals.user) instead of nushell runtime evaluation ($env.USER).
  darwinEnv = ''
    $env.__NIX_DARWIN_SET_ENVIRONMENT_DONE = 1
    $env.PATH = [
      "${homeDir}/.nix-profile/bin"
      "/etc/profiles/per-user/${user}/bin"
      "/run/current-system/sw/bin"
      "/nix/var/nix/profiles/default/bin"
      "/usr/local/bin"
      "/usr/bin"
      "/usr/sbin"
      "/bin"
      "/sbin"
      "/opt/homebrew/bin"
      "/opt/homebrew/sbin"
    ]
    $env.NIX_PATH = [
      "darwin-config=${homeDir}/.nixpkgs/darwin-configuration.nix"
      "/nix/var/nix/profiles/per-user/root/channels"
    ]
    $env.NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt"
    $env.PAGER = "less -R"
    $env.TERMINFO_DIRS = [
      "${homeDir}/.nix-profile/share/terminfo"
      "/etc/profiles/per-user/${user}/share/terminfo"
      "/run/current-system/sw/share/terminfo"
      "/nix/var/nix/profiles/default/share/terminfo"
      "/usr/share/terminfo"
    ]
    $env.XDG_CONFIG_DIRS = [
      "${homeDir}/.nix-profile/etc/xdg"
      "/etc/profiles/per-user/${user}/etc/xdg"
      "/run/current-system/sw/etc/xdg"
      "/nix/var/nix/profiles/default/etc/xdg"
    ]
    $env.XDG_DATA_DIRS = [
      "${homeDir}/.nix-profile/share"
      "/etc/profiles/per-user/${user}/share"
      "/run/current-system/sw/share"
      "/nix/var/nix/profiles/default/share"
    ]
    $env.NIX_USER_PROFILE_DIR = "/nix/var/nix/profiles/per-user/${user}"
    $env.NIX_PROFILES = [
      "/nix/var/nix/profiles/default"
      "/run/current-system/sw"
      "/etc/profiles/per-user/${user}"
      "${homeDir}/.nix-profile"
    ]

    if ("${homeDir}/.nix-defexpr/channels" | path exists) {
      $env.NIX_PATH = ($env.NIX_PATH | append "${homeDir}/.nix-defexpr/channels")
    }

    if (false in (ls -l /nix/var/nix | where type == dir | where name == "/nix/var/nix/db" | get mode | str contains "w")) {
      $env.NIX_REMOTE = "daemon"
    }
  '';
in {
  programs.nushell = {
    enable = true;

    environmentVariables = {
      EDITOR = "hx";
      VAULT_ADDR = "https://vault.core.bph:8200";
      OPENAI_API_KEY = "ollama";
      OPENAI_API_BASE = "https://ollama.k8s.bph/v1";
      XMR_URL = "http://xmr.crypto.bph";
      XMRIG_PROXY_TOKEN = "hello";
    };

    extraEnv = lib.optionalString isMac darwinEnv;
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
      uname = "^uname";
    };
  };
}
