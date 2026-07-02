{
  flake.nixosModules.gtk = {
    pkgs,
    lib,
    config,
    ...
  }: let
    theme-package = pkgs.stdenvNoCC.mkDerivation {
      pname = "material-gnome-theme";
      version = "1.2.0";
      src = pkgs.fetchFromGitHub {
        owner = "SakibShahariar";
        repo = "material-gnome-theme";
        rev = "v1.2.0";
        hash = "sha256-q8/vUbWB2hkxcHo5MWyzIcg+piUSiAYKKUXCFnTWQ8M=";
      };
      installPhase = ''
        mkdir -p $out/share/themes/Material-Gnome
        cp -r gtk-3.0 gtk-4.0 gnome-shell themes index.theme \
          $out/share/themes/Material-Gnome/
      '';
      meta.platforms = lib.platforms.linux;
    };
    theme-name = "Material-Gnome";

    icon-theme-package = pkgs.gruvbox-plus-icons;
    icon-theme-name = "Gruvbox-Plus-Dark";

    cursor-theme-package = pkgs.bibata-cursors;
    cursor-theme-name = "Bibata-Modern-Classic";

    gtksettings = ''
      [Settings]
      gtk-icon-theme-name = ${icon-theme-name}
      gtk-theme-name = ${theme-name}
      gtk-cursor-theme-name = ${cursor-theme-name}
    '';
  in {
    environment = {
      etc = {
        "xdg/gtk-3.0/settings.ini".text = gtksettings;
        "xdg/gtk-4.0/settings.ini".text = gtksettings;
      };
    };

    environment.variables = {
      GTK_THEME = theme-name;
      XCURSOR_THEME = cursor-theme-name;
    };

    programs = {
      dconf = {
        enable = lib.mkDefault true;
        profiles = {
          user = {
            databases = [
              {
                lockAll = false;
                settings = {
                  "org/gnome/desktop/interface" = {
                    gtk-theme = theme-name;
                    icon-theme = icon-theme-name;
                    cursor-theme = cursor-theme-name;
                    color-scheme = "prefer-dark";
                  };
                };
              }
            ];
          };
        };
      };
    };

    environment.systemPackages = [
      theme-package
      icon-theme-package
      cursor-theme-package

      pkgs.gtk3
      pkgs.gtk4
    ];

    systemd.user.tmpfiles.rules = [
      "L+ %h/.local/share/themes/Material-Gnome - - - - ${theme-package}/share/themes/Material-Gnome"
      "L+ %h/.config/noctalia/palettes - - - - ${theme-package}/share/themes/Material-Gnome/themes"
    ];

    # Make theme visible to Flatpak apps
    services.flatpak.overrides = lib.mkIf config.services.flatpak.enable {
      global.Context.filesystems = ["xdg-data/themes:ro"];
    };
  };
}
