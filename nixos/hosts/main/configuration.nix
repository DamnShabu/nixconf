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
    ...
  }: {
    imports = [
      self.nixosModules.base
      self.nixosModules.general
      self.nixosModules.desktop

      self.nixosModules.impermanence

      self.nixosModules.flatpak

      self.nixosModules.discord
      self.nixosModules.gimp
      self.nixosModules.obsidian
      self.nixosModules.steam
      self.nixosModules.telegram
      self.nixosModules.gaming
      self.nixosModules.vr
      self.nixosModules.powersave

      self.nixosModules.virt
      self.nixosModules.searxng

      # disko
      inputs.disko.nixosModules.disko
      self.diskoConfigurations.hostMain

      # flatpak management
      inputs.nix-flatpak.nixosModules.nix-flatpak
    ];

    preferences.monitors = {
      "HDMI-A-1" = {
        width = 1920;
        height = 1080;
        refreshRate = 60;
        x = 0;
        y = 0;
      };
      "DP-1" = {
        width = 1920;
        height = 1080;
        refreshRate = 165.003;
        x = 0;
        y = 1080;
      };
    };

    programs.corectrl.enable = true;

    boot = {
      kernelPackages = pkgs.linuxPackages_latest;

      loader.grub.enable = true;
      loader.grub.efiSupport = true;
      loader.grub.efiInstallAsRemovable = true;

      supportedFilesystems.ntfs = true;

      # kernelParams = ["quiet" "amd_pstate=guided" "processor.max_cstate=1"];
      kernelParams = ["quiet"];
      kernelModules = ["mt7921e" "coretemp" "cpuid" "v4l2loopback"];

      binfmt.emulatedSystems = ["aarch64-linux"];
    };

    boot.plymouth.enable = true;

    networking = {
      hostName = "main";
      networkmanager.enable = true;
    };

    hardware.cpu.amd.updateMicrocode = true;

    services = {
      hardware.openrgb.enable = true;
      flatpak.enable = true;
      udisks2.enable = true;
      printing.enable = true;
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

      mullvad-vpn
    ];

    services.mullvad-vpn.enable = true;

    xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];
    xdg.portal.enable = true;

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
    persistance.cache.directories = [
      ".config/obs-studio"
    ];

    systemd.services.create_ap = let
      apPkg = pkgs.linux-wifi-hotspot;
    in {
      description = "Create AP Service";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      path = [pkgs.iproute2 pkgs.gawk pkgs.iw];
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 10;
        RestartSteps = 5;
      };
      script = ''
        set -eu

        for i in $(seq 1 10); do
          WIFI=$(ip -o link show | grep -v lo | awk -F': ' '/^[0-9]+: wl/{print $2; exit}' || true)
          if [ -n "$WIFI" ]; then
            ip link set "$WIFI" up 2>/dev/null || true
            break
          fi
          sleep 1
        done

        if [ -z "$WIFI" ]; then
          echo "create_ap: no wifi interface found"
          exit 1
        fi

        ETHERNET=$(ip -o link show | grep -v lo | awk -F': ' '/^[0-9]+: e/{print $2; exit}' || true)
        echo "create_ap: ethernet=$ETHERNET wifi=$WIFI"

        CONF=$(mktemp)
        {
          echo "INTERNET_IFACE=$ETHERNET"
          echo "WIFI_IFACE=$WIFI"
          echo "SSID=${config.preferences.wifi.ssid}"
          echo "PASSPHRASE=${config.preferences.wifi.passphrase}"
          echo "FREQ_BAND=${toString config.preferences.wifi.band}"
          echo "COUNTRY=${config.preferences.wifi.country}"
          echo "CHANNEL=${toString config.preferences.wifi.channel}"
          echo "IEEE80211N=1"
          echo "IEEE80211AC=1"
          echo "IEEE80211AX=1"
          echo "HT_CAPAB=[HT40+]"
        } > "$CONF"

        exec ${apPkg}/bin/create_ap --config "$CONF"
      '';
    };

    # no conflicts
    networking.networkmanager.unmanaged = ["wl*"];
    # speed
    networking.firewall.allowedUDPPorts = [53 67];

    system.stateVersion = "23.11";
  };
}
