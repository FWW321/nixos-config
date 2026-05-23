{ config, pkgs, lib, ... }:

let
  script = pkgs.writeShellScript "hyprland-set-max-mode" ''
    set -euo pipefail
    JQ=${lib.getExe' pkgs.jq "jq"}

    hyprctl -j monitors | $JQ -r '
      .[] |
      .name as $name |
      [.availableModes[] | capture("^(?<w>[0-9]+)x(?<h>[0-9]+)@(?<r>[0-9.]+)") | {w: (.w|tonumber), h: (.h|tonumber), r: (.r|tonumber)}] |
      max_by((.w * .h) * 1000000 + .r) |
      if .w >= 3840 then
        "hyprctl keyword monitor \($name),\(.w)x\(.h)@\(.r*1000|round),0x0,1.5"
      else
        "hyprctl keyword monitor \($name),\(.w)x\(.h)@\(.r*1000|round),0x0,1"
      end
    ' | while read -r cmd; do
      eval "$cmd"
    done
  '';
  noctalia = "noctalia-shell-env";
in
{
  home.pointerCursor.hyprcursor.enable = true;

  home.packages = [
    (pkgs.writeShellScriptBin "hyprland-set-max-mode" ''
      exec ${script}
    '')
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;
    settings.config = {
      general = {
        gaps_in = 12;
        gaps_out = 12;
        border_size = 3;
        layout = "dwindle";
        allow_tearing = true;
        resize_on_border = true;
      };

      decoration = {
        rounding = 8;
        blur = {
          enabled = true;
          size = 4;
          passes = 2;
          ignore_opacity = true;
          xray = true;
        };
        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
        };
      };

      animations = {
        enabled = true;
      };

      dwindle = {
        preserve_split = true;
      };

      render = {
        direct_scanout = true;
      };

      misc = {
        vrr = 2;
      };

      xwayland = {
        force_zero_scaling = true;
      };

      input = {
        kb_layout = "us";
        follow_mouse = 1;
        accel_profile = "flat";
        touchpad = {
          natural_scroll = true;
        };
        sensitivity = 0;
      };
    };

    extraConfig = ''
      local mainMod = "SUPER"

      hl.curve("myBezier", { type = "bezier", points = {{0.05, 0.9}, {0.1, 1.05}} })
      hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })
      hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
      hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
      hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
      hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
      hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })

      hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("footclient"))
      hl.bind(mainMod .. " + Q", hl.dsp.window.close())
      hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exit())

      hl.bind(mainMod .. " + Left", hl.dsp.focus({ direction = "left" }))
      hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }))
      hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "up" }))
      hl.bind(mainMod .. " + Down", hl.dsp.focus({ direction = "down" }))

      hl.bind(mainMod .. " + SHIFT + Left", hl.dsp.window.move({ direction = "left" }))
      hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.move({ direction = "right" }))
      hl.bind(mainMod .. " + SHIFT + Up", hl.dsp.window.move({ direction = "up" }))
      hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.window.move({ direction = "down" }))

      hl.bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }))
      hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen())
      hl.bind(mainMod .. " + C", hl.dsp.window.center())

      for i = 1, 9 do
        hl.bind(mainMod .. " + " .. i, hl.dsp.focus({ workspace = tostring(i) }))
        hl.bind(mainMod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
      end

      hl.bind(mainMod .. " + Page_Down", hl.dsp.focus({ workspace = "e+1" }))
      hl.bind(mainMod .. " + Page_Up", hl.dsp.focus({ workspace = "e-1" }))

      hl.bind(mainMod .. " + BracketLeft", hl.dsp.window.move({ direction = "left" }))
      hl.bind(mainMod .. " + BracketRight", hl.dsp.window.move({ direction = "right" }))

      hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("${noctalia} ipc call plugin:clipper toggle"))
      hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("${noctalia} ipc call plugin:screen-recorder toggle"))
      hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd("${noctalia} ipc call launcher toggle"))
      hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }))
      hl.bind(mainMod .. " + SHIFT + T", hl.dsp.focus({ urgent_or_last = true }))

      hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("zen-beta"))
      hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("nautilus"))
      hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd([[grim -g "$(slurp -d)" - | satty --filename -]]))

      hl.bind("Print", hl.dsp.exec_cmd("grim - | satty --filename -"))
      hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd([[hyprctl -e activewindow > /tmp/hypr_screenshot_window.json && grim -g "$(hyprctl -j activewindow | jq -r '.at[0],.at[1] " " .size[0]x.size[1]' -r)" - | satty --filename -]]))

      hl.bind(mainMod .. " + SHIFT + M", hl.dsp.exec_cmd("hyprland-set-max-mode"))

      hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("${noctalia} ipc call plugin:volume up"))
      hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("${noctalia} ipc call plugin:volume down"))
      hl.bind("XF86AudioMute", hl.dsp.exec_cmd("${noctalia} ipc call plugin:volume toggle-mute"))
      hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("${noctalia} ipc call plugin:brightness up"))
      hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("${noctalia} ipc call plugin:brightness down"))

      hl.bind(mainMod .. " + SHIFT + Slash", hl.dsp.exec_cmd("${noctalia} ipc call plugin:keybind-cheatsheet toggle"))

      hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
      hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

      hl.on("hyprland.start", function()
        hl.exec_cmd("foot --server")
        hl.exec_cmd("fcitx5 -d")
        hl.exec_cmd("${noctalia}")
      end)

      hl.window_rule({
        name = "steam-games-immediate",
        match = { class = [[^(steam_app_.*\.exe)$]] },
        immediate = true,
      })

      hl.window_rule({
        name = "cs2-immediate",
        match = { class = "^(cs2)$" },
        immediate = true,
      })

      hl.window_rule({
        name = "steam-friends-float",
        match = { class = "^(steam)$", title = "^(Friends List)$" },
        float = true,
      })

      hl.window_rule({
        name = "spotify-float",
        match = { title = "^(Spotify Free)$" },
        float = true,
      })

      hl.window_rule({
        name = "steam-workspace",
        match = { class = "^(steam)$" },
        workspace = "2 silent",
        monitor = "DP-1",
        center = true,
        maximize = true,
      })

      hl.layer_rule({
        name = "noXray-blur",
        match = { namespace = "noXray" },
        blur = true,
        xray = true,
        ignore_alpha = 0,
      })
    '';
  };
}
