{self, ...}: {
  flake.nixosModules.yin = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      self.packages."${pkgs.stdenv.hostPlatform.system}".yin
    ];
  };
}
