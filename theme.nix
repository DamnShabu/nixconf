let
  theme = {
    base00 = "#0F1419"; # bg
    base01 = "#131721"; # dark
    base02 = "#272D38";
    base03 = "#3E4B59";
    base04 = "#BFBDB6";
    base05 = "#E6E1CF"; # fg
    base06 = "#E6E1CF"; # light fg
    base07 = "#F3F4F5"; # lightest fg
    base08 = "#F07178"; # red
    base09 = "#FF8F40"; # orange
    base0A = "#FFB454"; # yellow
    base0B = "#B8CC52"; # green
    base0C = "#95E6CB"; # cyan
    base0D = "#59C2FF"; # blue
    base0E = "#D2A6FF"; # magenta
    base0F = "#E6B673"; # brown
  };

in {
  flake = {
    inherit theme;
  };
}
