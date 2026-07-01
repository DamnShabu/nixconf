{ self, ... }: {
  flake.nixosModules.vicinae = { pkgs, config, ... }: {
    systemd.user.services.vicinae = {
      unitConfig = {
        Description = "Vicinae launcher daemon";
      };

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.vicinae}/bin/vicinae server";
        Restart = "on-failure";
        RestartSec = 3;
      };

      path = [pkgs.flatpak config.system.path];

      wantedBy = ["default.target"];
    };

    environment.systemPackages = [pkgs.vicinae];
  };
}
