{self, ...}: {
  flake.nixosModules.desktop = {pkgs, config, ...}: let
    selfpkgs = self.packages."${pkgs.stdenv.hostPlatform.system}";
  in {
    imports = [
      self.nixosModules.gtk
      self.nixosModules.vicinae

      self.nixosModules.pipewire
      self.nixosModules.zen
    ];

    programs.niri.enable = true;
    programs.niri.package = selfpkgs.niri;

    programs.mangowc.enable = true;
    programs.mangowc.package = selfpkgs.mangowc;

    environment.systemPackages = [
      selfpkgs.terminal
      pkgs.pcmanfm
      selfpkgs.noctalia-shell
      pkgs.wl-clipboard
    ];

    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      ubuntu-sans
      cm_unicode
      corefonts
      unifont
    ];

    fonts.fontconfig.defaultFonts = {
      serif = ["Ubuntu Sans"];
      sansSerif = ["Ubuntu Sans"];
      monospace = ["JetBrainsMono Nerd Font"];
    };

    time.timeZone = config.preferences.locale.timeZone;
    i18n.defaultLocale = config.preferences.locale.default;
    i18n.extraLocaleSettings = config.preferences.locale.extra;

    services.upower.enable = true;

    security.polkit.enable = true;

    hardware = {
      enableAllFirmware = true;

      bluetooth.enable = true;
      bluetooth.powerOnBoot = true;

      graphics = {
        enable = true;
        enable32Bit = true;
      };
    };
  };
}
