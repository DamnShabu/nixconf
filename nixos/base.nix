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

        autostart = lib.mkOption {
          type = lib.types.listOf (lib.types.either lib.types.str lib.types.package);
          default = [];
        };

        keymap = lib.mkOption {
          type = lib.types.lazyAttrsOf (lib.types.either lib.types.attrs lib.types.package);
          default = {};
        };

        keyboard = {
          layout = lib.mkOption {
            type = lib.types.str;
            default = "us,ru,ua";
          };
          xkbOptions = lib.mkOption {
            type = lib.types.str;
            default = "grp:alt_shift_toggle,caps:escape";
          };
          repeatRate = lib.mkOption {
            type = lib.types.int;
            default = 40;
          };
          repeatDelay = lib.mkOption {
            type = lib.types.int;
            default = 250;
          };
        };

        locale = {
          timeZone = lib.mkOption {
            type = lib.types.str;
            default = "Europe/Kyiv";
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

        monitors = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule {
            options = {
              primary = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              width = lib.mkOption {
                type = lib.types.int;
                example = 1920;
              };
              height = lib.mkOption {
                type = lib.types.int;
                example = 1080;
              };
              refreshRate = lib.mkOption {
                type = lib.types.float;
                default = 60;
              };
              x = lib.mkOption {
                type = lib.types.int;
                default = 0;
              };
              y = lib.mkOption {
                type = lib.types.int;
                default = 0;
              };
              enabled = lib.mkOption {
                type = lib.types.bool;
                default = true;
              };
            };
          });
          default = {};
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
