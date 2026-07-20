{
  lib,
  inputs,
  self,
  ...
}: {
  flake.wrappers.environment = {pkgs, ...}: let
    selfpkgs = self.packages."${pkgs.stdenv.hostPlatform.system}";
  in {
    imports = [self.wrapperModules.fish];
    binName = "fish";
    runtimePkgs = [
      pkgs.nil
      pkgs.nixd
      pkgs.statix
      pkgs.alejandra
      pkgs.manix
      pkgs.nix-inspect
      pkgs.file
      pkgs.unzip
      pkgs.zip
      pkgs.p7zip
      pkgs.wget
      pkgs.killall
      pkgs.sshfs
      pkgs.fzf
      pkgs.htop
      pkgs.btop
      pkgs.eza
      pkgs.fd
      pkgs.zoxide
      pkgs.dust
      pkgs.ripgrep
      pkgs.fastfetch
      pkgs.tree-sitter
      pkgs.imagemagick
      pkgs.imv
      pkgs.ffmpeg-full
      pkgs.yt-dlp
      pkgs.lazygit
      pkgs.just
      pkgs.mprocs
      pkgs.nh
      pkgs.lf
      pkgs.git
      selfpkgs.nix-check-bin
      selfpkgs.jprocsall
      selfpkgs.jprocs
    ];
  };

  flake.wrappers.terminal = {pkgs, ...}: let
    selfpkgs = self.packages."${pkgs.stdenv.hostPlatform.system}";
  in {
    imports = [self.wrapperModules.kitty];
    shell = lib.getExe selfpkgs.environment;
  };

  perSystem = {pkgs, ...}: {
    packages.jprocs = inputs.wrapper-modules.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.mprocs;
      binName = "jprocs";
      addFlag = ["--just"];
      flags = {
        "--log-dir" = "/tmp/jprocs.log";
      };
    };

    packages.jprocsall = inputs.wrapper-modules.lib.wrapPackage {
      inherit pkgs;
      package = pkgs.mprocs;
      binName = "jprocsall";
      addFlag = ["--just"];
      flags = {
        "--on-init" = "{c: restart-all}";
        "--log-dir" = "/tmp/jprocsall.log";
      };
    };

    packages.nix-check-bin = pkgs.writeShellScriptBin "nix-check-bin" ''
      $EDITOR "$(nix build "$1" --no-link --print-out-paths)/bin"
    '';
  };
}
