{inputs, ...}: {
  flake.nixosModules.sops = {lib, config, pkgs, ...}: let
    user = config.preferences.user.name;
    connFile = ../../secrets/connection.json;
    gitFile = ../../secrets/git-config;
    # ponytail: keyFile lives in /run (tmpfs). Only the TPM-SEALED blob is
    # persisted to /persist — it is TPM-locked ciphertext, inert without the
    # hardware, not a secret. The wizard (setup.py) refuses to persist a
    # plaintext AGE-SECRET-KEY, so the only thing on disk is the sealed blob.
    keyFile = "/run/sops-age/keys.txt";
    persistedKeyFile = "/persist/userdata/home/${user}/sops-age/keys.txt";
  in {
    imports = [ inputs.sops-nix.nixosModules.sops ];

    # ponytail: only activate sops-nix when the encrypted secrets exist
    sops = lib.mkIf (builtins.pathExists connFile || builtins.pathExists gitFile) {
      # ponytail: TPM2-sealed age identity (age-plugin-tpm). Decryption unseals
      # the TPM-bound blob in memory only — key material never hits disk.
      age.plugins = [ pkgs.age-plugin-tpm ];
      age.keyFile = keyFile;

      secrets.connection = lib.mkIf (builtins.pathExists connFile) {
        # ponytail: decrypted into tmpfs (/run/secrets) at boot. Needed offline
        # for hostname/wifi + ssh unlock, so it is decrypted on boot and purged
        # by the idle timer when not in use. Owned by the user so the `ask` tool
        # can read AI keys from it (no cleartext on persistent disk).
        sopsFile = connFile;
        key = ""; # whole-file encryption; jq parses the fields at runtime
        path = "/run/secrets/connection.json";
        owner = user;
      };
      secrets.gitconfig = lib.mkIf (builtins.pathExists gitFile) {
        sopsFile = gitFile;
        # ponytail: git config is decrypted on-demand into tmpfs (RAM only) and
        # pointed at via GIT_CONFIG_GLOBAL. Never written to a persistent path.
        path = "/run/secrets/git/config";
        owner = "yurii";
      };
    };

    # ponytail: restore the TPM-sealed blob into tmpfs at boot, before sops-nix
    # decrypts. This is the ONLY thing persisted to disk (the inert blob). We
    # never run `age-plugin-tpm --generate` at boot — that mints a fresh key and
    # breaks the recipient. We copy the seeded blob from the wizard.
    systemd.services.sops-age-restore = lib.mkIf (builtins.pathExists connFile || builtins.pathExists gitFile) {
      wantedBy = ["sops-install-secrets.service"];
      before = ["sops-install-secrets.service"];
      requiredBy = ["sops-install-secrets.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "sops-age";
        RuntimeDirectoryMode = "0700";
        # ponytail: install as the user (not root) so the user-session wizard
        # can read the key for `sops --decrypt` (autofill). Root-only 600 made
        # the file unreadable post-reboot and broke autofill.
        User = user;
        ExecStart = "${pkgs.coreutils}/bin/install -m 600 -o ${user} -T ${persistedKeyFile} ${keyFile}";
      };
    };

    # ponytail: decrypted secrets live in tmpfs (RAM). Idle timer purges them so
    # they sit encrypted ~90% of the time. Consumers (ask, connections-setup,
    # mullvad-setup) re-trigger decryption on demand by restarting
    # sops-install-secrets.service when /run/secrets is missing — wheel is
    # granted that right via polkit in general.nix. No reboot needed.
    fileSystems."/run/secrets" = lib.mkIf (builtins.pathExists connFile || builtins.pathExists gitFile) {
      fsType = "tmpfs";
      options = ["size=1M" "mode=755"];
    };

    systemd.services.secrets-lock = {
      serviceConfig = {Type = "oneshot"; RemainAfterExit = true;};
      script = "rm -rf /run/secrets/* 2>/dev/null || true";
      wantedBy = ["multi-user.target"];
    };

    systemd.timers.secrets-lock-idle = {
      timerConfig = {
        OnActiveSec = "30min";
        OnBootSec = "30min";
        Unit = "secrets-lock.service";
      };
      wantedBy = ["timers.target"];
    };
  };
}
