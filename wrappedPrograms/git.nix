{
  flake.wrappers.git = {
    wlib,
    lib,
    pkgs,
    ...
  }: {
    imports = [wlib.modules.default];
    package = pkgs.git;
    # ponytail: identity comes from the sops-decrypted git config, not plaintext.
    # sops-nix writes it to a tmpfs path (RAM only); never persisted to disk.
    env.GIT_CONFIG_GLOBAL = lib.mkIf (builtins.pathExists ../../secrets/git-config)
      "/run/secrets/git/config";
  };
}
