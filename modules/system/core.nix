# filepath: ~/nixos-config/modules/system/core.nix
{ config, pkgs, inputs, ... }:

{
  nixpkgs.config.allowUnfree = true;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
    hostKeys = [{
      type = "ed25519";
      path = "/etc/ssh/ssh_host_ed25519_key";
    }];
  };

  systemd.services.sshd = {
    wantedBy = [ ];
    enable = false;
  };

  programs.nix-ld.enable = true;
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 20;
  security.sudo.extraConfig = "Defaults lecture = never";
  security.polkit.enable = true;

  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [ "en_US.UTF-8/UTF-8" "zh_CN.UTF-8/UTF-8" ];

  environment.pathsToLink =
    [ "/share/applications" "/share/xdg-desktop-portal" ];

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
      wqy_zenhei
    ];
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    substituters = [ "https://niri.cachix.org" ];
    trusted-public-keys =
      [ "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964=" ];
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
  programs.gamemode.enable = true;
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
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

  programs.niri.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command =
          "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --asterisks --greeting 'Welcome to NixOS' --cmd niri-session";
        user = "greeter";
      };
    };
  };

  systemd.services.greetd.serviceConfig = {
    Type = "idle";
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
  boot.kernelParams =
    [ "quiet" "udev.log_priority=3" "rd.systemd.show_status=false" ];
}
