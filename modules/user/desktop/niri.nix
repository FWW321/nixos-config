{ config, pkgs, lib, ... }:

let
  script = pkgs.writeShellScript "niri-set-max-mode" ''
    set -euo pipefail
    JQ=${lib.getExe' pkgs.jq "jq"}

    niri msg --json outputs | $JQ -r '
      to_entries[] |
      .key as $name |
      .value.modes |
      sort_by(.width * .height) | .[-1] as $max_res |
      map(select(.width == $max_res.width and .height == $max_res.height)) |
      sort_by(.refresh_rate) | .[-1] as $best |
      @sh "niri msg output \($name) mode \($best.width)x\($best.height)@\($best.refresh_rate / 1000)"
    ' | while read -r cmd; do
      eval "$cmd"
    done

    niri msg --json outputs | $JQ -r '
      to_entries[] |
      .key as $name |
      .value.modes[.value.current_mode] as $current |
      if $current.width >= 3840 then
        "niri msg output \($name) scale 1.5"
      else
        "niri msg output \($name) scale 1"
      end
    ' | while read -r cmd; do
      eval "$cmd"
    done
  '';
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "niri-set-max-mode" ''
      exec ${script}
    '')
  ];

  programs.niri = {
    enable = true;
    settings = {
      prefer-no-csd = true;
      input = {
        keyboard.xkb.layout = "us";
        mouse.accel-profile = "flat";
      };
      layout = {
        gaps = 12;
        center-focused-column = "always";
        default-column-width = {
          proportion = 0.5;
        };
        focus-ring = {
          enable = true;
          width = 3;
          active.color = config.lib.stylix.colors.withHashtag.base0E;
          inactive.color = config.lib.stylix.colors.withHashtag.base03;
        };
      };
      spawn-at-startup = [
        { command = [ "noctalia-shell-env" ]; }
      ];
      window-rules = [
        {
          matches = [ { app-id = "^steam$"; } ];
          open-maximized = true;
        }
        {
          matches = [ { app-id = ".*"; } ];
          draw-border-with-background = false;
          geometry-corner-radius = {
            top-left = 8.0;
            top-right = 8.0;
            bottom-right = 8.0;
            bottom-left = 8.0;
          };
          clip-to-geometry = true;
        }
      ];

      binds = with config.lib.niri.actions; {
        "Mod+Return".action = spawn "footclient";
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

        "Mod+V".action = spawn "noctalia-shell-env" "ipc" "call" "plugin:clipper" "toggle";
        "Mod+Shift+R".action = spawn "noctalia-shell-env" "ipc" "call" "plugin:screen-recorder" "toggle";
        "Mod+Space".action = spawn "noctalia-shell-env" "ipc" "call" "launcher" "toggle";
        "Mod+T".action = toggle-window-floating;
        "Mod+Shift+T".action = switch-focus-between-floating-and-tiling;

        "Mod+W".action = spawn "zen-beta";
        "Mod+E".action = spawn "nautilus";
        "Mod+Shift+S".action = spawn "bash" "-c" "grim -g \"$(slurp -d)\" - | satty --filename -";
        "Print".action = spawn "bash" "-c" "grim - | satty --filename -";
        "Mod+Print".action = spawn "niri" "msg" "action" "screenshot-window";
        "Mod+Shift+M".action = spawn "niri-set-max-mode";
      };
    };
  };
}
