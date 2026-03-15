# filepath: ~/nixos-config/hosts/FWW-Desktop/default.nix
{ config, pkgs, ... }:

{
  networking.hostName = "FWW-Desktop";

  boot.kernelModules = [ "i2c-dev" ];
  hardware.i2c.enable = true;
  users.groups.i2c = { };
  users.users.fww.extraGroups = [ "i2c" ];

  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1ca6", ATTRS{idProduct}=="0529", MODE="0660", GROUP="input", TAG+="uaccess"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="24ae", ATTRS{idProduct}=="4617", MODE="0660", GROUP="input", TAG+="uaccess"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="24ae", ATTRS{idProduct}=="1417", MODE="0660", GROUP="input", TAG+="uaccess"
  '';

  environment.systemPackages = with pkgs; [ ddcutil ];

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  };

  home-manager.users.fww = { config, pkgs, ... }: {
    programs.niri.settings = {
      outputs."DP-1" = {
        mode = {
          width = 3840;
          height = 2160;
          refresh = 160.0;
        };
        scale = 1.5;
      };
    };
  };

  system.stateVersion = "25.11";
}
