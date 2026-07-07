{
  self,
  ...
}: {
  flake.nixosModules.impermanence = {config, ...}: {
    imports = [
      self.nixosModules.extra_impermanence
    ];

    persistence.enable = true;
    persistence.user = config.preferences.user.name;
  };
}
