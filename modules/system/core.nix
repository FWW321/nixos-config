# filepath: ~/nixos-config/modules/system/core.nix
{ config, pkgs, inputs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    inputs.nix-cachyos-kernel.overlays.default
    inputs.nix-gaming-edge.overlays.proton-cachyos
  ];

  services.openssh = {
    enable = true;
    startWhenNeeded = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
    hostKeys = [{
      type = "ed25519";
      path = "/etc/ssh/ssh_host_ed25519_key";
    }];
  };

  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [ lm_sensors ];

  boot.initrd.systemd.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 20;

  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-lto-x86_64-v3;

  services.scx = {
    enable = true;
    scheduler = "scx_bpfland";
  };

  # power-profiles-daemon 电源管理
  # 使用方式:
  #   powerprofilesctl get              # 查看当前配置
  #   powerprofilesctl set performance  # 性能模式
  #   powerprofilesctl set balanced     # 平衡模式
  #   powerprofilesctl set power-saver  # 省电模式
  services.power-profiles-daemon.enable = true;
  services.irqbalance.enable = true;

  security.sudo.extraConfig = "Defaults lecture = never";
  security.polkit.enable = true;

  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "zh_CN.UTF-8/UTF-8" ];

  networking.firewall.enable = true;

  environment.pathsToLink =
    [ "/share/applications" "/share/xdg-desktop-portal" ];

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    EDITOR = "nvim";
  };

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
      wqy_microhei
    ];
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    trusted-users = [ "root" "@wheel" ];
    max-jobs = "auto";
    substituters = [
      "https://attic.xuyh0120.win/lantian"
      "https://niri.cachix.org"
      "https://hyprland.cachix.org"
      "https://nix-cache.tokidoki.dev/tokidoki"
    ];
    trusted-public-keys = [
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "tokidoki:MD4VWt3kK8Fmz3jkiGoNRJIW31/QAm7l1Dcgz2Xa4hk="
    ];
  };
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraCompatPackages = [ pkgs.proton-cachyos-x86_64-v3 ];
  };

  users.groups = {
    shared = { };
    sops-keys = { };
  };
  users.users.fww = {
    isNormalUser = true;
    extraGroups =
      [ "wheel" "networkmanager" "video" "audio" "input" "shared" "sops-keys" ];
    hashedPasswordFile = config.sops.secrets.user_password.path;
    shell = pkgs.nushell;
  };

  systemd.tmpfiles.rules = [
    "z /etc/ssh/ssh_host_ed25519_key 0640 root sops-keys - -"
    "d /data/public 2775 root shared - -"
    "d /data/public/games 2775 root shared - -"
    "d /data/public/games/steam 2775 root shared - -"
    "d /data/public/music 2775 root shared - -"
    "d /data/public/videos 2775 root shared - -"
    "d /data/public/pictures 2775 root shared - -"
    "d /data/private 0755 root root - -"
    "d /data/private/fww 0700 fww users - -"
  ];

  boot.kernel.sysfs.kernel.mm.transparent_hugepage.defrag = "defer+madvise";

  programs.niri.enable = true;

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage =
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ ];
  };

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command =
          "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --asterisks --greeting 'Welcome to NixOS' --cmd uwsm start";
        user = "greeter";
      };
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

  boot.loader.timeout = 1;

  boot.consoleLogLevel = 0;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "udev.log_priority=3"
    "rd.systemd.show_status=false"
    "transparent_hugepage=always"
  ];

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 5;
  };

  services.btrfs.autoScrub.enable = true;
}
