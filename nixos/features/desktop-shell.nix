{self, ...}: {
  flake.nixosModules.desktopShell = {pkgs, config, ...}: {
    persistence.data.directories = [
      "Desktop"
    ];
  };
}
