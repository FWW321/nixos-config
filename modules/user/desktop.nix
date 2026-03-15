{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  imports = [
    inputs.niri.homeModules.niri
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia-shell = {
    enable = true;
    settings = {
      general.language = "zh-CN";
      ui.translucentWidgets = true;
      dock = {
        size = 1.5;
        groupApps = true;
      };
      controlCenter.cards = [
        { enabled = true; id = "profile-card"; }
        { enabled = true; id = "shortcuts-card"; }
        { enabled = false; id = "audio-card"; }
        { enabled = false; id = "brightness-card"; }
        { enabled = true; id = "weather-card"; }
        { enabled = true; id = "media-sysmon-card"; }
      ];
      appLauncher = {
        enableClipboardHistory = true;
        terminalCommand = "footclient -e";
      };
      idle = {
        enabled = true;
        screenOffTimeout = 600;
        lockTimeout = 900;
        suspendTimeout = 1200;
      };
      location = {
        name = "Chongqing";
        analogClockInCalendar = true;
      };
      systemMonitor.enableDgpuMonitoring = true;
      brightness.enableDdcSupport = true;
    };
    plugins = {
      sources = [
        {
          enabled = true;
          name = "Noctalia Plugins";
          url = "https://github.com/noctalia-dev/noctalia-plugins";
        }
      ];
      states = {
        polkit-agent = {
          enabled = true;
          sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
        };
        clipper = {
          enabled = true;
          sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
        };
        screen-recorder = {
          enabled = true;
          sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
        };
      };
      version = 1;
    };
  };

  home.packages = with pkgs; [
    gpu-screen-recorder
    grim
    slurp
    wl-clipboard
    cliphist
    (let
      script = writeShellScript "niri-set-max-mode" ''
        set -euo pipefail
        JQ=${lib.getExe pkgs.jq}

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
    in writeShellScriptBin "niri-set-max-mode" ''
      exec ${script}
    '')
    (let
      script = writeShellScript "gamescope-auto" ''
        set -euo pipefail
        JQ=${lib.getExe pkgs.jq}

        output=$(niri msg --json outputs | $JQ -r 'to_entries[0]')
        width=$(echo "$output" | $JQ -r '.value.modes[.value.current_mode].width')
        height=$(echo "$output" | $JQ -r '.value.modes[.value.current_mode].height')
        refresh=$(echo "$output" | $JQ -r '.value.modes[.value.current_mode].refresh_rate / 1000 | floor')

        exec gamescope --expose-wayland -W "$width" -H "$height" -r "$refresh" -f -S stretch --force-grab-cursor -- "$@"
      '';
    in writeShellScriptBin "gamescope-auto" ''
      exec ${script} "$@"
    '')
  ];

  programs.satty = {
    enable = true;
    settings = {
      general = {
        fullscreen = true;
        early-exit = true;
        initial-tool = "arrow";
        copy-command = "wl-copy";
      };
    };
  };

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
          matches = [ { app-id = ".*"; } ];
          # 当在 Niri 里给窗口加上圆角（Border Radius）和边框（Focus Ring / Border）时
          # 为了不让边框锯齿化，并且保证性能，Niri 的渲染器选择了一种最简单粗暴的方法
          # 直接在你的窗口正下方，垫一块跟窗口一样大、带颜色的"纯色实心铁板"
          # 如果窗口是不透明的,只能看到这块铁板露出来的边缘，这就是边框
          # 如果你的窗口是半透明的,原本垫在底下的"屎黄色实心铁板"就会像滤镜一样把整个窗口的背景色给污染了
          # draw-border-with-background = false会告诉把底下的实心铁板掏空，只画一个空心的线框
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

        "Mod+V".action = spawn "noctalia-shell" "ipc" "call" "plugin:clipper" "toggle";
        "Mod+Shift+R".action = spawn "noctalia-shell" "ipc" "call" "plugin:screen-recorder" "toggle";
        "Mod+Space".action = toggle-window-floating;
        "Mod+Shift+Space".action = switch-focus-between-floating-and-tiling;

        "Mod+D".action = spawn "noctalia-shell" "ipc" "call" "launcher" "toggle";
        "Mod+W".action = spawn "zen";
        "Mod+Shift+S".action = spawn "bash" "-c" "grim -g \"$(slurp -d)\" - | satty --filename -";
        "Print".action = spawn "bash" "-c" "grim - | satty --filename -";
        "Mod+Print".action = spawn "niri" "msg" "action" "screenshot-window";
        "Mod+Shift+M".action = spawn "niri-set-max-mode";
      };
    };
  };

  xresources.properties = {
    "Xft.dpi" = 144;
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      qt6Packages.fcitx5-chinese-addons
      fcitx5-gtk
      fcitx5-pinyin-zhwiki
    ];
    fcitx5.settings = {
      globalOptions = {
        "Hotkey/TriggerKeys"."0" = "Shift_L";
      };
      inputMethod = {
        "Groups/0" = {
          Name = "Default";
          "Default Layout" = "us";
          DefaultIM = "keyboard-us";
        };
        "Groups/0/Items/0".Name = "keyboard-us";
        "Groups/0/Items/1".Name = "pinyin";
        GroupOrder."0" = "Default";
      };
    };
  };
}
