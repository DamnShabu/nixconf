{
  flake.nixosModules.base = {lib, ...}: {
    options.preferences.wifi = {
      ssid = lib.mkOption {
        type = lib.types.str;
        default = "TROJANVIRUS67";
      };
      passphrase = lib.mkOption {
        type = lib.types.str;
        default = "yuriiyuriiyurii";
      };
      country = lib.mkOption {
        type = lib.types.str;
        default = "UA";
      };
      channel = lib.mkOption {
        type = lib.types.int;
        default = 36;
      };
      band = lib.mkOption {
        type = lib.types.int;
        default = 5;
      };
    };
  };
}
