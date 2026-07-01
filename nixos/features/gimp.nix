{
  flake.nixosModules.gimp = {...}: {
    services.flatpak.packages = ["org.gimp.GIMP"];

    persistance.data.directories = [
      ".var/app/org.gimp.GIMP"
    ];
  };
}
