{
  flake.nixosModules.telegram = {...}: {
    services.flatpak.packages = ["org.telegram.desktop"];

    persistance.data.directories = [
      ".var/app/org.telegram.desktop"
    ];
  };
}
