{
  flake.nixosModules.keys = {lib, config, pkgs, ...}: let
    connFile = "/run/secrets/connection.json"; # sops-decrypted (tmpfs)
    pubFile = ../../secrets/public.json; # cleartext public halves
    havePub = builtins.pathExists pubFile;

    # ponytail: decrypted private key lives ONLY in tmpfs and is handed to
    # ssh-agent (memory); the on-disk copy is deleted right after ssh-add.
    unlock = pkgs.writeShellScript "ssh-key-unlock" ''
      set -eu
      RUNDIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      KEYDIR="$RUNDIR/ssh-key"
      mkdir -p "$KEYDIR"
      chmod 700 "$KEYDIR"
      KEY="$KEYDIR/id_ed25519"

      if [ -s ${connFile} ]; then
        ${pkgs.jq}/bin/jq -r '.ssh_private // empty' ${connFile} > "$KEY"
        if [ -s "$KEY" ]; then
          chmod 600 "$KEY"
          if ${pkgs.openssh}/bin/ssh-add "$KEY" 2>/dev/null; then
            rm -f "$KEY"
          fi
        else
          rm -f "$KEY"
        fi
      fi

      mkdir -p "$HOME/.ssh"
      chmod 700 "$HOME/.ssh"
      ${lib.optionalString havePub ''
        if [ -f ${pubFile} ]; then
          ${pkgs.jq}/bin/jq -r '.ssh_public // empty' ${pubFile} > "$HOME/.ssh/id_ed25519.pub"
          chmod 644 "$HOME/.ssh/id_ed25519.pub"
        fi
      ''}
    '';

    lock = pkgs.writeShellScript "ssh-key-lock" ''
      set -eu
      RUNDIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      ${pkgs.openssh}/bin/ssh-add -D 2>/dev/null || true
      rm -rf "$RUNDIR/ssh-key"
    '';
  in {
    # ponytail: only active when a private SSH key was saved by the wizard
    config = lib.mkIf (builtins.pathExists ../../secrets/connection.json) {
      systemd.user.services.ssh-key-unlock = {
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${unlock}";
          ExecStop = "${lock}";
        };
        wantedBy = ["graphical-session.target"];
      };

      systemd.user.services.ssh-key-lock = {
        serviceConfig = {Type = "oneshot"; ExecStart = "${lock}";};
        wantedBy = ["graphical-session.target"];
      };

      # ponytail: idle reaper — purge in-memory + tmpfs key 30 min after unlock
      systemd.user.timers.ssh-key-lock-idle = {
        timerConfig = {
          OnActiveSec = "30min";
          Unit = "ssh-key-lock.service";
        };
        wantedBy = ["timers.target"];
      };

      environment.systemPackages = [pkgs.jq pkgs.openssh];
    };
  };
}
