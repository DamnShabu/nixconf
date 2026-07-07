{self, ...}: {
  flake.nixosModules.testme = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [hello];
  };
}
