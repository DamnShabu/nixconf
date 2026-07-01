{
  flake.nixosModules.discord = {...}: {
    services.flatpak.packages = ["dev.vencord.Vesktop"];

    persistance.data.directories = [
      ".var/app/dev.vencord.Vesktop"
    ];
  };
}
