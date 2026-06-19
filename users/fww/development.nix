# filepath: ~/nixos-config/users/fww/development.nix
# 开发环境：语言工具链集中安装
# LSP 由 opencode 自动下载、nvim 自行安装，此处不再放 LSP
{
  pkgs,
  inputs,
  ...
}:

{
  home.packages =
    with pkgs;
    [
      # ── Rust ──
      inputs.fenix.packages.${pkgs.stdenv.hostPlatform.system}.complete.toolchain

      # ── JavaScript / TypeScript ──
      nodejs
      bun

      # ── Zig ──
      zig
    ];
}

