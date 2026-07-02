{
  flake.nixosModules.steam = {...}: {
    services.flatpak.packages = ["com.valvesoftware.Steam"];

    hardware.steam-hardware.enable = true;

    persistance.data.directories = [
      ".var/app/com.valvesoftware.Steam"
    ];
  };
}
