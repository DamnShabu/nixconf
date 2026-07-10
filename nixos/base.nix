{
  flake.nixosModules.base = {
    lib,
    pkgs,
    ...
  }: {
    options = {
      preferences = {
        user = {
          name = lib.mkOption {
            type = lib.types.str;
            default = "yurii";
          };
        };

        locale = {
          timeZone = lib.mkOption {
            type = lib.types.str;
            default = "Europe/Berlin";
          };
          default = lib.mkOption {
            type = lib.types.str;
            default = "en_US.UTF-8";
          };
          extra = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            default = {
              LC_ADDRESS = "uk_UA.UTF-8";
              LC_IDENTIFICATION = "uk_UA.UTF-8";
              LC_MEASUREMENT = "uk_UA.UTF-8";
              LC_MONETARY = "uk_UA.UTF-8";
              LC_NAME = "uk_UA.UTF-8";
              LC_NUMERIC = "uk_UA.UTF-8";
              LC_PAPER = "uk_UA.UTF-8";
              LC_TELEPHONE = "uk_UA.UTF-8";
              LC_TIME = "uk_UA.UTF-8";
            };
          };
        };
      };

      persistence = {
        enable = lib.mkEnableOption "enable persistence";

        nukeRoot.enable = lib.mkEnableOption "Destroy /root on every boot";

        volumeGroup = lib.mkOption {
          default = "btrfs_vg";
        };

        user = lib.mkOption {
          default = "username";
        };

        directories = lib.mkOption {
          default = [];
        };

        files = lib.mkOption {
          default = [];
        };

        data.directories = lib.mkOption {
          default = [];
        };

        data.files = lib.mkOption {
          default = [];
        };

        cache.directories = lib.mkOption {
          default = [];
        };

        cache.files = lib.mkOption {
          default = [];
        };
      };
    };
  };
}
