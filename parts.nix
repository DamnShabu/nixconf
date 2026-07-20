{inputs, ...}: {
  imports = [
    inputs.wrapper-modules.flakeModules.wrappers
  ];

  config = {
    systems = [
      "aarch64-darwin"
      "aarch64-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];

    perSystem = {pkgs, lib, system, ...}: {
      packages.qylock = pkgs.stdenvNoCC.mkDerivation {
        pname = "qylock";
        version = "main";
        src = pkgs.fetchFromGitHub {
          owner = "Darkkal44";
          repo = "qylock";
          rev = "main";
          hash = "sha256-jVNBiyhdA0lU2CapcgoWO9WlnEF/EBg+JfpPf/G/CzQ=";
        };
        installPhase = ''
          mkdir -p $out/share/sddm/themes/clockwork
          cp -r themes/clockwork/orbital/* $out/share/sddm/themes/clockwork/
          # also install other themes alongside
          for d in themes/*/; do
            name=$(basename "$d")
            [ "$name" = "clockwork" ] && continue
            cp -r "$d" $out/share/sddm/themes/
          done
        '';
        meta.platforms = lib.platforms.linux;
      };

      packages.yin = pkgs.stdenv.mkDerivation {
        pname = "yin";
        version = "unstable-2025-04-14";
        src = pkgs.fetchFromGitHub {
          owner = "SaverinOnRails";
          repo = "yin";
          rev = "ef3d2f7fb2b297322df28c7e0169d3d7aeb4e5bd";
          hash = "sha256-yskUFINzewwePu8d250+Dm4E4n/zowYvHoCHdxmOKps=";
        };
        nativeBuildInputs = with pkgs; [meson ninja pkg-config python3 wayland-scanner];
        buildInputs = with pkgs; [wayland wayland-protocols libglvnd mesa libva ffmpeg libxkbcommon];
        installPhase = ''
          mkdir -p $out/bin
          cp yin yinctl $out/bin/
        '';
        meta = {
          description = "Lightweight, Hardware Accelerated Wayland Wallpaper daemon";
          homepage = "https://github.com/SaverinOnRails/yin";
          license = pkgs.lib.licenses.gpl3Plus;
          platforms = pkgs.lib.platforms.linux;
          mainProgram = "yin";
        };
      };

      packages.phisch-psst = pkgs.rustPlatform.buildRustPackage rec {
        pname = "psst";
        version = "0.2.0";
        src = pkgs.fetchFromGitHub {
          owner = "phisch";
          repo = "psst";
          rev = "v${version}";
          hash = "sha256-yZ0oHKQ4VEZRXxNCVFIumKMT/wIfGt+o/gwubk8u4sU=";
        };
        cargoLock.lockFile = "${src}/Cargo.lock";
        nativeBuildInputs = with pkgs; [
          pkg-config
          makeWrapper
          cmake
          clang
        ];
        buildInputs = with pkgs; [
          wayland
          wayland-protocols
          libxkbcommon
          fontconfig
          freetype
          libGL
          vulkan-loader
          openssl
          systemd
        ] ++ lib.optionals pkgs.stdenv.isLinux [
          pkgs.alsa-lib
        ];
        postFixup = let
          libPath = lib.makeLibraryPath [pkgs.wayland pkgs.libglvnd pkgs.mesa pkgs.vulkan-loader];
        in ''
          for bin in $out/bin/*; do
            wrapProgram "$bin" --prefix LD_LIBRARY_PATH : "${libPath}"
          done
        '';
        meta.platforms = lib.platforms.linux;
      };
    };
  };
}
