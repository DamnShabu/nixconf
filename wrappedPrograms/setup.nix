{
  flake.wrappers.mojo-setup = { wlib, pkgs, ... }: let
    py = pkgs.python3.withPackages (ps: [ps.pygobject3]);
  in {
    imports = [wlib.modules.default];
    package = pkgs.stdenv.mkDerivation {
      name = "mojo-setup";
      src = ./setup.py;
      dontUnpack = true;
      nativeBuildInputs = [pkgs.wrapGAppsHook3 pkgs.makeWrapper];
      buildInputs = [
        py pkgs.gtk3 pkgs.gobject-introspection pkgs.gdk-pixbuf
        pkgs.pango pkgs.glib pkgs.at-spi2-core pkgs.harfbuzz
      ];
      installPhase = ''
        mkdir -p $out/bin
        makeWrapper ${py}/bin/python3 $out/bin/mojo-setup \
          --add-flags ${./setup.py} \
          --prefix PATH : ${pkgs.lib.makeBinPath [pkgs.flatpak pkgs.mkpasswd pkgs.age-plugin-tpm pkgs.age]}
      '';
    };
  };

  perSystem = { pkgs, ... }: {
    packages.mojo-setup-desktop = pkgs.makeDesktopItem {
      name = "mojo-setup";
      exec = "mojo-setup";
      desktopName = "Niri Setup";
      comment = "First-time setup: password, profile pic, and browser";
      categories = ["Utility"];
    };
  };
}
