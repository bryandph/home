{globals, ...}: {
  programs = {
    git = {
      enable = true;
      lfs.enable = true;
      signing = {
        key = globals.gpg_thumbprint;
        signByDefault = true;
      };
      settings = {
        user = {
          inherit (globals) email;
          name = globals.fullname;
        };
        init.defaultBranch = "main";
        core = {
          untrackedCache = true;
          preloadIndex = true;
          fsmonitor = true;
        };
        feature.manyFiles = true;
        pack = {
          windowMemory = "2g";
          packSizeLimit = "1g";
          threads = 0;
        };
        maintenance = {
          auto = true;
          strategy = "incremental";
        };
        pull.rebase = true;
        push.autosetupremote = true;
        rebase.autostash = true;
        help.autocorrect = "prompt";
        merge.conflictstyle = "zdiff3";
        fetch.prune = true;
        diff = {
          algorithm = "histogram";
          submodule = "log";
        };
        submodule.recurse = "true";
        url = {
          "git@github.com:".insteadOf = ["gh:" "https://github.com/"];
          "git@git.bph:".insteadOf = "bph:";
        };
        status.submoduleSummary = true;
      };
    };
    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true;
        line-numbers = true;
        side-by-side = false;
        line-numbers-left-format = " {nm:>3} │";
        line-numbers-right-format = " {np:>3} │";
        line-numbers-minus-style = "red italic";
        line-numbers-plus-style = "green italic";
        line-numbers-zero-style = "brightblack italic";
        minus-emph-style = "syntax bold red";
        plus-emph-style = "syntax bold green";
        hunk-header-style = "blue bold";
        hunk-header-decoration-style = "blue box";
        file-style = "yellow bold";
        file-decoration-style = "yellow ul";
        blame-format = "{author:<18} {commit:<8} {timestamp:<15} │";
        merge-conflict-begin-symbol = "◆";
        merge-conflict-end-symbol = "◇";
        merge-conflict-ours-diff-header-style = "yellow bold";
        merge-conflict-theirs-diff-header-style = "magenta bold";
      };
    };
  };
}
