# filepath: ~/nixos-config/users/fww/ai/dsh/profiles/default.nix
# profile 聚合:每文件一个 profile(nixvim 每插件/每语言一文件同构)
{ ... }:

{
  imports = [
    ./web.nix
    ./headless.nix
    ./tui.nix
  ];
}
