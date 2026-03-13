# filepath: ~/nixos-config/modules/user/desktop.nix
{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.niri.homeModules.niri
    inputs.walker.homeManagerModules.default
  ];

  home.packages = with pkgs; [
    kooha
    grim
    slurp
    satty
    wl-clipboard
    inputs.elephant.packages.${stdenv.hostPlatform.system}.default
    inputs.noctalia.packages.${stdenv.hostPlatform.system}.default
    inputs.zen-browser.packages.${stdenv.hostPlatform.system}.default
  ];

  programs.niri = {
    enable = true;
    settings = {
      input = {
        keyboard.xkb.layout = "us";
        mouse.accel-profile = "flat";
      };
      outputs."DP-1" = {
        variable-refresh-rate = true;
      };
      layout = {
        gaps = 12;
        center-focused-column = "always";
        default-column-width = {
          proportion = 0.5;
        };
        border = {
          enable = true;
          width = 3;
        };
      };
      spawn-at-startup = [
        { command = [ "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1" ]; }
        { command = [ "noctalia-shell" ]; }
        {
          command = [
            "fcitx5"
            "-d"
            "--replace"
          ];
        }
      ];
      window-rules = [
        {
          matches = [ { app-id = "^steam$"; } ];
          open-maximized = true;
        }
        {
          matches = [ { app-id = "^polkit-gnome-authentication-agent-1$"; } ];
          open-floating = true;
        }
      ];

      binds = with config.lib.niri.actions; {
        "Mod+Return".action = spawn "ghostty";
        "Mod+Q".action = close-window;
        "Mod+Shift+E".action = quit;

        "Mod+Left".action = focus-column-left;
        "Mod+Right".action = focus-column-right;
        "Mod+up".action = focus-window-up;
        "Mod+Down".action = focus-window-down;

        "Mod+Shift+Left".action = move-column-left;
        "Mod+Shift+Right".action = move-column-right;
        "Mod+Shift+Up".action = move-window-up;
        "Mod+Shift+Down".action = move-window-down;

        "Mod+F".action = maximize-column;
        "Mod+Shift+F".action = fullscreen-window;
        "Mod+C".action = center-column;

        "Mod+1".action = focus-workspace 1;
        "Mod+2".action = focus-workspace 2;
        "Mod+3".action = focus-workspace 3;

        "Mod+Shift+Slash".action = show-hotkey-overlay;
        "Mod+O".action = toggle-overview;

        "Mod+Page_Down".action = focus-workspace-down;
        "Mod+Page_Up".action = focus-workspace-up;

        "Mod+R".action = switch-preset-column-width;
        "Mod+BracketLeft".action = consume-or-expel-window-left;
        "Mod+BracketRight".action = consume-or-expel-window-right;

        "Mod+V".action = toggle-window-floating;
        "Mod+Shift+V".action = switch-focus-between-floating-and-tiling;

        "Mod+D".action = spawn "walker";
        "Mod+W".action = spawn "zen";
        "Mod+Shift+S".action = spawn "bash" "-c" "grim -g \"$(slurp)\" - | satty --filename -";
        "Print".action = spawn "bash" "-c" "grim - | satty --filename -";
      };
    };
  };

  systemd.user.services.niri-auto-scale = {
    Unit = {
      Description = "Niri dynamic scale daemon";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.writeShellScript "niri-auto-scale" ''
        ${pkgs.niri}/bin/niri msg --json event-stream | while read -r event; do
          if echo "$event" | ${pkgs.jq}/bin/jq -e 'has("OutputsChanged")' > /dev/null; then
            CURRENT_WIDTH=$(${pkgs.niri}/bin/niri msg --json outputs | ${pkgs.jq}/bin/jq -r '.[] | select(.name == "DP-1") | .current_mode.width')
            if [ "$CURRENT_WIDTH" = "3840" ]; then
              ${pkgs.niri}/bin/niri msg output DP-1 scale 1.5
            elif [ "$CURRENT_WIDTH" = "1920" ]; then
              ${pkgs.niri}/bin/niri msg output DP-1 scale 1.0;
            fi
          fi
        done
      ''}";
      Restart = "on-failure";
      RestartSec = "2";
    };
  };

  xresources.properties = {
    "Xft.dpi" = 144;
  };

  xdg.configFile."noctalia/settings.json".text = builtins.toJSON {
    settingsVersion = 0;
    bar = {
      position = "top";
      floating = true;
      marginVertical = 8;
      marginHorizontal = 12;
      outerCorners = true;
      showCapsule = true;
    };
  };

  programs.walker = {
    enable = true;
    runAsService = true;
    config = {
      theme = "default";
      placeholders.default = {
        input = "Search...";
        list = "No Results";
      };
      providers.prefixed = [
        {
          provider = "calculator";
          prefix = "=";
        }
        {
          provider = "websearch";
          prefix = "?";
        }
      ];
    };
  };
}
