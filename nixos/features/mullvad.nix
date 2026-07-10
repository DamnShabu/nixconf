{
  flake.nixosModules.mullvad = {lib, config, pkgs, ...}: let
    connFile = "/run/secrets/connection.json"; # sops-decrypted (tmpfs)

    # ponytail: token comes from the wizard's encrypted connection.json. We
    # derive it at boot, log in only if no account is set, force lockdown so all
    # traffic is dropped unless it goes through Mullvad, then connect.
    setup = pkgs.writeShellScript "mullvad-setup" ''
      set -u
      TOKEN="$(${pkgs.jq}/bin/jq -r '.mullvad // empty' ${connFile})"
      [ -n "$TOKEN" ] || exit 0

      # ponytail: account login writes /etc/mullvad-vpn, needs root
      if ! ${pkgs.mullvad-vpn}/bin/mullvad account get >/dev/null 2>&1; then
        ${pkgs.mullvad-vpn}/bin/mullvad account login "$TOKEN" || exit 1
      fi

      ${pkgs.mullvad-vpn}/bin/mullvad tunnel set lockdown-mode on || true
      ${pkgs.mullvad-vpn}/bin/mullvad connect || exit 1
    '';
  in {
    config = {
      services.mullvad-vpn.enable = true;

      systemd.services.mullvad-setup = {
        description = "Bootstrap Mullvad account and lockdown from saved token";
        after = ["mullvad-daemon.service" "sops-install-secrets.service"];
        wants = ["mullvad-daemon.service" "sops-install-secrets.service"];
        wantedBy = ["multi-user.target"];
        # ponytail: re-decrypt on demand if the idle lock wiped /run/secrets
        # (wheel may restart sops-install-secrets via polkit).
        preStart = ''
          [ -s ${connFile} ] || systemctl restart sops-install-secrets.service 2>/dev/null || true
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${setup}";
        };
      };

      environment.systemPackages = [pkgs.jq pkgs.mullvad-vpn];
    };
  };
}
