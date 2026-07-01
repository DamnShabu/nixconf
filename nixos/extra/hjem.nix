{
  inputs,
  self,
  ...
}: {
  flake.nixosModules.extra_hjem = {config, pkgs, ...}: let
    user = config.preferences.user.name;
    gitconfig = pkgs.writeText "gitconfig" ''
      [user]
        name = DamnShabu
        email = DamnShabu@porkbuns.xyz
    '';
  in {
    imports = [
      inputs.hjem.nixosModules.default
    ];

    config = {
      hjem = {
        users."${user}" = {
          enable = true;
          directory = "/home/${user}";
          user = "${user}";

          files = {
            ".gitconfig".source = gitconfig;
          };
        };

        clobberByDefault = true;
      };
    };
  };
}
