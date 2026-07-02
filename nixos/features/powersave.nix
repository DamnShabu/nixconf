{
  flake.nixosModules.powersave = {
    pkgs,
    lib,
    ...
  }: {
    services.tlp.enable = true;
    services.tlp.settings.USB_AUTOSUSPEND = 0;
    services.thermald.enable = true;
    powerManagement.powertop.enable = true;

    systemd.services.disable-usb-autosuspend = {
      description = "Disable USB autosuspend for all devices";
      after = ["powertop.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c 'for d in /sys/bus/usb/devices/*/power/control; do echo on > \"$d\"; done; for d in /sys/bus/usb/devices/*/power/autosuspend; do echo -1 > \"$d\"; done'";
      };
    };

    hardware.amdgpu.overdrive.enable = true;
    services.lact.enable = true;

    # systemd.services.lact-monitor = {
    #   enable = true;
    #   description = "Monitor PowerProfiles and update LACT profile";
    #   after = ["network.target" "lactd.service" "power-profiles-daemon.service"];
    #   wants = ["lactd.service" "power-profiles-daemon.service"];
    #   serviceConfig = {
    #     Type = "simple";
    #     ExecStartPre = lib.getExe (pkgs.writeShellApplication {
    #       name = "lact-initial-set";
    #       runtimeInputs = [pkgs.lact pkgs.glib pkgs.dbus pkgs.power-profiles-daemon];
    #       text = ''
    #         profile=$(powerprofilesctl get)
    #         if [[ $profile == "power-saver" ]]; then
    #             lact cli profile set "power-saver"
    #         else
    #             lact cli profile set "default"
    #         fi
    #       '';
    #     });
    #     ExecStart = lib.getExe (pkgs.writeShellApplication {
    #       name = "lact-watcher";
    #       runtimeInputs = [pkgs.libnotify pkgs.lact pkgs.glib pkgs.dbus];
    #       text = ''
    #         gdbus monitor --system --dest net.hadess.PowerProfiles |
    #         while read -r line; do
    #             if [[ $line =~ ActiveProfile ]]; then
    #                 profile=$(echo "$line" | grep -oP "(?<=<').+?(?='>)")
    #
    #                 if [[ $profile == "power-saver" ]]; then
    #                     lact cli profile set "power-saver"
    #                 else
    #                     lact cli profile set "default"
    #                 fi
    #             fi
    #         done
    #       '';
    #     });
    #     Restart = "always";
    #     User = "root";
    #   };
    #   wantedBy = ["multi-user.target"];
    # };
  };
}
