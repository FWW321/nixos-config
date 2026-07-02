# filepath: ~/nixos-config/users/fww/browsers/default.nix
# 浏览器配置入口：每个浏览器独立一个文件
{
  imports = [
    ./zen.nix
    ./brave.nix
  ];
}
