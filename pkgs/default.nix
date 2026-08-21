# filepath: ~/nixos-config/pkgs/default.nix
# 自定义打包 overlay 聚合：每个子目录是一个 pkgs.xxx 包
# 通过 flake.nix 的 nixpkgs.overlays 挂载，使用方直接 pkgs.<name> 引用
#
# 新增包：在 pkgs/ 下建 <name>/default.nix，然后在此 final 追加一行
final: _prev: {
  mdbook-svgbob = final.callPackage ./mdbook-svgbob { };
  opencode2 = final.callPackage ./opencode2 { };
  pdf-inspector = final.callPackage ./pdf-inspector { };
  mmx-cli = final.callPackage ./mmx-cli { };
  # koharu 已迁独立仓库 koharu-nix(flake input overlay 提供 pkgs.koharu,
  # 同 nixdsh/zcode-nix;HM 模块见 users/fww/ai/koharu.nix)
  # dsh/dshPlugins 已迁独立仓库 nixdsh(flake input overlay 提供 pkgs.dsh)
  # unified ChatGPT/Codex 桌面端(Linux):抄自 PR #551713 待合并,见 pkgs/chatgpt/package.nix 头注释
  # codexPackage 与 home-manager programs.codex 复用 nixpkgs codex 同一二进制
  chatgpt = final.callPackage ./chatgpt { codexPackage = final.codex; };
  # zcode 已迁独立仓库 zcode-nix(flake input overlay 提供 pkgs.zcode,同 nixdsh)
}
