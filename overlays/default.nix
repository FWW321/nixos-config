# filepath: ~/nixos-config/overlays/default.nix
# 全部 overlay 的唯一组装点(此前散落 flake.nix inline + boot.nix 两处)。
# 消费:flake.nix 的 nixpkgs.overlays = [ self.overlays.default ]。
#
# fold 成单个 overlay 函数,消费侧零嵌套列表。
{ inputs }:
let
  lib = inputs.nixpkgs.lib;
in
lib.foldl' lib.composeExtensions (_: _: { }) [
  # Rust 工具链(rust-bin → pkgs.rust-bin),声明式替代 rustup
  inputs.rust-overlay.overlays.default

  # cachyos 内核/Proton:pinned overlay 锁 nixpkgs 版本与 lantian attic 缓存一致
  # (刻意不 follows 主 nixpkgs —— 内核 flake 自己的 nixpkgs 才命中缓存,见 flake.nix 输入注释)
  inputs.nix-cachyos-kernel.overlays.pinned
  inputs.proton-cachyos-nix.overlays.default

  # 独立仓库包集
  # dsh:插件系统消费 pkgs.dshPlugins 命名空间,overlay 是承重接口
  # (zcode/koharu 不在此:包经各自 homeManagerModules 自带,不走 overlay)
  inputs.nixdsh.overlays.default

  # 本仓自建包(by-name 布局)
  (import ../pkgs { inherit inputs; })
]
