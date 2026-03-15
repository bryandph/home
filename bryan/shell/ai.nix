{ pkgs, ... }:
{
  programs = {
    # Shared MCP servers — used by OpenCode via enableMcpIntegration.
    # Only non-secret servers here (no API tokens).
    # Secret-requiring servers (github, gitea) go in host-level managed configs.
    mcp = {
      enable = true;
      servers = {
        context7 = {
          url = "https://mcp.context7.com/mcp";
        };
        nixos = {
          command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
        };
        serena = {
          command = "nix";
          args = [
            "run"
            "github:oraios/serena"
            "--"
            "start-mcp-server"
            "--context"
            "claude-code"
            "--project"
            "$(pwd)"
          ];
        };
      };
    };

    # Claude Code — no wrapper, no mcpServers, no enableMcpIntegration.
    # MCP servers come from /etc/claude-code/managed-mcp.json (NixOS level).
    claude-code = {
      enable = true;
      settings = {
        enabledPlugins = {
          "rust-analyzer-lsp@claude-plugins-official" = true;
          "clangd-lsp@claude-plugins-official" = false;
          "pyright-lsp@claude-plugins-official" = false;
          "commit-commands@claude-plugins-official" = true;
          "typescript-lsp@claude-plugins-official" = true;
          "stripe@claude-plugins-official" = false;
          "frontend-design@claude-plugins-official" = true;
          "explanatory-output-style@claude-plugins-official" = true;
          "feature-dev@claude-plugins-official" = true;
        };
        attribution = { };
      };
    };

    # Gemini CLI
    gemini-cli = {
      enable = true;
    };

    # OpenCode — pulls MCP servers from programs.mcp.servers via config file (no wrapper)
    opencode = {
      enable = true;
      enableMcpIntegration = true;
      settings = {
        model = "anthropic/claude-opus-4-6";
        small_model = "anthropic/claude-sonnet-4-6";
        provider = {
          ollama-blackwin = {
            npm = "@ai-sdk/openai-compatible";
            name = "Ollama-Blackwin";
            options = {
              baseURL = "http://blackwin:11434/v1";
            };
            models = {
              "hf.co/DreamFast/gemma-3-12b-it-heretic-v2" = {
                name = "Gemma 3 12B Heretic v2";
              };
            };
          };
        };
      };
    };
  };
}
