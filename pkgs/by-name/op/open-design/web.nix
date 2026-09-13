# filepath: ~/nixos-config/pkgs/by-name/op/open-design/web.nix
# OpenDesign Web SPA(Next.js 静态导出)— 上游 nix/package-web.nix
# @open-design-v0.21.1 原文 vendor,适配点同 package.nix(砍参/版本源自
# odSrc/过滤内联/pnpm 钉版)。
#
# 产物布局:$out/ = apps/web/out/ 内容(index.html + _next/ 等),塞进任意
# 静态服务器即可。构建期 OD_DAEMON_URL="",bundle 发相对请求(/api/*、
# /artifacts/*、/frames/*),服务侧须同源反代这三段到 daemon
# (modules/home/open-design.nix 的内置 caddy 即做此事)。
{
  lib,
  stdenv,
  nodejs,
  pnpm,
  fetchPnpmDeps,
  pnpmConfigHook,
  odSrc,
}:
let
  inherit ((lib.importJSON (odSrc + "/package.json"))) version;

  workspacePaths = [
    "packages/release"
    "packages/components"
    "packages/contracts"
    "packages/host"
    "packages/platform"
    "packages/sidecar"
    "packages/sidecar-proto"
    "apps/web"
  ];

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
    ]
    ++ workspacePaths
  );

  pnpmDepsSrc = filterOdSource (
    [
      "package.json"
      "pnpm-lock.yaml"
      "pnpm-workspace.yaml"
    ]
    ++ map (workspacePath: "${workspacePath}/package.json") workspacePaths
  );

  pnpmWorkspaceFilters = map (workspacePath: "./${workspacePath}") workspacePaths;
  pnpmDepsHash = (import ./pnpm-deps.nix).webHash;
  dependencyBuildPaths = lib.filter (workspacePath: workspacePath != "apps/web") workspacePaths;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "open-design-web";
  inherit version src;

  pnpmWorkspaces = pnpmWorkspaceFilters;

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version;
    src = pnpmDepsSrc;
    hash = pnpmDepsHash;
    inherit pnpm;
    pnpmWorkspaces = pnpmWorkspaceFilters;
    fetcherVersion = 3;
  };

  env = {
    NODE_ENV = "production";
    OD_DAEMON_URL = "";
  };

  buildPhase = ''
    runHook preBuild
    for target in ${lib.escapeShellArgs dependencyBuildPaths}; do
      pnpm -C "$target" run --if-present build
    done

    # next.config.ts 以 NODE_ENV=production 门控静态导出,写 apps/web/out/
    pnpm --filter @open-design/web run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r apps/web/out/. $out/
    runHook postInstall
  '';

  passthru = {
    inherit nodejs;
    inherit (finalAttrs) pnpmDeps;
  };

  meta = {
    description = "OpenDesign — Next.js static SPA (apps/web)";
    homepage = "https://github.com/nexu-io/open-design";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
