# filepath: ~/nixos-config/users/fww/development/c-cpp.nix
# C / C++ 语言生态：gcc（编译器 + cc linker）+ xmake（构建工具）
# - gcc 同时充当 cc linker，被 Rust（openssl-sys 等原生依赖 crate）跨域借用——
#   跨域构建依赖不改变归属：gcc 是 C/C++ 域工具，各域工具都上 PATH，互相可用
# - xmake 内置 Lua 运行时，编辑器侧复用现有 Lua 三件套
#   （treesitter lua + lua_ls + stylua 自动覆盖 xmake.lua）
# - 未来可在此扩展 clang / cmake / make / gdb 等 C/C++ 工具链
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    gcc
    xmake
  ];
}
