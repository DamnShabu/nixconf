{
  flake.nixosModules.steam = {...}: {
    services.flatpak.packages = ["com.valvesoftware.Steam"];

    hardware.steam-hardware.enable = true;

    persistence.data.directories = [
      ".var/app/com.valvesoftware.Steam"
    ];
  };
}
