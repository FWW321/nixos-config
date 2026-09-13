#!/usr/bin/env bash
# filepath: ~/nixos-config/pkgs/by-name/op/open-design/update.sh
# OpenDesign 自持打包的更新自愈循环(上游退役 Nix 分发后 hash 由本仓持有)。
#
# 用法(主仓根目录先 bump 源):
#   nix flake update sources/open-design
#   ./update.sh
#
# 三件事:
#   1. packageManager 联动:比对源码树 package.json#pnpm@<ver> 与 pnpm.nix,
#      漂移则 prefetch 新 tgz hash 并改写 pnpm.nix
#   2. daemonHash / webHash 重生:fakeHash → nix build 抓 "got: sha256-…"
#      → 写回 pnpm-deps.nix → 复验构建
#   3. 冒烟:open-design --version
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(git -C "$here" rev-parse --show-toplevel)"
FAKE="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

# ── 1. pnpm 钉版联动 ─────────────────────────────────────────────
rev="$(jq -r '.nodes.open-design.locked.rev' "$root/flake.lock")"
want="$(curl -sf "https://raw.githubusercontent.com/nexu-io/open-design/$rev/package.json" | jq -r .packageManager)"
want="${want#pnpm@}"
cur="$(grep -oP 'version = "\K[^"]+' "$here/pnpm.nix")"
if [ "$want" != "$cur" ]; then
  echo "packageManager $cur → $want,prefetch tgz hash…"
  hash="$(nix store prefetch-file --hash-type sha256 \
    "https://registry.npmjs.org/pnpm/-/pnpm-$want.tgz" | jq -r .hash)"
  sed -i "s|version = \"$cur\"|version = \"$want\"|; \
          s|hash = \"sha256-[A-Za-z0-9+/=]*\"|hash = \"$hash\"|" "$here/pnpm.nix"
  echo "pnpm.nix 已更新到 $want"
else
  echo "pnpm 钉版一致($cur)"
fi

# ── 2. FOD hash 重生 ─────────────────────────────────────────────
regen() { # $1 = pnpm-deps.nix 键名  $2 = flake 构建目标
  local key="$1" target="$2" got
  if nix build "$root#$target" --no-link 2>/dev/null; then
    echo "$key: 现值有效,跳过"; return 0
  fi
  echo "$key: 重生中…"
  sed -i "s|$key = \"[^\"]*\"|$key = \"$FAKE\"|" "$here/pnpm-deps.nix"
  set +e
  out="$(nix build "$root#$target" --no-link 2>&1)"
  rc=$?
  set -e
  got="$(grep -oP 'got:\s+\Ksha256-[A-Za-z0-9+/=]+' <<<"$out" | tail -1)"
  if [ -z "$got" ]; then
    echo "$hash 目标构建失败且未捕获 got: hash —— 非锁文件漂移(大概率是上游构建姿势变更,需人工 diff vendor 文件):" >&2
    tail -40 <<<"$out" >&2
    return 1
  fi
  sed -i "s|$key = \"[^\"]*\"|$key = \"$got\"|" "$here/pnpm-deps.nix"
  echo "$key → $got"
  nix build "$root#$target" --no-link
}

regen daemonHash open-design
regen webHash open-design-web

# ── 3. 冒烟(CLI 无 --version 选项,--help 不启动 daemon 即可验证 wrapper+graft)──
nix run "$root#open-design" -- --help >/dev/null
echo "✓ OpenDesign 更新完成"
