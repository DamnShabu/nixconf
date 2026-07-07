{self, ...}: {
  flake.nixosModules.opencode = {
    pkgs,
    config,
    ...
  }: let
    user = config.preferences.user.name;
    opencodeConfig = pkgs.writeText "opencode.json" (builtins.toJSON {
      lsp = true;
      plugin = ["@dietrichgebert/ponytail"];
      mcp = {
        nixos = {
          type = "local";
          command = ["mcp-nixos"];
          enabled = true;
        };
      };
    });
  in {
    environment.systemPackages = with pkgs; [opencode];

    persistence.data.directories = [
      ".config/opencode"
    ];

    hjem.users."${user}".files = {
      ".config/opencode/opencode.json".source = opencodeConfig;
    };
  };
}
