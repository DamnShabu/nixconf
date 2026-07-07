{
  self,
  lib,
  inputs,
  ...
}: {
  flake.wrappers.niri = {
    wlib,
    pkgs,
    config,
    ...
  }: let
    noctaliaExe = lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.noctalia-shell;
  in {
    imports = [wlib.wrapperModules.niri];

    options.terminal = lib.mkOption {
      type = lib.types.str;
      default = "kitty";
    };

    config.settings = {
      prefer-no-csd = _: {};

      hotkey-overlay = {
        show-at-startup = false;
      };

      cursor = {
        xcursor-theme = "Bibata-Modern-Classic";
        xcursor-size = 24;
      };

      input = {
        focus-follows-mouse = _: {};

        keyboard = {
          xkb = {
            layout = "us,ru,ua";
            options = "grp:alt_shift_toggle,caps:escape";
          };
          repeat-rate = 40;
          repeat-delay = 250;
        };

        touchpad = {
          natural-scroll = _: {};
          tap = _: {};
        };

        mouse = {
          accel-profile = "flat";
        };
      };

      binds = {
        "Mod+Tab".toggle-overview = _: {};

        "Mod+Return".spawn = config.terminal;

        "Mod+Q".close-window = _: {};
        "Mod+Space"."spawn-sh" = "vicinae toggle";

        "Mod+F".maximize-column = _: {};
        "Mod+G".fullscreen-window = _: {};
        "Mod+Shift+F".toggle-window-floating = _: {};
        "Mod+C".center-column = _: {};

        "Mod+H".focus-column-left = _: {};
        "Mod+L".focus-column-right = _: {};
        "Mod+K".focus-window-up = _: {};
        "Mod+J".focus-window-down = _: {};

        "Mod+Left".focus-column-left = _: {};
        "Mod+Right".focus-column-right = _: {};
        "Mod+Up".focus-window-up = _: {};
        "Mod+Down".focus-window-down = _: {};

        "Mod+Shift+H".move-column-left = _: {};
        "Mod+Shift+L".move-column-right = _: {};
        "Mod+Shift+K".move-window-up = _: {};
        "Mod+Shift+J".move-window-down = _: {};

        "Mod+1".focus-workspace = "w0";
        "Mod+2".focus-workspace = "w1";
        "Mod+3".focus-workspace = "w2";
        "Mod+4".focus-workspace = "w3";
        "Mod+5".focus-workspace = "w4";
        "Mod+6".focus-workspace = "w5";
        "Mod+7".focus-workspace = "w6";
        "Mod+8".focus-workspace = "w7";
        "Mod+9".focus-workspace = "w8";
        "Mod+0".focus-workspace = "w9";

        "Mod+Shift+1".move-column-to-workspace = "w0";
        "Mod+Shift+2".move-column-to-workspace = "w1";
        "Mod+Shift+3".move-column-to-workspace = "w2";
        "Mod+Shift+4".move-column-to-workspace = "w3";
        "Mod+Shift+5".move-column-to-workspace = "w4";
        "Mod+Shift+6".move-column-to-workspace = "w5";
        "Mod+Shift+7".move-column-to-workspace = "w6";
        "Mod+Shift+8".move-column-to-workspace = "w7";
        "Mod+Shift+9".move-column-to-workspace = "w8";
        "Mod+Shift+0".move-column-to-workspace = "w9";

        "Mod+S".spawn-sh = "${noctaliaExe} ipc call launcher toggle";
        "Mod+V".spawn-sh = "${pkgs.alsa-utils}/bin/amixer sset Capture toggle";

        "XF86AudioRaiseVolume".spawn-sh = "wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%+";
        "XF86AudioLowerVolume".spawn-sh = "wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%-";

        "Mod+Ctrl+H".set-column-width = "-5%";
        "Mod+Ctrl+L".set-column-width = "+5%";
        "Mod+Ctrl+J".set-window-height = "-5%";
        "Mod+Ctrl+K".set-window-height = "+5%";

        "Mod+WheelScrollDown".focus-column-left = _: {};
        "Mod+WheelScrollUp".focus-column-right = _: {};
        "Mod+Ctrl+WheelScrollDown".focus-workspace-down = _: {};
        "Mod+Ctrl+WheelScrollUp".focus-workspace-up = _: {};

        "Mod+Ctrl+S".spawn-sh = "${pkgs.grim}/bin/grim -l 0 - | ${pkgs.wl-clipboard}/bin/wl-copy";

        "Mod+Shift+E".spawn-sh = "${pkgs.wl-clipboard}/bin/wl-paste | ${pkgs.swappy}/bin/swappy -f -";

        "Mod+Shift+S".spawn-sh = "${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp -w 0)\" - | ${pkgs.wl-clipboard}/bin/wl-copy";

      };

      layout = {
        gaps = 5;

        struts = {
          left = 10;
          right = 10;
          top = 10;
          bottom = 10;
        };

        focus-ring = {
          off = _: {};
        };
      };

      window-rules = [
        {
          geometry-corner-radius = 8;
          clip-to-geometry = true;
        }
      ];

      layer-rules = [
        {
          matches = [
            { namespace = "^noctalia-overview-"; }
          ];
          place-within-backdrop = true;
        }
        {
          matches = [
            { namespace = "^psst-"; }
          ];
          background-effect = {
            blur = true;
            xray = true;
          };
          geometry-corner-radius = 16;
        }
      ];

      workspaces = let
        settings = {layout.gaps = 5;};
      in {
        "w0" = settings;
        "w1" = settings;
        "w2" = settings;
        "w3" = settings;
        "w4" = settings;
        "w5" = settings;
        "w6" = settings;
        "w7" = settings;
        "w8" = settings;
        "w9" = settings;
      };

      outputs = {
        "DP-1" = {
          mode = "1920x1080@165.003";
          position = _: {
            props = {
              x = 0;
              y = 1080;
            };
          };
          scale = 1.0;
        };
        "HDMI-A-1" = {
          mode = "1920x1080@60";
          position = _: {
            props = {
              x = 0;
              y = 0;
            };
          };
          scale = 1.0;
        };
      };

      xwayland-satellite.path =
        lib.getExe pkgs.xwayland-satellite;

      spawn-sh-at-startup = [
        "${self.packages.${pkgs.stdenv.hostPlatform.system}.psst-polkit-agent}/bin/psst-polkit-agent"
        "${self.packages.${pkgs.stdenv.hostPlatform.system}.psst-pinentry}/bin/psst-pinentry"
        "${self.packages.${pkgs.stdenv.hostPlatform.system}.psst-keyring-prompter}/bin/psst-keyring-prompter"
        noctaliaExe
      ];
    };
  };
}
