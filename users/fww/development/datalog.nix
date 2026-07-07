# filepath: ~/nixos-config/users/fww/development/datalog.nix
# Datalog / 逻辑编程范式：Soufflé 编译器
# - souffle：.dl 规约 → 综合parallel C++ → 原生二进制；纯批处理编译器
# - 无 LSP、nixpkgs 无 tree-sitter grammar → 编辑器侧无集成（.dl 文件按纯文本处理）
# - 命名为 datalog.nix（范式域）而非 souffle.nix（单一工具）：预留未来加其它 Datalog 实现（Crepe/Ascent）的语义位
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    souffle
  ];
}
