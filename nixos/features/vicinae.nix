{ self, ... }: {
  flake.nixosModules.vicinae = { pkgs, config, ... }: {
    environment.systemPackages = [pkgs.vicinae];
  };
}
