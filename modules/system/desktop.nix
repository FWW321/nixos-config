# filepath: ~/nixos-config/modules/system/desktop.nix
# 桌面环境：Hyprland、Niri、greetd、字体、本地化
{ pkgs, inputs, ... }:

{
  # Wayland 合成器
  programs.niri.enable = true;

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  # XDG Portal - 现代桌面集成
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  # GVFS 后端（Nautilus 网络共享 / MTP / 挂载支持）
  services.gvfs.enable = true;

  # 登录管理器
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --asterisks --greeting 'Welcome to NixOS' --cmd 'uwsm start'";
      user = "greeter";
    };
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

  # 字体
  fonts = {
    enableDefaultPackages = true;
    fontDir.enable = true;
    packages = with pkgs; [
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.symbols-only
      noto-fonts-color-emoji
    ];
    fontconfig.defaultFonts = {
      sansSerif = [ "Noto Sans CJK SC" "Noto Sans" ];
      serif = [ "Noto Serif CJK SC" "Noto Serif" ];
      monospace = [ "JetBrainsMono Nerd Font" "Noto Sans Mono CJK SC" ];
      emoji = [ "Noto Color Emoji" ];
    };
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
