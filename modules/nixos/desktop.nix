# filepath: ~/nixos-config/modules/nixos/desktop.nix
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

  # OBS Studio:录制/推流(FineCam 4K 经 UVC 即插即用,添加"视频采集设备"即可)
  programs.obs-studio = {
    enable = true;
    # 虚拟摄像头(v4l2loopback):OBS 合成画面输出成 /dev/video 设备,
    # 会议软件里选"OBS Virtual Camera"即可吃到 OBS 处理后的画面
    enableVirtualCamera = true;
    plugins = [
      # nixpkgs 打包遗漏修复(零文件载体包):obs-nvenc-test 探测助手的
      # RUNPATH 缺 /run/opengl-driver/lib → dlopen 不到 libnvidia-encode →
      # OBS 里 NVENC 编码器全消失(日志:"Test process failed: nvenc_lib")。
      # 经 wrapOBS 的 obsWrapperArguments 扩展点给 OBS 注入 LD_LIBRARY_PATH,
      # 子进程继承后即可加载(实测 nvenc_supported=true,Ada/AV1 8K)。
      # 注意:助手路径由 /proc/self/exe 解析回原始包,patch 副本无效,
      # 环境继承是唯一样本外修复路径。上游修复后删除本项。
      (pkgs.runCommand "obs-nvenc-driver-ldpath" {
        passthru.obsWrapperArguments = [
          "--prefix LD_LIBRARY_PATH : /run/opengl-driver/lib"
        ];
      } "mkdir -p $out")
    ];
  };

  # 登录管理器：Noctalia Greeter（配合 greetd）
  services.greetd = {
    enable = true;
    settings.default_session = {
      user = "greeter";
    };
  };

  # 2026-09-25:上游模块改名 programs.noctalia-greeter → 此处(eval 警告溯源)
  services.displayManager.noctalia-greeter = {
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

  # 环境变量(EDITOR 由 nixvim defaultEditor 在用户级声明,系统级不重复)
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];

  # 本地化
  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "zh_CN.UTF-8";
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "zh_CN.UTF-8/UTF-8"
  ];
}
