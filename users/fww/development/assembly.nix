# filepath: ~/nixos-config/users/fww/development/assembly.nix
# 汇编语言域：NASM + FASM 汇编器
# - nasm：x86/x86-64 Intel 语法汇编器；产目标文件走链接器（gcc/ld）
# - fasm：x86/x86-64 宏汇编器，自带 ELF/PE 输出，语法独立于 NASM
# - LSP(asm-lsp) 同时管 NASM+FASM（默认启用两者）；见 editors/nvim
# - tree-sitter 仅 nasm grammar（无 fasm）；fasm 高亮走 Neovim 内置 syntax/fasm.vim
# - emacs 无 nasm-ts-mode（nixpkgs 未收录），故 emacs 侧不接汇编高亮
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    nasm
    fasm
  ];
}
