{
  flake.modules.homeManager.helix = _: {
    programs.helix = {
      enable = true;

      settings = {
        editor = {
          line-number = "relative";
          cursorline = true;
          color-modes = true;
          true-color = true;
          undercurl = true;
          rulers = [100];
          idle-timeout = 0;
          completion-trigger-len = 1;
          bufferline = "multiple";
          popup-border = "all";
          auto-save = {
            focus-lost = true;
            after-delay.enable = false;
          };

          cursor-shape = {
            insert = "bar";
            normal = "block";
            select = "underline";
          };

          file-picker = {
            hidden = false;
            git-ignore = true;
          };

          indent-guides = {
            render = true;
            character = "▏";
            skip-levels = 1;
          };

          gutters = {
            layout = ["diagnostics" "spacer" "line-numbers" "spacer" "diff"];
            line-numbers.min-width = 1;
          };

          lsp = {
            display-messages = true;
            display-inlay-hints = true;
          };

          statusline = {
            left = ["mode" "spinner" "spacer" "version-control" "spacer" "diagnostics"];
            center = ["file-name" "file-modification-indicator" "read-only-indicator"];
            right = ["selections" "register" "position" "file-encoding" "file-line-ending" "file-type"];
            separator = "│";
            mode = {
              normal = "◎ NOR";
              insert = "◈ INS";
              select = "◇ SEL";
            };
          };

          soft-wrap = {
            enable = true;
            wrap-indicator = "↩ ";
          };

          whitespace = {
            render = {
              tab = "all";
              nbsp = "all";
              nnbsp = "all";
            };
            characters = {
              tab = "→";
              nbsp = "⍽";
              nnbsp = "⋅";
              tabpad = "·";
            };
          };
        };

        keys = {
          normal = {
            "C-s" = ":w";
            "S-tab" = "goto_previous_buffer";
            "tab" = "goto_next_buffer";
            "C-w" = ":bc";
            "C-h" = "jump_view_left";
            "C-l" = "jump_view_right";
            "C-j" = "jump_view_down";
            "C-k" = "jump_view_up";
            "esc" = ["collapse_selection" "keep_primary_selection"];
            space = {
              w = ":w";
              q = ":q";
              x = ":wq";
              f = "file_picker";
              b = "buffer_picker";
              "/" = "global_search";
            };
            # Window management under C-w prefix
            "A-h" = "jump_view_left";
            "A-l" = "jump_view_right";
            "A-j" = "jump_view_down";
            "A-k" = "jump_view_up";
          };
          insert = {
            "C-s" = ":w";
            "C-space" = "completion";
          };
          select = {
            "tab" = "extend_to_line_bounds";
          };
        };
      };

      languages = {
        language-server = {
          nixd = {
            command = "nixd";
          };
          yaml-language-server = {
            command = "yaml-language-server";
            args = ["--stdio"];
          };
          vscode-json-language-server = {
            command = "vscode-json-language-server";
            args = ["--stdio"];
          };
          bash-language-server = {
            command = "bash-language-server";
            args = ["start"];
          };
          rust-analyzer = {
            command = "rust-analyzer";
            config.check.command = "clippy";
          };
          ruff = {
            command = "ruff";
            args = ["server"];
          };
        };

        language = [
          {
            name = "nix";
            auto-format = true;
            formatter.command = "alejandra";
            language-servers = ["nixd"];
          }
          {
            name = "rust";
            auto-format = true;
            language-servers = ["rust-analyzer"];
          }
          {
            name = "python";
            auto-format = true;
            language-servers = ["ruff"];
            formatter = {
              command = "ruff";
              args = ["format" "-"];
            };
          }
          {
            name = "yaml";
            auto-format = true;
            language-servers = ["yaml-language-server"];
          }
          {
            name = "json";
            language-servers = ["vscode-json-language-server"];
          }
          {
            name = "toml";
            auto-format = true;
          }
          {
            name = "bash";
            language-servers = ["bash-language-server"];
          }
          {
            name = "markdown";
            soft-wrap.enable = true;
          }
        ];
      };
    };
  };
}
