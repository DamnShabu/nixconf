{
  flake.nixosModules.zen = {...}: {
    services.flatpak.packages = ["app.zen_browser.zen"];

    persistance.data.directories = [
      ".var/app/app.zen_browser.zen/.zen"
    ];

    persistance.cache.directories = [
      ".var/app/app.zen_browser.zen/cache"
    ];
  };
}
