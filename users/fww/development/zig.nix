# filepath: ~/nixos-config/users/fww/development/zig.nix
# Zig 语言生态：zig（自带 cc 工具链 zig cc，不依赖 default.nix 的 gcc）
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    zig
  ];
}
