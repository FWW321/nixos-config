# filepath: ~/nixos-config/users/fww/ai/dsh/profiles/default.nix
# profile 聚合:每文件一个交互面(nixvim 每插件/每语言一文件同构)
#
# 不变量(设计依据见 nixdsh README 语义模型 §4):profile 数 = 交互面数,
# 与插件数无关 —— 交互面 bundle 两两互斥(duplicate entry / TTY 致死,
# 均实测),功能插件一律走 programs.dsh.plugins.<name>(profiles 缺省
# 全分发),不新建 profile
{ ... }:

{
  imports = [
    ./web.nix
    ./headless.nix
    ./tui.nix
  ];
}
