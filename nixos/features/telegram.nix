{
  flake.nixosModules.telegram = {...}: {
    services.flatpak.packages = ["org.telegram.desktop"];

    persistence.data.directories = [
      ".var/app/org.telegram.desktop"
    ];
  };
}
