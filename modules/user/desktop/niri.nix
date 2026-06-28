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
        center-focused-column = "never";
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

      # 允许通知操作按钮激活窗口（如点击通知的"回复"按钮聚焦对应应用）
      debug.honor-xdg-activation-with-invalid-serial = [ ];

      spawn-at-startup = [
        { command = [ "noctalia" ]; }
      ];

      window-rules = [
        # Noctalia 设置窗口以浮动弹窗形式打开
        {
          matches = [ { app-id = "^dev\\.noctalia\\.Noctalia\\.Settings$"; } ];
          open-floating = true;
          default-column-width.fixed = 1080;
          default-window-height.fixed = 920;
        }
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

      # Noctalia 壁纸层嵌入 niri overview backdrop，
      # 打开 overview 时显示 noctalia 管理的壁纸（带模糊效果）
      layer-rules = [
        {
          matches = [ { namespace = "^noctalia-backdrop"; } ];
          place-within-backdrop = true;
        }
      ];

      binds = with config.lib.niri.actions; {
        "Mod+Return".action = spawn "footclient";
        "Mod+Q".action = close-window;
        "Mod+Shift+E".action = spawn "noctalia" "msg" "panel-toggle" "session";

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
        "Mod+4".action = focus-workspace 4;
        "Mod+5".action = focus-workspace 5;
        "Mod+6".action = focus-workspace 6;
        "Mod+7".action = focus-workspace 7;
        "Mod+8".action = focus-workspace 8;
        "Mod+9".action = focus-workspace 9;

        "Mod+Shift+1".action = move-column-to-index 1;
        "Mod+Shift+2".action = move-column-to-index 2;
        "Mod+Shift+3".action = move-column-to-index 3;
        "Mod+Shift+4".action = move-column-to-index 4;
        "Mod+Shift+5".action = move-column-to-index 5;
        "Mod+Shift+6".action = move-column-to-index 6;
        "Mod+Shift+7".action = move-column-to-index 7;
        "Mod+Shift+8".action = move-column-to-index 8;
        "Mod+Shift+9".action = move-column-to-index 9;

        "Mod+Shift+Slash".action = show-hotkey-overlay;
        "Mod+O".action = toggle-overview;

        "Mod+Page_Down".action = focus-workspace-down;
        "Mod+Page_Up".action = focus-workspace-up;

        "Mod+R".action = switch-preset-column-width;
        "Mod+BracketLeft".action = consume-or-expel-window-left;
        "Mod+BracketRight".action = consume-or-expel-window-right;

        "Mod+V".action = spawn "noctalia" "msg" "panel-toggle" "clipboard";
        "Mod+Shift+R".action = spawn "noctalia" "msg" "panel-toggle" "wallpaper";
        "Mod+Space".action = spawn "noctalia" "msg" "panel-toggle" "launcher";
        "Mod+T".action = toggle-window-floating;
        "Mod+Shift+T".action = switch-focus-between-floating-and-tiling;

        "Mod+W".action = spawn "zen-beta";
        "Mod+E".action = spawn "footclient" "--" "yazi";
        "Mod+Shift+S".action = spawn "noctalia" "msg" "screenshot-region";
        "Print".action = spawn "noctalia" "msg" "screenshot-fullscreen";
        "Mod+Print".action = spawn "niri" "msg" "action" "screenshot-window";
        "Mod+Shift+M".action = spawn "niri-set-max-mode";

        # 硬件媒体键
        "XF86AudioRaiseVolume".action = spawn "noctalia" "msg" "volume-up";
        "XF86AudioLowerVolume".action = spawn "noctalia" "msg" "volume-down";
        "XF86AudioMute".action = spawn "noctalia" "msg" "volume-mute";
        "XF86MonBrightnessUp".action = spawn "noctalia" "msg" "brightness-up";
        "XF86MonBrightnessDown".action = spawn "noctalia" "msg" "brightness-down";
      };
    };
  };
}
