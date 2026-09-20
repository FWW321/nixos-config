{
  # filepath: ~/nixos-config/pkgs/by-name/op/open-design/pnpm-deps.nix
  # fetchPnpmDeps 的两个固定输出 hash(上游 nix/pnpm-deps.nix 原样平移)。
  # 生成物:lock 文件;除有意的 Nix 维护外勿手改。
  #
  # daemon 与 web 从不同的过滤源码树构建,各自的 fetchPnpmDeps 需要独立的
  # 固定输出 hash。pnpm-lock.yaml 或源过滤变更时刷新对应 hash:
  # 1. 把对应 hash 临时改为任意无效值(fakeHash)
  # 2. 跑 update.sh(或手动 nix build 对应目标)
  # 3. 把 Nix 报错的 "got: sha256-…" 抄回下方对应字段
  daemonHash = "sha256-s+o4o+SOy4/2nsGjWZGiFviciFaAQs7R/eoV15pDfwY=";
  webHash = "sha256-SIs+q91GnNvX8P4Vh/515YAXqWlvFV05HLZD1I9MDGw=";
}
