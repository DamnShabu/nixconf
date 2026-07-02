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
