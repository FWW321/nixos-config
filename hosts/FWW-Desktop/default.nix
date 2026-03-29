# FWW-Desktop 主机特定配置
{ pkgs, config, ... }:

{
  networking.hostName = "FWW-Desktop";

  boot.kernelModules = [ "i2c-dev" "nct6775" ];
  hardware.i2c.enable = true;
  users.groups.i2c = { };
  users.users.fww.extraGroups = [ "i2c" ];
  environment.systemPackages = [ pkgs.ddcutil ];

  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1ca6", ATTRS{idProduct}=="0529", MODE="0660", GROUP="input", TAG+="uaccess"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="24ae", ATTRS{idProduct}=="4617", MODE="0660", GROUP="input", TAG+="uaccess"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="24ae", ATTRS{idProduct}=="1417", MODE="0660", GROUP="input", TAG+="uaccess"
  '';

  home-manager.users.fww = {
    programs.niri.settings.outputs."DP-1" = {
      mode = { width = 3840; height = 2160; refresh = 160.0; };
      scale = 1.5;
    };
    wayland.windowManager.hyprland.settings.monitor = "DP-1, 3840x2160@160, 0x0, 1.5";
  };

  system.stateVersion = "25.11";
}
