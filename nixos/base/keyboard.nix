{
  flake.nixosModules.base = {lib, ...}: {
    options.preferences.keyboard = {
      layout = lib.mkOption {
        type = lib.types.str;
        default = "us,ru,ua";
        description = "XKB keyboard layout(s)";
      };
      xkbOptions = lib.mkOption {
        type = lib.types.str;
        default = "grp:alt_shift_toggle,caps:escape";
        description = "XKB keyboard options";
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
  };
}
