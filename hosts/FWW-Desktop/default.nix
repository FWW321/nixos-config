# FWW-Desktop 主机配置 —— 自治:本机硬件文件 + nixos-hardware 模块在此 import,
# flake.nix 对本主机只挂 ./hosts/FWW-Desktop 一个入口
{ pkgs, config, inputs, ... }:

{
  imports = [
    ./hardware.nix
    ./disko.nix
    ./nvidia.nix

    # 硬件模块(主机相关,随主机走)
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-ssd
    inputs.nixos-hardware.nixosModules.common-pc
  ];

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
    wayland.windowManager.hyprland.settings.monitor = {
      output = "DP-1";
      mode = "3840x2160@160";
      position = "0x0";
      scale = "1.5";
    };
  };

  system.stateVersion = "26.05";
}
