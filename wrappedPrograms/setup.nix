{
  flake.wrappers.niri-setup = { wlib, pkgs, ... }: let
    py = pkgs.python3.withPackages (ps: [ps.pygobject3]);
  in {
    imports = [wlib.modules.default];
    package = pkgs.stdenv.mkDerivation {
      name = "niri-setup";
      src = ./setup.py;
      dontUnpack = true;
      nativeBuildInputs = [pkgs.wrapGAppsHook3 pkgs.makeWrapper];
      buildInputs = [
        py pkgs.gtk3 pkgs.gobject-introspection pkgs.gdk-pixbuf
        pkgs.pango pkgs.glib pkgs.at-spi2-core pkgs.harfbuzz
      ];
      installPhase = ''
        mkdir -p $out/bin
        makeWrapper ${py}/bin/python3 $out/bin/niri-setup \
          --add-flags ${./setup.py} \
          --prefix PATH : ${pkgs.lib.makeBinPath [pkgs.flatpak]}
      '';
    };
  };

  perSystem = { pkgs, ... }: {
    packages.niri-setup-desktop = pkgs.makeDesktopItem {
      name = "niri-setup";
      exec = "niri-setup";
      desktopName = "Niri Setup";
      comment = "First-time setup: password, profile pic, and browser";
      categories = ["Utility"];
    };
  };
}
