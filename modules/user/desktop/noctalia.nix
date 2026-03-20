{ config, pkgs, ... }:

{
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
}
