# filepath: ~/nixos-config/modules/user/scripts/wallpaper-switch.nix
# 壁纸快速切换脚本：通过命令行快速切换 Noctalia 壁纸
{ config, pkgs, lib, ... }:

let
  wallpaperDir = "${config.home.homeDirectory}/Pictures/Wallpapers";
  
  switchWallpaperScript = pkgs.writeShellScriptBin "wallpaper-next" ''
    # 随机切换到下一张壁纸（配色自动更新）
    ${lib.getExe config.programs.noctalia-shell.package} ipc call wallpaper set-random
    notify-send "壁纸已切换" "配色方案已自动更新" -t 2000
  '';
  
  setWallpaperScript = pkgs.writeShellScriptBin "wallpaper-set" ''
    if [ -z "$1" ]; then
      echo "用法: wallpaper-set <壁纸路径>"
      exit 1
    fi
    
    if [ ! -f "$1" ]; then
      echo "错误: 壁纸文件不存在: $1"
      exit 1
    fi
    
    # 切换到指定壁纸
    ${lib.getExe config.programs.noctalia-shell.package} ipc call wallpaper set "$1"
    notify-send "壁纸已切换" "配色方案已自动更新" -t 2000
  '';
in
{
  home.packages = [
    switchWallpaperScript
    setWallpaperScript
  ];
}
