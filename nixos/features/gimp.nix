{
  flake.nixosModules.gimp = {...}: {
    services.flatpak.packages = ["org.gimp.GIMP"];

    persistence.data.directories = [
      ".var/app/org.gimp.GIMP"
    ];
  };
}
