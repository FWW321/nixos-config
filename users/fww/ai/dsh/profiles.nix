# filepath: ~/nixos-config/users/fww/ai/dsh/profiles.nix
# 手写命名 profile(非交互组合;交互面 profile 由 plugins.<name>.face 自动生成,
# 两者互斥,见 nixdsh lib/faces.nix)
{ pkgs, ... }:

{
  programs.dsh.profiles = {
    # OpenDesign 的 dsh 适配 profile(OD agent 列表选 DeepSeek Harness 即用)
    # 物化到 $DSH_HOME/profiles/open-design,OD daemon 探测
    # `dsh --profile open-design --probe` 直接过 → 永不弹"安装连接组件"
    # runtime 包版本与 services.open-design 同 flake.lock pin(协议原子耦合,
    # 见 pkgs/open-design-dsh-runtime)
    open-design.plugins = [
      "@deepseek-ai/dsh-base" # base 先行(dsh 官方 profile 组合约定)
      pkgs.open-design-dsh-runtime
    ];
  };
}
