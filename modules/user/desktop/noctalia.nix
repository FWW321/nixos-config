# filepath: ~/nixos-config/modules/user/desktop/noctalia.nix
# Noctalia Shell v5 配置：基于 C++/OpenGL ES 的轻量 Wayland 桌面 shell
# 配色方案由 Stylix 统一管理
{ config, pkgs, ... }:

let
  wallpaperDir = "${config.home.homeDirectory}/Pictures/Wallpapers";
  wallpaperSrc = ../../../wallpapers;
  avatarDir = "${config.home.homeDirectory}/Pictures/Avatars";
  avatarSrc = ../../../Avatars;
in
{
  programs.noctalia = {
    enable = true;

    settings = {
      # Shell 通用设置
      shell = {
        lang = "zh-Hans";
        font_family = "JetBrainsMono Nerd Font";
        polkit_agent = true;
        avatar_path = "${config.home.homeDirectory}/Pictures/Avatars/2131F1CB68E2BAA3698C8F87BB484FB8.jpg";
        clipboard_enabled = true;
        clipboard_history_max_entries = 100;
        animation.enabled = true;
        # 屏幕物理圆角补偿
        screen_corners = {
          enabled = true;
          size = 32;
        };
        panel = {
          transparency_mode = "glass";
          borders = true;
          shadow = true;
        };
        # 截图：管道传给 satty 标注
        screenshot = {
          save_to_file = false;
          copy_to_clipboard = false;
          pipe_to_command = true;
          pipe_command = "satty -f -";
        };
      };

      # 壁纸管理
      wallpaper = {
        enabled = true;
        directory = wallpaperDir;
        fill_mode = "crop";
        transition = [
          "fade"
          "wipe"
        ];
        transition_duration = 500;
        automation = {
          enabled = false;
          order = "random";
        };
      };

      # 背景层：niri overview 中显示模糊壁纸
      backdrop = {
        enabled = true;
        blur_intensity = 0.5;
        tint_intensity = 0.3;
      };

      # 配色方案：Stylix 尚未适配 noctalia v5（缺少 target），
      # 所以 Noctalia 暂时自己管理配色，从壁纸图片提取（M3 算法）
      # 其余应用配色仍由 Stylix 统一管理
      theme = {
        mode = "dark";
        source = "wallpaper";
        wallpaper_scheme = "m3-content";
        templates = {
          enable_community_templates = true;
          community_ids = [ "steam" ];
        };
      };

      # Dock
      dock = {
        enabled = true;
        position = "bottom";
        icon_size = 48;
        show_dots = true;
        show_running = true;
        magnification = true;
      };

      # 控制中心快捷按钮
      control_center = {
        shortcuts = [
          { type = "wifi"; }
          { type = "bluetooth"; }
          { type = "nightlight"; }
          { type = "notification"; }
          { type = "wallpaper"; }
          { type = "screen_recorder"; }
          { type = "session"; }
        ];
      };

      # 空闲/锁屏
      idle = {
        behavior = {
          lock = {
            timeout = 900;
            enabled = true;
            command = "noctalia:session lock";
          };
          screen-off = {
            timeout = 600;
            enabled = true;
            command = "noctalia:dpms-off";
            resume_command = "noctalia:dpms-on";
          };
        };
      };

      # 位置/天气
      location = {
        address = "Chongqing";
      };

      # 天气
      weather = {
        enabled = true;
        refresh_minutes = 30;
        unit = "celsius";
      };

      # 系统监控
      system.monitor = {
        enabled = true;
        cpu_poll_seconds = 2.0;
        gpu_poll_seconds = 5.0;
        memory_poll_seconds = 2.0;
        network_poll_seconds = 3.0;
      };

      # 亮度控制
      brightness = {
        enable_ddcutil = true;
      };

      # 护眼模式：日落后自动降低色温（基于 location 自动计算日落时间）
      nightlight = {
        enabled = true;
        temperature_day = 6500;
        temperature_night = 4000;
      };

      # 通知
      notification = {
        enable_daemon = true;
        show_app_name = true;
        show_actions = true;
      };

      # 锁屏
      lockscreen = {
        enabled = true;
      };

      # 顶栏配置
      bar.main = {
        position = "top";
        thickness = 34;
        background_opacity = 0.85;
        radius = 12;
        margin_ends = 15;
        margin_edge = 10;
        capsule = true;
        start = [
          "launcher"
          "clock"
          "active_window"
        ];
        center = [
          "workspaces"
        ];
        end = [
          "tray"
          "notifications"
          "network"
          "bluetooth"
          "volume"
          "brightness"
          "control-center"
        ];
      };

      # Clock widget 格式
      widget.clock = {
        format = "{:%H:%M}";
      };

      # 工作区：隐藏空工作区，只显示有窗口的
      widget.workspaces = {
        hide_when_empty = true;
      };

      # 插件
      plugins = {
        enabled = [
          "noctalia/screen_recorder"
        ];
      };

      # TODO: Noctalia v5 暂无 IPC 命令触发 greeter 同步，
      # 目前只能手动 Settings → Shell → Security → Noctalia Greeter → Sync Now
      # 等 v5 添加 greeter-sync IPC 后，通过 hooks.wallpaper_changed 自动同步
    };
  };

  # 将仓库壁纸同步到本地壁纸目录
  home.activation.copyAssets = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p ${wallpaperDir} ${avatarDir}
    cp -rf ${wallpaperSrc}/. ${wallpaperDir}/
    cp -rf ${avatarSrc}/. ${avatarDir}/
  '';
}
