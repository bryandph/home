_: {
  programs = {
    # Global MCP servers — shared across MCP-aware tools (claude-code, opencode, etc.)
    mcp = {
      enable = true;
      servers = {
        context7 = {
          type = "http";
          url = "https://mcp.context7.com/mcp";
          headers.CONTEXT7_API_KEY = "{env:CONTEXT7_API_KEY}";
        };
        serena = {
          type = "stdio";
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
        github = {
          type = "http";
          url = "https://api.githubcopilot.com/mcp";
          headers.Authorization = "Bearer {env:GITHUB_PERSONAL_ACCESS_TOKEN}";
        };
        nixos = {
          type = "stdio";
          command = "nix";
          args = ["run" "github:utensils/mcp-nixos" "--"];
        };
      };
    };

    # Claude Code
    claude-code = {
      enable = true;
      enableMcpIntegration = true;
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
        attribution = {};
      };
    };

    # Gemini CLI
    gemini-cli = {
      enable = true;
    };

    # OpenCode
    opencode = {
      enable = true;
      enableMcpIntegration = true;
      settings = {
        model = "anthropic/claude-opus-4-6";
        small_model = "anthropic/claude-sonnet-4-6";
      };
    };
  };
}
