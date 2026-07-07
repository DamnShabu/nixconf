{
  flake.nixosModules.user-config = {
    lib,
    pkgs,
    config,
    ...
  }: let
    connFile = ../../user-config/_connection.nix;
    conn = if builtins.pathExists connFile then import connFile else {};
  in {
    networking.hostName = lib.mkIf (conn ? hostname && conn.hostname != "") conn.hostname;

    environment.etc."NetworkManager/system-connections/setup-wifi.nmconnection" = lib.mkIf (conn ? wifi_ssid && conn.wifi_ssid != "") {
      text = ''
        [connection]
        id=setup-wifi
        type=wifi
        interface-name=wlan0
        autoconnect=true
        permissions=

        [wifi]
        ssid=${conn.wifi_ssid}
        mode=infrastructure
        hidden=false

        [wifi-security]
        key-mgmt=wpa-psk
        psk=${conn.wifi_password}
      '';
      mode = "0600";
    };
  };
}
