{pkgs, ...}: {
  imports = [
    ./git.nix
    ./gpg.nix
    ./nix.nix
    ./nushell.nix
    ./starship.nix
    ./gptcommit.nix
  ];
  config = {
    programs = {
      helix.enable = true;
      uv.enable = true;
      earthly.enable = true;
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
      mise = {
        enable = true;
        enableNushellIntegration = true;
      };
      gpg.enable = true;
      zellij.enable = true;
      jq.enable = true;
      k9s.enable = true;
      kubecolor.enable = true;
      zed-editor = {
        enable = true;
        installRemoteServer = true;
      };
      zoxide = {
        enable = true;
        enableNushellIntegration = true;
      };
    };

    home = {
      packages = with pkgs; [
        # Development Tools
        helix
        just
        bacon
        evcxr
        nix
        nodejs
        claude-code
        gemini-cli

        # Kubernetes Tools
        kubectl
        kubectx
        kubernetes-helm
        kubeconform
        kustomize
        kompose

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
        gptcommit
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
        xmr-monitor
        hexyl
      ];
    };
  };
}
