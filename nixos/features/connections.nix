{
  flake.nixosModules.connections = {lib, config, pkgs, ...}: let
    connFile = "/run/secrets/connection.json"; # sops-decrypted (tmpfs)

    # ponytail: tailscale/gpg/openpgp/signify all come from the wizard's
    # encrypted connection.json. AI keys are NOT written to disk — `ask` reads
    # them straight from the tmpfs /run/secrets/connection.json (see llm.nix),
    # honoring the "no cleartext secret at rest" rule. gpg keys are fetched from
    # the keyserver by fingerprint; the signify pubkey is dropped into /etc/signify.
    setup = pkgs.writeShellScript "connections-setup" ''
      set -u
      [ -s ${connFile} ] || exit 0
      JQ="${pkgs.jq}/bin/jq"

      # ponytail: gpg/openpgp fingerprint -> fetch pubkey from keyserver
      for fp in $($JQ -r '.gpg // .openpgp // empty' ${connFile}); do
        [ -n "$fp" ] || continue
        ${pkgs.gnupg}/bin/gpg --recv-keys "$fp" 2>/dev/null || true
      done

      # ponytail: signify public key -> /etc/signify for verification use
      sig="$($JQ -r '.signify // empty' ${connFile})"
      if [ -n "$sig" ]; then
        install -Dm644 <(printf '%s\n' "$sig") /etc/signify/mujo.pub
      fi
    '';
  in {
    config = lib.mkIf (builtins.pathExists ../../secrets/connection.json) {
      # ponytail: tailscale is a toggle in the wizard; enable the service, the
      # user logs in interactively (no auth key is collected).
      services.tailscale.enable = lib.mkDefault (
        let conn = if builtins.pathExists connFile
                   then builtins.fromJSON (builtins.readFile connFile) else {};
        in conn ? tailscale && conn.tailscale == true
      );

      systemd.services.connections-setup = {
        description = "Bootstrap tailscale/gpg/signify/AI keys from saved secrets";
        after = ["sops-install-secrets.service"];
        wants = ["sops-install-secrets.service"];
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

      environment.systemPackages = [pkgs.jq pkgs.gnupg pkgs.tailscale];
    };
  };
}
