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
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "hyprland-set-max-mode" ''
      exec ${script}
    '')
  ];

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false;
    settings = let
      noctalia = "noctalia-shell-env";
    in {
      "$mod" = "SUPER";

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
        bezier = "myBezier, 0.05, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier"
          "windowsOut, 1, 7, default, popin 80%"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };

      dwindle = {
        pseudotile = false;
        preserve_split = true;
      };

      render = {
        direct_scanout = true;
      };

      misc = {
        vrr = 2;
        vfr = true;
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

      bind = [
        "$mod, Return, exec, footclient"
        "$mod, Q, killactive,"
        "$mod SHIFT, E, exit,"

        "$mod, Left, movefocus, l"
        "$mod, Right, movefocus, r"
        "$mod, Up, movefocus, u"
        "$mod, Down, movefocus, d"

        "$mod SHIFT, Left, movewindow, l"
        "$mod SHIFT, Right, movewindow, r"
        "$mod SHIFT, Up, movewindow, u"
        "$mod SHIFT, Down, movewindow, d"

        "$mod, F, togglefloating,"
        "$mod SHIFT, F, fullscreen,"
        "$mod, C, centerwindow,"

        "$mod, 1, workspace, 1"
        "$mod, 2, workspace, 2"
        "$mod, 3, workspace, 3"

        "$mod SHIFT, 1, movetoworkspace, 1"
        "$mod SHIFT, 2, movetoworkspace, 2"
        "$mod SHIFT, 3, movetoworkspace, 3"

        "$mod, Page_Down, workspace, e+1"
        "$mod, Page_Up, workspace, e-1"

        "$mod, BracketLeft, movewindow, l"
        "$mod, BracketRight, movewindow, r"

        "$mod, V, exec, ${noctalia} ipc call plugin:clipper toggle"
        "$mod SHIFT, R, exec, ${noctalia} ipc call plugin:screen-recorder toggle"
        "$mod, Space, exec, ${noctalia} ipc call launcher toggle"
        "$mod, T, togglefloating,"
        "$mod SHIFT, T, focusurgentorlast,"

        "$mod, W, exec, zen-beta"
        "$mod, E, exec, nautilus"
        "$mod SHIFT, S, exec, grim -g \"$(slurp -d)\" - | satty --filename -"
        ", Print, exec, grim - | satty --filename -"
        "$mod, Print, exec, hyprctl -e activewindow > /tmp/hypr_screenshot_window.json && grim -g \"$(hyprctl -j activewindow | jq -r '\"'\"'.at[0],.at[1] \\\" \\\" .size[0]x.size[1] '\"'\"'\" -r)\" - | satty --filename -"

        "$mod SHIFT, M, exec, hyprland-set-max-mode"

        ", XF86AudioRaiseVolume, exec, ${noctalia} ipc call plugin:volume up"
        ", XF86AudioLowerVolume, exec, ${noctalia} ipc call plugin:volume down"
        ", XF86AudioMute, exec, ${noctalia} ipc call plugin:volume toggle-mute"

        ", XF86MonBrightnessUp, exec, ${noctalia} ipc call plugin:brightness up"
        ", XF86MonBrightnessDown, exec, ${noctalia} ipc call plugin:brightness down"

        "$mod SHIFT, Slash, exec, ${noctalia} ipc call plugin:keybind-cheatsheet toggle"
      ];

      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];

      env = [
        "HYPRCURSOR_SIZE,24"
      ];

      exec-once = [
        "foot --server"
        "fcitx5 -d"
        noctalia
      ];
    };

    extraConfig = ''
      windowrule {
          name = steam-games-immediate
          match:class = ^(steam_app_.*\.exe)$
          immediate = yes
      }

      windowrule {
          name = cs2-immediate
          match:class = ^(cs2)$
          immediate = yes
      }

      windowrule {
          name = steam-friends-float
          match:class = ^(steam)$
          match:title = ^(Friends List)$
          float = yes
      }

      windowrule {
          name = spotify-float
          match:title = ^(Spotify Free)$
          float = yes
      }

      windowrule {
          name = steam-workspace
          match:class = ^(steam)$
          workspace = 2 silent
          monitor = DP-1
          center = yes
          maximize = yes
      }

      layerrule {
          name = noXray-blur
          match:namespace = noXray
          blur = yes
          xray = yes
          ignore_alpha = 0
      }
    '';
  };
}
