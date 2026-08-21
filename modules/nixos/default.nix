# filepath: ~/nixos-config/modules/nixos/default.nix
# 系统域模块聚合入口:flake.nix 只 import 本文件,新增模块在此登记
# (命名对齐社区惯例:Misterio77 starter-configs / wimpysworld 均为 modules/nixos)
{ ... }:

{
  imports = [
    ./audio.nix
    ./boot.nix
    ./containers.nix
    ./desktop.nix
    ./gaming.nix
    ./network.nix
    ./nix.nix
    ./secrets.nix
    ./services.nix
    ./ssh.nix
    ./theme.nix
    ./torrents.nix
    ./users.nix
  ];
}
