{pkgs, ...}: {
  home.packages = with pkgs; [
    nixos-anywhere
    nix-output-monitor
    nix-tree
    nixfmt
    nix-prefetch-github
    nixd
    treefmt
    nh
  ];
}
