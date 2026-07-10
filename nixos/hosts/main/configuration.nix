{
  inputs,
  self,
  ...
}: {
  flake.nixosConfigurations.main = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.hostMain
    ];
  };

  flake.nixosModules.hostMain = {
    pkgs,
    config,
    lib,
    ...
  }: {
    imports = [
      self.nixosModules.base
      self.nixosModules.general
      self.nixosModules.desktop

      self.nixosModules.impermanence

      self.nixosModules.flatpak

      self.nixosModules.opencode
      self.nixosModules.discord
      self.nixosModules.gimp
      self.nixosModules.obsidian
      self.nixosModules.steam
      self.nixosModules.telegram
      self.nixosModules.gaming
      self.nixosModules.vr
      self.nixosModules.virt
      self.nixosModules.searxng
      self.nixosModules.user-config
      self.nixosModules.user
      self.nixosModules.sops
      self.nixosModules.keys
      self.nixosModules.mullvad
      self.nixosModules.connections

      # disko
      inputs.disko.nixosModules.disko
      self.diskoConfigurations.hostMain

      # flatpak management
      inputs.nix-flatpak.nixosModules.nix-flatpak

    ];

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

    programs.corectrl.enable = true;

    boot = {
      loader.grub.enable = true;
      loader.grub.efiSupport = true;
      loader.grub.efiInstallAsRemovable = true;

      supportedFilesystems.ntfs = true;

      kernelParams = ["quiet"];
      kernelModules = ["coretemp" "cpuid" "v4l2loopback"];

      binfmt.emulatedSystems = ["aarch64-linux"];
    };

    boot.plymouth.enable = true;

    networking = {
      hostName = lib.mkDefault "main";
      networkmanager.enable = true;
    };

    hardware.cpu.amd.updateMicrocode = true;

    services = {
      flatpak.enable = true;
      udisks2.enable = true;
      printing.enable = true;
      upower.enable = true;
      power-profiles-daemon.enable = true;
    };

    programs.alvr.enable = true;
    programs.alvr.openFirewall = true;

    environment.systemPackages = with pkgs; [
      winetricks
      glib

      bs-manager

      zerotierone

      android-tools
      self.packages."${pkgs.stdenv.hostPlatform.system}".ask

      self.packages."${pkgs.stdenv.hostPlatform.system}".phisch-psst
    ];

    xdg.portal = {
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
      enable = true;
      config = {
        common = {
          default = ["gtk"];
          "org.freedesktop.impl.portal.FileChooser" = "gtk";
        };
      };
    };

    hardware.graphics.enable = true;

    programs.niri.enable = true;

    networking.firewall.enable = false;
    programs.appimage.enable = true;
    programs.appimage.binfmt = true;

    services.xserver.videoDrivers = ["amdgpu"];
    boot.initrd.kernelModules = ["amdgpu"];

    programs.obs-studio = {
      enable = true;
      plugins = with pkgs.obs-studio-plugins; [
        obs-move-transition
      ];
    };
    persistence.cache.directories = [
      ".config/obs-studio"
    ];


    system.stateVersion = "25.11";
  };
}
