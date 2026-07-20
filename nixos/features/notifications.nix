{self, ...}: {
  flake.nixosModules.notifications = {pkgs, config, ...}: {
    environment.systemPackages = with pkgs; [
      quickshell
      swayosd
      libnotify
    ];

    persistence.data.directories = [
      ".cache/quickshell"
    ];
  };
}
