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
      extraGroups = ["wheel" "networkmanager"];
      shell = self.packages.${pkgs.stdenv.hostPlatform.system}.environment;

      initialPassword = "12345";
      hashedPasswordFile = "/persist/passwd";
    };

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
