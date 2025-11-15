{pkgs, ...}: {
  home.packages = with pkgs; [
    nixos-anywhere
    nix-output-monitor
    nix-tree
    nixfmt-rfc-style
    nix-prefetch-github
    nil
    treefmt
    nh
  ];
}
