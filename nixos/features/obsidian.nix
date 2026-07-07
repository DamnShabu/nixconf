{
  flake.nixosModules.obsidian = {...}: {
    services.flatpak.packages = ["md.obsidian.Obsidian"];

    persistence.data.directories = [
      ".var/app/md.obsidian.Obsidian"
    ];
  };
}
