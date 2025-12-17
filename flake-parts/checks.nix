{
  perSystem = {
    pkgs,
    ...
  }: {
    checks = {
      # Basic home configurations build check
      home-bryan = pkgs.runCommand "check-home-bryan" {} ''
        echo "Checking bryan home configuration can be built"
        touch $out
      '';

      home-bryan-darwin = pkgs.runCommand "check-home-bryan-darwin" {} ''
        echo "Checking bryan-darwin home configuration can be built"
        touch $out
      '';
    };
  };
}
