{
  flake.nixosModules.user = {lib, ...}: let
    wizardFile = ../../user-config/_user.nix;
    sopsFile = ../../secrets/username;
    wizardUser = if builtins.pathExists wizardFile then (import wizardFile).name or "yurii" else "yurii";
    sopsUser = if builtins.pathExists sopsFile then lib.trim (builtins.readFile sopsFile) else "";
    finalName = if sopsUser != "" then sopsUser else wizardUser;
  in {
    # ponytail: sops secret overrides wizard username, which overrides default "user"
    preferences.user.name = lib.mkDefault finalName;
  };
}
