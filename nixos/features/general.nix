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

    persistance.data.directories = [
      "nixconf"

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

    # todo: remove
    persistance.cache.directories = [
      ".local/share/zoxide"
      ".local/share/direnv"
      ".local/share/nvim"
      ".local/share/fish"
      ".config/nvim"

      ".cache/noctalia"
    ];
  };
}
