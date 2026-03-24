# filepath: ~/nixos-config/modules/user/desktop/noctalia.nix
# Noctalia Shell 配置：基于 Quickshell (Qt/QML) 的现代桌面 shell
# 完全由 Stylix 管理配色方案、字体、透明度、壁纸
{ config, pkgs, ... }:

let
  # 壁纸文件（从 Stylix 同步）
  wallpaperDir = "${config.home.homeDirectory}/Pictures/Wallpapers";
in
{
  programs.noctalia-shell = {
    enable = true;

    settings = {
      # 通用设置
      general.language = "zh-CN";

      # UI 设置（透明度由 Stylix 管理）
      ui = {
        translucentWidgets = true;
        enableAnimations = true;
        animationDuration = 200;
      };

      # 壁纸管理（使用 Stylix 的壁纸）
      wallpaper = {
        enabled = true;
        directory = wallpaperDir;
        fillMode = "crop"; # crop, fit, stretch, tile
        # 自动轮换（禁用，使用手动控制）
        automationEnabled = false;
        wallpaperChangeMode = "random";
        changeInterval = 1800; # 30 分钟（未启用）
        # 过渡动画
        transitionType = [ "fade" "crossFade" ];
        transitionDuration = 500;
      };

      # 配色方案：完全由 Stylix 统一管理
      # Stylix 会自动设置 programs.noctalia-shell.colors
      # 不在此处覆盖任何配色，保证全局配色统一

      # 网络设置
      network = {
        wifiEnabled = true;
        showWifiStrength = true;
        bluetoothEnabled = true;
        bluetoothAutoConnect = true;
      };

      # Dock 设置
      dock = {
        size = 1.5;
        groupApps = true;
        showRunningIndicator = true;
      };

      # 控制中心
      controlCenter.cards = [
        { enabled = true; id = "profile-card"; }
        { enabled = true; id = "shortcuts-card"; }
        { enabled = true; id = "network-card"; } # 内置 WiFi/蓝牙控制
        { enabled = true; id = "audio-card"; }
        { enabled = true; id = "brightness-card"; }
        { enabled = true; id = "weather-card"; }
        { enabled = true; id = "media-sysmon-card"; }
      ];

      # 应用启动器
      appLauncher = {
        enableClipboardHistory = true;
        terminalCommand = "footclient -e";
        showRecentApps = true;
        maxRecentApps = 5;
      };

      # 空闲/锁屏/休眠
      idle = {
        enabled = true;
        screenOffTimeout = 600; # 10 分钟关闭屏幕
        lockTimeout = 900; # 15 分钟锁屏
        suspendTimeout = 1200; # 20 分钟挂起
        # 3 小时后休眠（配合系统休眠设置）
        customCommands = builtins.toJSON [
          {
            timeout = 10800;
            command = "systemctl hibernate";
          }
        ];
      };

      # 位置/天气
      location = {
        name = "Chongqing";
        analogClockInCalendar = true;
      };

      # 系统监控
      systemMonitor = {
        enableDgpuMonitoring = true; # NVIDIA GPU 监控
        showCpuUsage = true;
        showMemoryUsage = true;
        showNetworkSpeed = true;
      };

      # 亮度控制
      brightness = {
        enableDdcSupport = true; # DDC/CI 支持外接显示器亮度调节
      };

      # 顶栏配置
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
          # 使用内置 Network widget
          {
            id = "Network";
            showWifiName = false; # 简洁显示
          }
          # 内置蓝牙 widget
          {
            id = "Bluetooth";
            showConnectedDevice = true;
          }
          { id = "plugin:assistant-panel"; }
          { id = "Volume"; }
          { id = "Brightness"; }
          { id = "ControlCenter"; }
        ];
      };
    };

    # 插件配置
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
        # 移除 network-indicator 插件，使用内置 Network widget
      };
      version = 1;
    };

    # 插件设置
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

  # 下载壁纸到本地文件夹（从 Stylix 获取）
  # Stylix 已经通过 ~/.cache/noctalia/wallpapers.json 设置默认壁纸
  # 这里额外将壁纸复制到 Pictures/Wallpapers 供手动管理
  home.activation.copyWallpaper = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${wallpaperDir}
    # 从 Stylix 复制壁纸
    if [ -f ${config.stylix.image} ]; then
      cp -f ${config.stylix.image} ${wallpaperDir}/stylix-wallpaper.png
    fi
  '';
}
