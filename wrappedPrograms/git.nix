{
  flake.wrappers.git = {
    wlib,
    pkgs,
    ...
  }: {
    imports = [wlib.modules.default];
    package = pkgs.git;
    env = {
      GIT_AUTHOR_NAME = "DamnShabu";
      GIT_AUTHOR_EMAIL = "DamnShabu@porkbuns.xyz";
      GIT_COMMITTER_NAME = "DamnShabu";
      GIT_COMMITTER_EMAIL = "DamnShabu@porkbuns.xyz";
    };
  };
}
