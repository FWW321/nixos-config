# filepath: ~/nixos-config/hosts/FWW-Desktop/default.nix
{ config, pkgs, ... }:

{
  networking.hostName = "FWW-Desktop";

  nixpkgs.config.allowUnfree = true;

  boot.kernelModules = [ "i2c-dev" ];

  hardware.i2c.enable = true;

  users.groups.i2c = { };
  users.users.fww.extraGroups = [ "i2c" ];

  environment.systemPackages = with pkgs; [
    ddcutil
  ];
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
    WLR_NO_HARDWARE_CURSORS = "1";
    __GL_THREADED_OPTIMIZATION = "1";
  };

  system.stateVersion = "25.11";
}
