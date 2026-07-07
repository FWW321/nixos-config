# filepath: ~/nixos-config/users/fww/editors/default.nix
# 编辑器入口：聚合 nvim 与 emacs 子模块
{
  imports = [
    ./nvim
    ./emacs
  ];
}
