{globals, ...}: {
  programs = {
    git = {
      enable = true;
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
          "git@github.com:".insteadOf = "https://github.com/";
        };
        status.submoduleSummary = true;
      };
    };
    delta = {
      enable = true;
      enableGitIntegration = true;
    };
  };
}
