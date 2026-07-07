# filepath: ~/nixos-config/users/fww/development/js.nix
# JavaScript / TypeScript 生态：nodejs（运行时 + npm）+ bun（现代运行时 / 打包器 / 测试器）
# nodejs 与 bun 同属 JS/TS 域，不拆成 node.nix / bun.nix
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nodejs
    bun
  ];
}
