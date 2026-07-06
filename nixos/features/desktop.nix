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

    services.xserver.enable = true;
    services.displayManager.sddm.enable = true;
    services.displayManager.sddm.theme = "clockwork";
    services.displayManager.sddm.extraPackages = [ pkgs.qt6.qt5compat pkgs.qt6.qtmultimedia ];
    services.displayManager.defaultSession = "niri";

    environment.systemPackages = [
      selfpkgs.terminal
      pkgs.pcmanfm
      selfpkgs.noctalia-shell
      pkgs.wl-clipboard
      selfpkgs.qylock
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

    security.polkit.enable = true;

    hardware = {
      enableAllFirmware = true;

      bluetooth.enable = true;

      graphics = {
        enable = true;
        enable32Bit = true;
      };
    };
  };
}
