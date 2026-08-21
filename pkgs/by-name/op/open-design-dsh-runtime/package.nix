# filepath: ~/nixos-config/pkgs/open-design-dsh-runtime/default.nix
# @open-design/dsh-runtime — OpenDesign 的 dsh profile 适配器 bundle
#
# 让 OD daemon 能驾驶本机 dsh:JSONL stdio 协议 + 冷恢复桥(dsh 官方
# out-of-tree bundle,manifest 带 dsh.bundle.patch → nixdsh mkPlugin 自动
# 识别进层表)。OD 侧效果:agent 列表选 DeepSeek Harness,probe 直接通过,
# 永不弹"安装连接组件"。
#
# 版本耦合(刻意不走 nixdsh registry 独立版本化):
#   OD spec 要求 daemon↔runtime 协议代际原子同步(probe frame 校验
#   protocol generation),src 与 services.open-design 共用同一
#   inputs.open-design pin —— flake.lock 一把锁,升级 OD 即升级本包。
#
# 构建(上游 esbuild.config.ts 的等价 CLI 翻译):
#   3 入口 bundle,packages=external → dist 运行时 import 依赖包;
#   tsc --emitDeclarationOnly 产物(*.d.ts)运行时不消费,跳过。
#   esbuild 是独立 Go 二进制,构建期无需 node/pnpm。
#
# node_modules 布局(对齐 `dsh plugin add` + nixdsh 物化约束):
#   - 运行时依赖 dsh-cmdline/commander:两个 npm tarball 直取
#     (hash=registry integrity,合计 <300KB;OD workspace 根 lockfile
#     覆盖全仓依赖树,fetchPnpmDeps 会拉 daemon/web 全闭包,刻意绕开)
#   - 7 个 @deepseek-ai/* peer:经 nixdsh linkPeers 回链宿主 dsh 安装
#     (Node ESM 从 store realpath 向上解析,profile 级 symlink 走不到)
{
  lib,
  stdenv,
  esbuild,
  fetchurl,
  dshPlugins,
  odDshRuntimeSrc, # flake.nix inline overlay 注入 = inputs.open-design
}:

let
  manifest = lib.importJSON "${odDshRuntimeSrc}/packages/dsh-runtime/package.json";

  # peer 集随上游 manifest 自动同步(手抄 7 个名字会漂)
  peers = builtins.attrNames (manifest.peerDependencies or { });

  npmTarball =
    { url, integrity }:
    fetchurl {
      inherit url;
      hash = integrity;
    };

  # 依赖版本钉在上游 package.json;hash 钉 npm registry integrity —— 两处
  # 事实源,上游 bump 依赖时这里 fetchurl 报 hash mismatch(fail-loud)
  dshCmdline = npmTarball {
    url = "https://registry.npmjs.org/@deepseek-ai/dsh-cmdline/-/dsh-cmdline-${
      manifest.dependencies."@deepseek-ai/dsh-cmdline"
    }.tgz";
    integrity = "sha512-dqRHF+kIlTBwt+fio/34ttp6B7Lrpm31A+EOoEwBuwaziiHTEAWVl50hS53dPFmPyVBRINavBdx7Fa7UT2/2iw==";
  };
  commander = npmTarball {
    url = "https://registry.npmjs.org/commander/-/commander-${manifest.dependencies.commander}.tgz";
    integrity = "sha512-z67u4ZhzCL/Tydu1lJARtEZYWbWaN7oYLHbsuzocr6y4N6WZAagG3RQ4FW61V1/0+jImpj293XfrcYnd1qxtPg==";
  };
in
stdenv.mkDerivation {
  pname = "open-design-dsh-runtime";
  inherit (manifest) version;

  src = "${odDshRuntimeSrc}/packages/dsh-runtime";

  nativeBuildInputs = [ esbuild ];

  buildPhase = ''
    runHook preBuild
    for entry in index startup invariant; do
      esbuild "src/$entry.ts" \
        --bundle --format=esm --platform=node --target=node24 \
        --packages=external \
        --outfile="dist/$entry.js"
    done
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r dist "$out/dist"
    cp cordis.patch.yml package.json README.md "$out/"

    # 运行时依赖:npm tarball(package/ 前缀)解包进插件内 node_modules
    _tmp=$(mktemp -d)
    mkdir -p "$out/node_modules/@deepseek-ai"
    tar -xf "${dshCmdline}" -C "$_tmp"
    mv "$_tmp/package" "$out/node_modules/@deepseek-ai/dsh-cmdline"
    tar -xf "${commander}" -C "$_tmp"
    mv "$_tmp/package" "$out/node_modules/commander"

    # peer 回链(宿主 dsh 安装 → 插件内 node_modules)
    ${dshPlugins.linkPeers peers}
    runHook postInstall
  '';

  passthru = {
    # mkPlugin 亦会读包内 package.json 自动识别,此处按 nixdsh 约定显式
    packageName = manifest.name;
    dshBundlePatch = manifest.dsh.bundle.patch or null;
  };

  meta = with lib; {
    description = "OpenDesign profile runtime bundle for DeepSeek Harness (dsh plugin)";
    homepage = "https://github.com/nexu-io/open-design/tree/main/packages/dsh-runtime";
    license = licenses.asl20;
    platforms = platforms.unix;
  };
}
