# filepath: ~/nixos-config/pkgs/by-name/op/open-design/package.nix
# OpenDesign daemon(open-design CLI)— 上游 nix/package-daemon.nix @open-design-v0.21.1
# 原文 vendor(上游 #7644 于 2026-08-31 退役官方 Nix 分发,删除全部 nix/ 树,
# 本仓自持;原文参见 tag 或 git 历史比对 sync)。
#
# 与上游的适配差异(刻意保留最小,便于上游复活时回归):
#   1. 砍 dream2nix/nixpkgs/system 三参(上游接线遗留,注释自认未用)
#   2. version 从 odSrc(package.json)读,原文件相对路径 ../package.json 在
#      vendor 位置失义
#   3. 源过滤/workspacePaths/pnpm 钉版从上游 flake.nix 平移进本目录
#      (filterProjectSource 逻辑逐字保留 —— include 列表锁死 hash 变更域)
#   4. patches:opencode2 支持补丁(本仓私有,不上游;上游 PR #7226 停在
#      dirty 未合,且漏了 models --verbose 与 #variant 两处,此处补全)
#
# 构建:stdenv + fetchPnpmDeps(pnpm workspace 过滤)+ tsc 逐包构建;
# better-sqlite3 12.10 从源码编译(node 24 无 v137 prebuild)。
# ⚠ 该产物在 node 24 上运行时会崩(ObjectWrap 回归 × bsq 12.10,open-design#6462)
# —— 部署一律走 pkgs.open-design-daemon-bsq13 graft 版,本包是它的底座。
#
# 更新流程:nix flake update sources/open-design → ./update.sh →
# 冒烟(open-design --help;CLI 无 --version)→ 换 better-sqlite3 ≥13 后按 bsq13 包内清单拆除 graft。
{
  lib,
  stdenv,
  nodejs,
  pnpm,
  fetchPnpmDeps,
  pnpmConfigHook,
  makeWrapper,
  python3,
  gnumake,
  pkg-config,
  odSrc,
}:
let
  inherit ((lib.importJSON (odSrc + "/package.json"))) version;

  # 与上游 CI change_scopes 同步(该 CI 已随 #7644 退役,同步参照物 =
  # 主干 git history 中对 pnpm-workspace/包清单的变更)
  workspacePaths = [
    "packages/release"
    "packages/contracts"
    "packages/registry-protocol"
    "packages/agui-adapter"
    "packages/plugin-runtime"
    "packages/sidecar-proto"
    "packages/launcher-proto"
    "packages/sidecar"
    "packages/platform"
    "packages/diagnostics"
    "apps/daemon"
  ];

  # 上游 flake.nix filterProjectSource 逐字平移(仅 self→odSrc)。
  # 目录前缀匹配分支保证 include 列表中尚未存在的路径其父目录仍进入树。
  filterOdSource =
    includePaths:
    lib.cleanSourceWith {
      src = odSrc;
      filter =
        path: type:
        let
          rel = lib.removePrefix (toString odSrc + "/") (toString path);
          matches =
            includePath:
            rel == includePath
            || lib.hasPrefix (includePath + "/") rel
            || (type == "directory" && lib.hasPrefix (rel + "/") includePath);
        in
        rel == "" || builtins.any matches includePaths;
    };

  src = filterOdSource (
    [
      "package.json"
      "pnpm-lock.yaml"
      "pnpm-workspace.yaml"
      "tsconfig.json"
      "assets"
      "plugins"
      "skills"
      "design-systems"
      "design-templates"
      "craft"
      "prompt-templates"
    ]
    ++ workspacePaths
  );

  # fetchPnpmDeps 的源比构建源更窄:仅锁文件 + workspace 清单
  pnpmDepsSrc = filterOdSource (
    [
      "package.json"
      "pnpm-lock.yaml"
      "pnpm-workspace.yaml"
    ]
    ++ map (workspacePath: "${workspacePath}/package.json") workspacePaths
  );

  pnpmWorkspaceFilters = map (workspacePath: "./${workspacePath}") workspacePaths;
  pnpmDepsHash = (import ./pnpm-deps.nix).daemonHash;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "open-design-daemon";
  inherit version src;

  patches = [ ./opencode2-support.patch ];

  pnpmWorkspaces = pnpmWorkspaceFilters;

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    makeWrapper
    # better-sqlite3 原生绑定从源码重建所需(node-gyp 走 python,
    # gnumake/pkg-config + stdenv C++ 编译器补全工具链)
    python3
    gnumake
    pkg-config
  ];

  # fetchPnpmDeps 默认用 pkgs.pnpm;钉到本目录 pnpm.nix 的 10.33.2,
  # 与 install 阶段(pnpmConfigHook 从 PATH 解析)保持同版
  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version;
    src = pnpmDepsSrc;
    hash = pnpmDepsHash;
    inherit pnpm;
    pnpmWorkspaces = pnpmWorkspaceFilters;
    fetcherVersion = 3;
  };

  env.NODE_ENV = "production";

  buildPhase = ''
    runHook preBuild

    # better-sqlite3 12.10 无 node-v137(Node 24)prebuild,跳过下载直接编译。
    # 不用 `pnpm rebuild`:pnpm 10 的 onlyBuiltDependencies × approve-builds
    # 同意门会让 rebuild 静默空跑;直接调 node-gyp 绕开。
    # npm_config_nodedir → 用 nixpkgs nodejs 自带头文件(沙箱无网络);
    # node-gyp 从 nodejs 内置 npm 的 bin 目录借道(它不是 bsq 直接依赖)。
    export npm_config_nodedir=${nodejs}
    export npm_config_build_from_source=true
    export PATH="${nodejs}/lib/node_modules/npm/bin/node-gyp-bin:$PATH"

    bsq_dir=$(find node_modules/.pnpm -mindepth 2 -maxdepth 4 \
      -type d -path '*/better-sqlite3@*/node_modules/better-sqlite3' \
      -print -quit)
    if [ -z "$bsq_dir" ]; then
      echo "ERROR: better-sqlite3 not found under node_modules/.pnpm — pnpm install may have failed" >&2
      exit 1
    fi

    echo "Building better-sqlite3 from source at $bsq_dir"
    ( cd "$bsq_dir" && node-gyp rebuild --release --build-from-source )

    # 静默跳过会产出运行时才炸的 "valid" 派生物,断言 fail-fast
    if [ ! -f "$bsq_dir/build/Release/better_sqlite3.node" ]; then
      echo "ERROR: better_sqlite3.node was not produced at $bsq_dir/build/Release/" >&2
      find "$bsq_dir" -name '*.node' -print >&2 || true
      exit 1
    fi

    for target in ${lib.escapeShellArgs workspacePaths}; do
      pnpm -C "$target" run --if-present build
    done
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/open-design $out/bin

    # 整树拷贝:pnpm 的 node_modules symlink 以相对路径解析兄弟包,
    # 无法裁剪到只剩 apps/daemon
    cp -r . $out/lib/open-design/

    # 运行时包出口指向 dist/;保留 workspace 清单供 Node 解析,
    # 裁掉源码/测试/构建配置,Nix fixup 扫描前清场
    for target in ${lib.escapeShellArgs workspacePaths}; do
      if [ "$target" = "apps/daemon" ]; then
        find "$out/lib/open-design/$target" -mindepth 1 -maxdepth 1 \
          ! -name dist \
          ! -name bin \
          ! -name node_modules \
          ! -name package.json \
          -exec rm -rf {} +
      else
        find "$out/lib/open-design/$target" -mindepth 1 -maxdepth 1 \
          ! -name dist \
          ! -name node_modules \
          ! -name package.json \
          -exec rm -rf {} +
      fi
    done

    # 根 devDependencies 经 pnpm symlink 暴露非 daemon workspace,裁掉
    # 悬空链接避免 Nix fixup 在断链上失败
    rm -f \
      $out/lib/open-design/node_modules/@open-design/components \
      $out/lib/open-design/node_modules/@open-design/tools-dev \
      $out/lib/open-design/node_modules/@open-design/tools-pack \
      $out/lib/open-design/node_modules/@open-design/tools-release \
      $out/lib/open-design/node_modules/@open-design/tools-serve \
      $out/lib/open-design/node_modules/.bin/tools-dev \
      $out/lib/open-design/node_modules/.bin/tools-pack \
      $out/lib/open-design/node_modules/.bin/tools-release \
      $out/lib/open-design/node_modules/.bin/tools-serve

    chmod +x $out/lib/open-design/apps/daemon/dist/cli.js

    # 二进制名 open-design(非上游的 od):od 进 HM profile 会遮蔽 coreutils
    # od,脚本/调试场景的 od 必须保持 coreutils(2026-09-08 实测踩坑)
    makeWrapper ${nodejs}/bin/node $out/bin/open-design \
      --add-flags $out/lib/open-design/apps/daemon/dist/cli.js \
      --set NODE_ENV production
    runHook postInstall
  '';

  passthru = {
    inherit nodejs;
    inherit (finalAttrs) pnpmDeps;
  };

  meta = {
    description = "OpenDesign daemon — local agent orchestrator + API (`open-design` CLI)";
    homepage = "https://github.com/nexu-io/open-design";
    license = lib.licenses.asl20;
    mainProgram = "open-design";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
