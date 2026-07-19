# filepath: ~/nixos-config/pkgs/default.nix
# 自定义打包 overlay 聚合：每个子目录是一个 pkgs.xxx 包
# 通过 flake.nix 的 nixpkgs.overlays 挂载，使用方直接 pkgs.<name> 引用
#
# 新增包：在 pkgs/ 下建 <name>/default.nix，然后在此 final 追加一行
final: _prev: {
  mdbook-svgbob = final.callPackage ./mdbook-svgbob { };
}
