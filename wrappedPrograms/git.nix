{
  flake.wrappers.git = {
    wlib,
    pkgs,
    ...
  }: let
    userGit = import ../user-config/_git.nix;
  in {
    imports = [wlib.modules.default];
    package = pkgs.git;
    env = {
      GIT_AUTHOR_NAME = userGit.name;
      GIT_AUTHOR_EMAIL = userGit.email;
      GIT_COMMITTER_NAME = userGit.name;
      GIT_COMMITTER_EMAIL = userGit.email;
    };
  };
}
