{ self, ... }: {
  flake.nixosModules.searxng = { pkgs, config, ... }: let
    settingsYml = pkgs.writeText "searxng-settings.yml" ''
      use_default_settings: true

      server:
        secret_key: "wYonYcIAM9eI4iYtIA01a0XU3x2VNb"
        image_proxy: true

      search:
        formats:
          - html
          - json
    '';
  in {
    persistance.data.directories = [
      "searxng"
    ];

    networking.firewall.allowedTCPPorts = [8080];

    virtualisation.oci-containers = {
      backend = "podman";
      containers.searxng = {
        image = "docker.io/searxng/searxng:latest";
        autoStart = true;
        extraOptions = [
          "--network=host"
        ];

        volumes = [
          "/persist/searxng/config:/etc/searxng:Z"
          "/persist/searxng/data:/var/lib/searxng:Z"
        ];

        environment = {
          SEARXNG_BASE_URL = "http://localhost:8080";
        };
      };
    };

    systemd.services."podman-searxng" = {
      preStart = ''
        mkdir -p /persist/searxng/config /persist/searxng/data
        cp ${settingsYml} /persist/searxng/config/settings.yml
      '';
    };
  };
}
