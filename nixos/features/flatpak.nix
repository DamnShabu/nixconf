{
  flake.nixosModules.flatpak = {...}: {
    services.flatpak = {
      remotes = [{
        name = "flathub";
        location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      }];
    };

    persistence.directories = [
      "/var/lib/flatpak"
    ];
  };
}
