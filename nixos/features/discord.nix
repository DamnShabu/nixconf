{
  flake.nixosModules.discord = {...}: {
    services.flatpak.packages = ["dev.vencord.Vesktop"];

    persistence.data.directories = [
      ".var/app/dev.vencord.Vesktop"
    ];
  };
}
