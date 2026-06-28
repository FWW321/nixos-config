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
      # fenix nightly 工具链，profile 区别（组件累加）：
      #   minimal: rustc, cargo, rust-std（仅编译必需，日期最新）
      #   default: + clippy, rustfmt, rust-docs, rust-src（日常开发够用，日期次新）← 当前
      #   complete: + miri, rustc-dev, llvm-tools, rustc-codegen-cranelift 等（全组件，日期最旧，多数用不到）
      inputs.fenix.packages.${pkgs.stdenv.hostPlatform.system}.default.toolchain

      # ── JavaScript / TypeScript ──
      nodejs
      bun

      # ── Zig ──
      zig
    ];
}

