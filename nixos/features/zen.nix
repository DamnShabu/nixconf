{
  flake.nixosModules.zen = {...}: {
    services.flatpak.packages = ["app.zen_browser.zen"];

    persistence.data.directories = [
      ".var/app/app.zen_browser.zen/.zen"
    ];

    persistence.cache.directories = [
      ".var/app/app.zen_browser.zen/cache"
    ];
  };
}
