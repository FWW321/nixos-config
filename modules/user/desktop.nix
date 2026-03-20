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
        {
          enabled = true;
          id = "profile-card";
        }
        {
          enabled = true;
          id = "shortcuts-card";
        }
        {
          enabled = false;
          id = "audio-card";
        }
        {
          enabled = false;
          id = "brightness-card";
        }
        {
          enabled = true;
          id = "weather-card";
        }
        {
          enabled = true;
          id = "media-sysmon-card";
        }
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
        customCommands = builtins.toJSON [
          {
            timeout = 10800;
            command = "systemctl hibernate";
          }
        ];
      };
      location = {
        name = "Chongqing";
        analogClockInCalendar = true;
      };
      systemMonitor.enableDgpuMonitoring = true;
      brightness.enableDdcSupport = true;
      bar.widgets = {
        left = [
          { id = "Launcher"; }
          {
            id = "Clock";
            formatHorizontal = "HH:mm";
            useMonospacedFont = true;
          }
          { id = "SystemMonitor"; }
          { id = "ActiveWindow"; }
        ];
        center = [
          {
            id = "Workspace";
            hideUnoccupied = false;
          }
        ];
        right = [
          { id = "Tray"; }
          { id = "NotificationHistory"; }
          { id = "plugin:privacy-indicator"; }
          { id = "plugin:network-indicator"; }
          { id = "plugin:assistant-panel"; }
          { id = "Volume"; }
          { id = "Brightness"; }
          { id = "ControlCenter"; }
        ];
      };
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
        keybind-cheatsheet = {
          enabled = true;
          sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
        };
        file-search = {
          enabled = true;
          sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
        };
        assistant-panel = {
          enabled = true;
          sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
        };
        privacy-indicator = {
          enabled = true;
          sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
        };
        network-indicator = {
          enabled = true;
          sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
        };
      };
      version = 1;
    };
    pluginSettings = {
      assistant-panel = {
        ai = {
          provider = "openai_compatible";
          models.openai_compatible = "glm-5";
          openaiBaseUrl = "https://open.bigmodel.cn/api/coding/paas/v4/chat/completions";
          temperature = 0.7;
          systemPrompt = "You are a helpful assistant. Be concise and helpful. Respond in the same language as the user.";
        };
        translator = {
          backend = "google";
          targetLanguage = "zh";
          realTimeTranslation = true;
        };
        panelWidth = 600;
        panelDetached = true;
        panelPosition = "right";
      };
    };
  };

  home.packages = with pkgs; [
    gpu-screen-recorder
    grim
    slurp
    wl-clipboard
    cliphist
    (
      let
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
      in
      writeShellScriptBin "niri-set-max-mode" ''
        exec ${script}
      ''
    )
    (writeShellScriptBin "noctalia-shell-env" ''
      export NOCTALIA_AP_OPENAI_COMPATIBLE_API_KEY=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.zhipu_api_key.path})
      exec ${pkgs.noctalia-shell}/bin/noctalia-shell "$@"
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
        { command = [ "noctalia-shell-env" ]; }
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
        "Mod+Space".action = spawn "noctalia-shell" "ipc" "call" "launcher" "toggle";
        "Mod+T".action = toggle-window-floating;
        "Mod+Shift+T".action = switch-focus-between-floating-and-tiling;

        "Mod+W".action = spawn "zen-beta";
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
      addons = {
        cloudpinyin = {
          globalSection = {
            CloudPinyinEnabled = false;
          };
        };
      };
    };
  };

  systemd.user.services.fcitx5-daemon = {
    Service = {
      Restart = "always";
      RestartSec = "3";
    };
  };

  home.sessionVariables = {
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "ibus";
  };

  sops.secrets.zhipu_api_key = { };
  sops.secrets.github_token = { };

  home.activation.writeNixConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    TOKEN=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.github_token.path})
    ${pkgs.coreutils}/bin/mkdir -p ~/.config/nix
    ${pkgs.coreutils}/bin/cat > ~/.config/nix/nix.conf << EOF
    access-tokens = github.com=$TOKEN
    EOF
  '';
}
