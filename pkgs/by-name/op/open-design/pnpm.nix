# filepath: ~/nixos-config/pkgs/by-name/op/open-design/pnpm.nix
# pnpm 钉版:上游 package.json#packageManager 声明 engines 下限,nixpkgs
# 默认 pnpm_10 版本不满足时 `pnpm install` 直接拒跑(且报错不像版本问题)。
# 版本与 hash 必须与源码树的 packageManager 字段锁步更新 —— update.sh
# 自动比对,手动 bump 时用:
#   nix store prefetch-file --hash-type sha256 \
#     https://registry.npmjs.org/pnpm/-/pnpm-<版本>.tgz
{
  pnpm_10,
  fetchurl,
}:
pnpm_10.overrideAttrs (_: rec {
  version = "10.33.2";
  src = fetchurl {
    url = "https://registry.npmjs.org/pnpm/-/pnpm-${version}.tgz";
    hash = "sha256-envPE9f2zrOUbAOXg3PZm+n94cr8MAC9/tTE95EWdhA=";
  };
})
