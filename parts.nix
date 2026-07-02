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
      packages.yin = pkgs.stdenv.mkDerivation rec {
        pname = "yin";
        version = "0.1";
        src = pkgs.fetchFromGitHub {
          owner = "SaverinOnRails";
          repo = "yin";
          rev = "8769afc299a47b4f26cb0315a8f5975def277b33";
          hash = "sha256-9dBTXq2u9iB0HtnUI2/1QSv/8fllIlmL1YZ/u/+dd1I=";
        };
        nativeBuildInputs = with pkgs; [meson ninja pkg-config wayland-scanner];
        buildInputs = with pkgs; [
          wayland
          wayland-protocols
          libglvnd
          mesa
          ffmpeg
          libva
        ];
        # yin's meson.build doesn't set install:true on executables
        dontUseMesonInstall = true;
        installPhase = ''
          mkdir -p $out/bin
          cp yin $out/bin/
          cp yinctl $out/bin/
        '';
        meta.platforms = lib.platforms.linux;
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
