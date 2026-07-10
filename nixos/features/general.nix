{self, ...}: {
  flake.nixosModules.general = {
    pkgs,
    config,
    ...
  }: {
    imports = [
      self.nixosModules.extra_hjem
      self.nixosModules.gtk
      self.nixosModules.nix
    ];

    users.users.${config.preferences.user.name} = {
      isNormalUser = true;
      description = "${config.preferences.user.name}'s account";
      # ponytail: tss group grants access to /dev/tpmrm0 so the user-session
      # wizard can seal the age key via age-plugin-tpm (no plaintext on disk).
      extraGroups = ["wheel" "networkmanager" "tss"];
      shell = self.packages.${pkgs.stdenv.hostPlatform.system}.environment;

      initialPassword = "12345";
      hashedPasswordFile = "/persist/passwd";
    };

    # ponytail: enable the TPM and expose /dev/tpmrm0 to the tss group so the
    # wizard can seal the SOPS age identity. Without this, age-plugin-tpm hits
    # "permission denied" and the wizard falls back to a PLAINTEXT key — which
    # would then be written to /persist (disk). This is what keeps secrets off disk.
    security.tpm2.enable = true;
    security.tpm2.applyUdevRules = true;

    environment.shells = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.environment
    ];

    persistence.data.directories = [
      "nixconf"

      "Pictures"
      "Videos"
      "Documents"
      "Downloads"
      "Projects"

      ".ssh"

      "Documents/.data/mullvad-vpn"

      ".config/vicinae"
      ".local/share/vicinae"
      ".local/state/vicinae"

      ".config/noctalia"

      # ponytail: only the TPM-SEALED blob lives here (inert without hardware,
      # not a plaintext key). sops-age-restore copies it into tmpfs /run/sops-age
      # at boot. The decrypted key never persists.
      "sops-age"

    ];

    system.activationScripts."create-initial-face" = {
      deps = [ "createPersistentStorageDirs" ];
      text = ''
        targetFile="/persist/userdata/home/${config.preferences.user.name}/.face"
        if [ -d "$targetFile" ]; then
          rmdir "$targetFile" 2>/dev/null || rm -rf "$targetFile"
        fi
        if [ ! -f "$targetFile" ]; then
          mkdir -p "$(dirname "$targetFile")"
          touch "$targetFile"
        fi
        chown "${config.preferences.user.name}" "$targetFile"
      '';
    };

    # ponytail: allow pkexec tee /persist/passwd for setup wizard
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
        // ponytail: let wheel re-trigger sops decryption on demand (after the
        // idle secret lock wipes /run/secrets). Needed so runtime consumers like
        // `ask` can bring the secrets back without a reboot.
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "sops-install-secrets.service" &&
            (action.lookup("verb") == "start" || action.lookup("verb") == "restart") &&
            subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';

    persistence.cache.directories = [
      ".local/share/zoxide"
      ".local/share/direnv"
      ".local/share/nvim"
      ".local/share/fish"
      ".config/nvim"

      ".cache/noctalia"
    ];
  };
}
