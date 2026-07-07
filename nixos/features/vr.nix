{
  flake.nixosModules.vr = {
    pkgs,
    config,
    ...
  }: let
    user = config.preferences.user.name;
  in {
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "vrstart" ''
        #!/usr/bin/env bash
        export PRESSURE_VESSEL_FILESYSTEMS_RW="$XDG_RUNTIME_DIR/wivrn/comp_ipc"
        exec "$@"
      '')
    ];

    persistence.cache.directories = [
      ".config/wivrn"
    ];

    services.wivrn = {
      enable = true;
      openFirewall = true;
      # Run WiVRn as a systemd service on startup
      autoStart = true;
    };

    hjem.users.${user} = {
      files.".config/openxr/1/active_runtime.json".source = "${pkgs.wivrn}/share/openxr/1/openxr_wivrn.json";

      files.".config/openvr/openvrpaths.vrpath".text = let
        steam = "/home/${user}/.local/share/Steam";
      in
        builtins.toJSON {
          version = 1;
          jsonid = "vrpathreg";

          external_drivers = null;
          config = ["${steam}/config"];

          log = ["${steam}/logs"];

          runtime = [
            "${pkgs.xrizer}/lib/xrizer"
            # OR
            #"${pkgs.opencomposite}/lib/opencomposite"
          ];
        };
    };
  };
}
