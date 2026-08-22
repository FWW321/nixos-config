# filepath: ~/nixos-config/users/fww/desktop/drawy.nix
# 白板:KDE 无限画布,随手贴想法/草图的原生轻量工具(Excalidraw 的桌面替代)
{ pkgs, ... }:

{
  home.packages = with pkgs; [ drawy ];
}
