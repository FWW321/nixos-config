# filepath: ~/nixos-config/modules/system/gaming.nix
# Steam、图形驱动、游戏相关
{ pkgs, ... }:

{
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
}
