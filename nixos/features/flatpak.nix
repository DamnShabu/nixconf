{
  flake.nixosModules.flatpak = {...}: {
    services.flatpak = {
      remotes = [{
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }];
    };

    persistance.directories = [
      "/var/lib/flatpak"
    ];
  };
}
