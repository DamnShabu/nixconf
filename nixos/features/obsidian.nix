{
  flake.nixosModules.obsidian = {...}: {
    services.flatpak.packages = ["md.obsidian.Obsidian"];

    persistance.data.directories = [
      ".var/app/md.obsidian.Obsidian"
    ];
  };
}
