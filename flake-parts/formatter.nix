{
  perSystem = {pkgs, ...}: {
    # Use alejandra as the default formatter
    formatter = pkgs.alejandra;
  };
}
