{ pkgs, ... }:
{
  imports = [
    ./git.nix
    ./gpg.nix
    ./helix.nix
    ./k9s.nix
    ./nix.nix
    ./nushell.nix
    ./starship.nix
    ./sesh.nix
    ./tmux.nix
    ./workmux.nix
  ];
  config = {
    programs = {
      uv.enable = true;
      btop.enable = true;
      direnv = {
        enable = true;
        nix-direnv.enable = true;
        enableNushellIntegration = true;
        silent = true;
      };
      carapace = {
        enable = true;
        enableNushellIntegration = true;
      };
      gpg.enable = true;
      # zellij removed — using tmux as primary multiplexer
      jq.enable = true;
      kubecolor.enable = true;
      zed-editor = {
        enable = true;
        installRemoteServer = true;
      };
      zoxide = {
        enable = true;
        enableNushellIntegration = true;
      };
      yazi = {
        enable = true;
        enableNushellIntegration = true;
      };
    };

    home = {
      packages = with pkgs; [
        # Development Tools
        just
        bacon
        evcxr
        nix
        nodejs

        # Kubernetes Tools
        kubectl
        kubectx
        (wrapHelm kubernetes-helm { plugins = [ kubernetes-helmPlugins.helm-diff ]; }) # helm-diff backs the k9s helm-diff plugins
        kubeconform
        kustomize
        kompose
        stern # multi-pod log tailing — k9s Ctrl-Y plugin

        # Cloud Tools
        # awscli
        # google-cloud-sdk
        # azure-cli
        # opentofu

        # Security & Secret Management
        vault
        bws
        sops
        age
        gpsd

        # System Utilities
        bat
        eza
        uutils-coreutils-noprefix
        # uutils-findutils
        uutils-diffutils
        ripgrep
        ripgrep-all
        direnv
        nix-direnv
        rustscan
        lazygit
        unixtools.arp
        tree
        pv # Pipe viewer — progress for dd/zstd pipes

        # Container Tools
        dive
        podman-tui
        docker-compose
        skopeo

        # Other Tools
        usbutils
        yq
        sshpass
        step-cli
        minio-client
        yamlfmt
        mprocs
        wiki-tui
        speedtest-rs
        dust # Disk usage analyzer
        aspell # Spell checker
        age-plugin-yubikey # YubiKey plugin for age encryption
        act # Run Github actions locally
        aspellDicts.en # English dictionary for aspell
        glow # Markdown renderer for terminal
        fzf # Fuzzy finder
        libfido2 # FIDO2 library
        fastfetch # neofetch replacement
        hexyl
        nix-search-cli

        # TUIs
        systemctl-tui # systemd units + per-unit logs
        lazyjournal # journald/container log browser
        trippy # mtr-style traceroute/ping
        bandwhich # per-process/per-connection bandwidth
        sshs # ssh-config host picker
        jqp # interactive jq playground
        dua # interactive disk usage (dua i)
        atac # postman-like API client

        # Security Tools
        nmap
        rustscan
        git-filter-repo
      ];
    };
  };
}
