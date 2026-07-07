{
  self,
  lib,
  ...
}: let
  psstConfig = pkgs: pkgs.runCommand "psst-config" {} ''
    mkdir -p $out/psst
    cat > $out/psst/theme.kdl << 'KDL'
backdrop {
    background "#0F141980"
}

window {
    background "#131721CC"
    border "#272D38"
    border-width 2
    radius 16
    padding { x 28; y 26 }
    gap 20
    shadow { color "#00000090"; blur 25; spread 10; offset-x 0; offset-y 15 }

    text "#E6E1CF"

    title { size 24 }

    icon {
        background "#59C2FF70"
        text "#F3F4F5"
        radius 8
        size 24
        padding { x 10; y 10 }
    }

    description-label { text "#3E4B59"; size 13 }
    description-value { text "#BFBDB6"; size 13 }

    error {
        text "#F07178"
        background "#F0717820"
        radius 6
        size 13
        padding { x 12; y 8 }
    }

    field {
        background "#0F1419"
        placeholder "#3E4B59"
        selection "#E6E1CF60"
        border "#272D38"
        border-width 2
        radius 8
        font "DejaVu Sans Mono, Liberation Mono, Noto Sans Mono"
        size 15
        padding { x 13; y 11 }
        focus { border "#59C2FF"; background "#131721" }
    }

    reveal { text "#BFBDB6"; size 20 }

    strength { background "#272D38"; radius 3; size 6 }
    strength-weak { background "#F07178" }
    strength-medium { background "#FFB454" }
    strength-strong { background "#B8CC52" }

    checkbox {
        background "#0F1419"
        text "#BFBDB6"
        border "#272D38"
        border-width 1
        radius 4
        size 16
        focus { border "#59C2FF" }
        checked { text "#E6E1CF"; border "#3E4B59" }
    }

    confirm {
        background "#59C2FF70"
        text "#F3F4F5"
        radius 6
        size 13
        padding { x 18; y 9 }
        hover { background "#59C2FFB0" }
        active { background "#59C2FF95" }
    }

    cancel {
        background "#131721"
        text "#BFBDB6"
        radius 6
        size 13
        padding { x 12; y 9 }
        hover { background "#272D38" }
        active { background "#3E4B59" }
    }

    hint-key { text "#E6E1CF"; size 12 }
    hint-word { text "#3E4B59"; size 12 }
KDL
  '';

  wrapPsstBin = {pkgs, binName}:
    pkgs.writeShellScriptBin binName ''
      export XDG_CONFIG_HOME="${psstConfig pkgs}"
      exec ${self.packages.${pkgs.stdenv.hostPlatform.system}.phisch-psst}/bin/${binName}
    '';
in {
  perSystem = {pkgs, ...}: let
    bins = ["psst-polkit-agent" "psst-pinentry" "psst-keyring-prompter"];
  in {
    packages = builtins.listToAttrs (map (name: {
      inherit name;
      value = wrapPsstBin {inherit pkgs; binName = name;};
    }) bins);
  };
}
