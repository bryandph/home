{
  flake.modules.homeManager.nushell = {
    pkgs,
    lib,
    config,
    ...
  }: let
    user = config.home.username;
    isMac = pkgs.stdenv.isDarwin;
    homeDir = config.home.homeDirectory;

    # nix-darwin sets up the environment via POSIX shell scripts (/etc/static/bashrc, /etc/zshenv)
    # which nushell can't source. We reconstruct the nix-darwin environment here using
    # nix-time interpolation (config.home.username) instead of nushell runtime evaluation ($env.USER).
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
        LANG = "en_US.UTF-8";
        EDITOR = "hx";
        VAULT_ADDR = "https://vault.bph:8200";
        OPENAI_API_KEY = "ollama";
        OPENAI_API_BASE = "https://ollama.k8s.bph/v1";
        XMR_URL = "http://xmr.crypto.bph";
        XMRIG_PROXY_TOKEN = "hello";
      };

      extraEnv = lib.optionalString isMac darwinEnv;
      extraConfig = ''
        let carapace_completer = {|spans|
          carapace $spans.0 nushell ...$spans | from json
        }

        $env.config = {
          show_banner: false
          highlight_resolved_externals: true

          hooks: {
            pre_prompt: [{ ||
              if (which direnv | is-empty) { return }
              direnv export json | from json | default {} | load-env
              if 'ENV_CONVERSIONS' in $env and 'PATH' in $env.ENV_CONVERSIONS {
                $env.PATH = do $env.ENV_CONVERSIONS.PATH.from_string $env.PATH
              }
            }]
          }

          completions: {
            case_sensitive: false
            quick: true
            partial: true
            algorithm: "fuzzy"
            external: {
              enable: true
              max_results: 100
              completer: $carapace_completer
            }
          }

          cursor_shape: {
            emacs: line
            vi_insert: line
            vi_normal: block
          }

          table: {
            mode: rounded
            index_mode: auto
            show_empty: true
            padding: { left: 1, right: 1 }
            trim: {
              methodology: wrapping
              wrapping_try_keep_words: true
            }
          }

          explore: {
            status_bar_background: { fg: white, bg: dark_gray }
            command_bar_text: { fg: white }
            highlight: { fg: black, bg: yellow }
            selected_cell: { bg: blue, fg: white }
          }

          color_config: {
            separator: dark_gray
            leading_trailing_space_bg: { attr: n }
            header: { fg: green, attr: b }
            empty: blue
            bool: { fg: purple, attr: i }
            int: yellow
            float: yellow
            filesize: cyan
            duration: yellow
            date: { fg: purple, attr: i }
            range: yellow
            string: green
            nothing: dark_gray
            binary: purple
            cell-path: cyan
            row_index: { fg: dark_gray, attr: i }
            record: blue
            list: cyan
            block: blue
            hints: dark_gray
            search_result: { fg: black, bg: yellow }

            shape_binary: purple
            shape_block: blue
            shape_bool: { fg: purple, attr: i }
            shape_closure: { fg: cyan, attr: i }
            shape_custom: green
            shape_datetime: { fg: purple, attr: i }
            shape_directory: { fg: blue, attr: i }
            shape_external: cyan
            shape_externalarg: { fg: green, attr: i }
            shape_filepath: { fg: blue, attr: i }
            shape_flag: { fg: yellow, attr: i }
            shape_float: yellow
            shape_garbage: { fg: red, attr: biu }
            shape_glob_interpolation: { fg: cyan, attr: i }
            shape_globpattern: { fg: cyan, attr: i }
            shape_int: yellow
            shape_internalcall: { fg: blue, attr: b }
            shape_keyword: { fg: purple, attr: i }
            shape_list: cyan
            shape_literal: green
            shape_match_pattern: green
            shape_nothing: dark_gray
            shape_operator: { fg: yellow, attr: b }
            shape_or: { fg: purple, attr: b }
            shape_pipe: { fg: purple, attr: b }
            shape_range: yellow
            shape_raw_string: green
            shape_record: blue
            shape_redirection: { fg: purple, attr: i }
            shape_signature: { fg: green, attr: b }
            shape_string: green
            shape_string_interpolation: { fg: green, attr: i }
            shape_table: blue
            shape_variable: { fg: yellow, attr: i }
            shape_vardecl: { fg: yellow, attr: b }
          }

          menus: [
            {
              name: completion_menu
              only_buffer_difference: false
              marker: "◈ "
              type: {
                layout: columnar
                columns: 4
                col_padding: 2
              }
              style: {
                text: green
                selected_text: { fg: black, bg: green, attr: b }
                description_text: { fg: dark_gray, attr: i }
                match_text: { fg: yellow, attr: b }
                selected_match_text: { fg: black, bg: yellow, attr: b }
              }
            }
            {
              name: history_menu
              only_buffer_difference: true
              marker: "△ "
              type: {
                layout: list
                page_size: 10
              }
              style: {
                text: cyan
                selected_text: { fg: black, bg: cyan, attr: b }
                description_text: { fg: dark_gray, attr: i }
              }
            }
            {
              name: help_menu
              only_buffer_difference: true
              marker: "□ "
              type: {
                layout: description
                columns: 4
                col_padding: 2
                selection_rows: 4
                description_rows: 10
              }
              style: {
                text: blue
                selected_text: { fg: black, bg: blue, attr: b }
                description_text: { fg: dark_gray, attr: i }
              }
            }
          ]

          keybindings: [
            {
              name: completion_menu
              modifier: none
              keycode: tab
              mode: [emacs vi_normal vi_insert]
              event: {
                until: [
                  { send: menu, name: completion_menu }
                  { send: menunext }
                  { edit: complete }
                ]
              }
            }
            {
              name: history_menu
              modifier: control
              keycode: char_r
              mode: [emacs vi_normal vi_insert]
              event: { send: menu, name: history_menu }
            }
            {
              name: help_menu
              modifier: control
              keycode: char_q
              mode: [emacs vi_normal vi_insert]
              event: { send: menu, name: help_menu }
            }
            {
              name: next_page
              modifier: control
              keycode: char_x
              mode: emacs
              event: { send: menupagenext }
            }
            {
              name: undo_or_previous_page
              modifier: control
              keycode: char_z
              mode: emacs
              event: {
                until: [
                  { send: menupageprevious }
                  { edit: undo }
                ]
              }
            }
          ]
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
        # eza aliases — override ls for icons + color
        ls = "eza --icons --group-directories-first";
        ll = "eza -la --icons --group-directories-first --git";
        lt = "eza -T --icons --group-directories-first --level=2";
        la = "eza -a --icons --group-directories-first";
        lg = "lazygit";
        # override uname for zed
        uname = "^uname";
      };
    };
  };
}
