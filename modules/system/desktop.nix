# filepath: ~/nixos-config/modules/system/desktop.nix
# 桌面环境：Hyprland、Niri、greetd、字体、本地化
{ pkgs, ... }:

{
  # Wayland 合成器
  programs.niri.enable = true;

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  # XDG Portal - 现代桌面集成
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  # 登录管理器：Noctalia Greeter（配合 greetd）
  services.greetd = {
    enable = true;
    settings.default_session = {
      user = "greeter";
    };
  };

  programs.noctalia-greeter = {
    enable = true;
    greeter-args = "--session niri";
  };

  systemd.services.greetd.serviceConfig = {
    StandardInput = "tty";
    StandardOutput = "tty";
    StandardError = "journal";
    TTYReset = true;
    TTYVHangup = true;
    TTYVTDisallocate = true;
  };

  systemd.user.services.dbus-update-env = {
    description = "Update D-Bus activation environment on session start";
    wantedBy = [ "graphical-session.target" ];
    after = [ "dbus-broker.service" ];
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd \
        DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP XDG_DATA_DIRS
    '';
  };

  systemd.user.paths.dbus-broker = {
    wantedBy = [ "default.target" ];
    pathConfig.PathChanged = [
      "%h/.nix-profile/share/dbus-1/services"
      "/etc/profiles/per-user/%U/share/dbus-1/services"
      "/run/current-system/sw/share/dbus-1/services"
    ];
  };

  # 环境变量
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    EDITOR = "nvim";
  };

  environment.pathsToLink = [ "/share/applications" "/share/xdg-desktop-portal" ];

  # 本地化
  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "zh_CN.UTF-8";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "zh_CN.UTF-8/UTF-8" ];
}
