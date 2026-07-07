# filepath: ~/nixos-config/users/fww/development/lean.nix
# Lean 4 生态（依赖类型函数式编程 + 交互式定理证明）
# - lean4：编译器 + lake 构建工具；LSP 内置于 lean（lean --server），无需独立 LSP 包
# - 编辑器：nvim 经 lean.nvim 连接（见 editors/nvim/plugins.nix）；emacs 暂无 lean4-mode（nixpkgs 未收录）
# - 走纯 nix 包（不用 elan）：声明式、可复现；生态版本对齐由项目 lean-toolchain 文件负责
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    lean4
  ];
}
