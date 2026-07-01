{
  flake.nixosModules.base = {lib, ...}: {
    options.preferences.locale = {
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
  };
}
