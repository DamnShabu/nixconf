{
  flake.nixosModules.steam = {...}: {
    services.flatpak.packages = ["com.valvesoftware.Steam"];

    persistance.data.directories = [
      ".var/app/com.valvesoftware.Steam"
    ];
  };
}
