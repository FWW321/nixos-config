# filepath: ~/nixos-config/pkgs/open-design-daemon-bsq13/default.nix
# open-design daemon × better-sqlite3 13.x graft
#
# 崩溃链:node 24.x ObjectWrap cleanup hooks 回归(nodejs/node#63642/
# #63923,#63985 修复未回补 v24)× better-sqlite3 12.10.0 Statement 析构调
# RemoveEnvironmentCleanupHook → GC 时机不巧即 ABRT(open-design#6462,
# 实测 24.18.1/24.19.0 均中招,仅频率差异)。
#
# 13.0.0 起整个重构到 node-addon-api(N-API):不再继承 node::ObjectWrap,
# 断言链结构性消失;且预编译二进制直接随 npm 包分发(prebuilds/linux-x64.node,
# N-API ABI 稳定,跨 node 版本可用)——零编译,fetchurl + patchelf rpath 即成。
#
# graft 方式:整树复制 daemon 包,替换
# .pnpm/better-sqlite3@12.10.0/node_modules/better-sqlite3 内容为 13.0.3。
# 目录名保留 12.10.0(pnpm symlink node_modules/better-sqlite3 指向该路径,
# 运行时按路径解析不校验版本;目录名仅为 pnpm 布局标识)。12 的 runtime deps
# (bindings/prebuild-install)成孤儿,留在树中无害;13 的 dependencies 仅
# node-addon-api(构建期头文件,lib/*.js 零 require),树内 7.1.1 无人加载。
#
# 拆除条件:open-design 把 better-sqlite3 bump 到 ≥13(查法见下)
#
# ── 上游修复后的清理清单(3 处,按序)──────────────────────────────
# 前置确认(nix flake update open-design 后):
#   grep '"better-sqlite3"' <(nix build .#nixosConfigurations.FWW-Desktop.pkgs.open-design-daemon-bsq13 --no-link --print-out-paths 2>/dev/null | xargs -I{} jq -r .dependencies.better-sqlite3 {}/../apps/daemon/package.json) 2>/dev/null
#   —— 更简单:直接看上游 https://github.com/nexu-io/open-design/blob/main/apps/daemon/package.json
#   或 curl -s https://raw.githubusercontent.com/nexu-io/open-design/main/apps/daemon/package.json | jq .dependencies.better-sqlite3
#   版本 ≥13 即可动手;graft 包自带 fail-loud(树上找不到 12.10.0 目录即构建报错,
#   上游真 bump 后本包会自己炸出来提醒你,不会静默产出坏包)
#
#   1. users/fww/ai/open-design.nix:删除文件头「better-sqlite3 13 graft」整段
#      注释 + let 块(odDaemonFixed)+ services.open-design.package 行(还原默认)
#   2. flake.nix:删除 overlay 里 open-design-daemon-bsq13 条目(注意保留
#      同一 overlay 块中的 open-design-dsh-runtime,勿整块删)
#   3. git rm -r pkgs/open-design-daemon-bsq13/
#   然后 nh os switch . 验证:journalctl --user -u open-design 无断言崩溃,
#   OD UI 本地 Agent 扫描正常。
#
# 注:dsh-runtime(open-design-dsh-runtime 包)与此补丁无关,是 OD↔dsh 的
# profile 适配器,清理本补丁时不要动它。
{
  lib,
  stdenv,
  patchelf,
  fetchurl,
  daemonPkg, # flake.nix inline overlay 注入 = inputs.open-design daemon
}:

let
  # hash = npm registry dist.integrity(SRI);上游发 13.0.4+ 时换此值
  betterSqlite13 = fetchurl {
    url = "https://registry.npmjs.org/better-sqlite3/-/better-sqlite3-13.0.3.tgz";
    hash = "sha512-RbOBxmLBG8uvFUc15X9+9SFemKcQ0WBuISBVkpuiaUB2qblC8UWlHEjdWVoZ8AdhSwmoEgsiXKfopX0CQxaACQ==";
  };
in
stdenv.mkDerivation {
  name = "open-design-daemon-bsq13-${lib.getVersion daemonPkg}";

  # prebuilds/*.node 是 Ubuntu 构建的 ELF,补 libstdc++ rpath
  # (显式 patchelf,不依赖 autoPatchelfHook 的 fixup 时机)
  nativeBuildInputs = [ patchelf ];
  buildInputs = [ stdenv.cc.cc.lib ];

  buildCommand = ''
    cp -a --reflink=auto ${daemonPkg}/. "$out"
    chmod -R u+w "$out"

    # 复制来的 bin/od wrapper exec 原包路径的 cli.js,会把 graft 旁路掉
    # ——所有原包引用重定向到本包
    if [ -f "$out/bin/od" ]; then
      substituteInPlace "$out/bin/od" \
        --replace-fail "${daemonPkg}" "$out"
    else
      echo "bsq13 graft: bin/od not found in daemon package" >&2
      exit 1
    fi

    _bsq="$out/lib/open-design/node_modules/.pnpm/better-sqlite3@12.10.0/node_modules/better-sqlite3"
    if [ ! -d "$_bsq" ]; then
      echo "bsq13 graft: better-sqlite3@12.10.0 not found in daemon tree — upstream layout changed or already bumped" >&2
      exit 1
    fi
    rm -rf "$_bsq"
    mkdir -p "$_bsq"
    tar -xf ${betterSqlite13} -C "$_bsq" --strip-components=1
    # fail-loud:prebuild 缺失 = 上游包布局变化,静默产出会在运行时炸
    [ -f "$_bsq/prebuilds/linux-x64.node" ] || {
      echo "bsq13 graft: prebuilds/linux-x64.node missing from 13.0.3 tarball" >&2
      exit 1
    }
    # rpath:libstdc++(其余依赖 libc/libm 由解释器进程已加载)
    patchelf --set-rpath "${stdenv.cc.cc.lib}/lib" "$_bsq/prebuilds/linux-x64.node" \
      || { echo "bsq13 graft: patchelf failed on linux-x64.node" >&2; exit 1; }

    # dsh 版本白名单扩容:上游钉 0.1.0-rc.6,本机 dsh 为 rc.8(nixdsh)。探测/
    # 模型/stdio 协议实测兼容(probe protocol v1 通过,peers 已按 rc.8 宿主回链),
    # 白名单仅是版本诊断的比对源,扩容消掉 UI 的"不支持的版本"警告
    substituteInPlace "$out/lib/open-design/apps/daemon/dist/runtimes/defs/deepseek-harness.js" \
      --replace-fail "supportedVersions: ['0.1.0-rc.6']" "supportedVersions: ['0.1.0-rc.6', '0.1.0-rc.8']"
  '';

  meta = {
    # HM 模块 ExecStart/MCP 派生经 lib.getExe 取 bin/od(二进制名与包名
    # 不一致,必须显式声明,否则走弃用的同名假设并告警)
    mainProgram = "od";
    description = "open-design daemon with better-sqlite3 13.x grafted (nodejs#63642 crash fix)";
    platforms = lib.platforms.unix;
  };
}
