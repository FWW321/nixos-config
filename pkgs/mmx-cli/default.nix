# mmx-cli: MiniMax Token Plan 官方 CLI(text/image/video/speech/music 全模态)
# 源码: https://github.com/MiniMax-AI/cli  npm: mmx-cli@1.0.19 (tag v1.0.19, 2026-08-01)
#
# 打包策略:直接消费 npm registry 成品 tarball(思路同 pkgs/pdf-inspector 的 fetchCrate)
#   dist/mmx.mjs 为 bun 预构建 bundle,依赖均已内联,唯一外部静态 import 是 undici
#   (bundle 顶层 ProxyAgent/setGlobalDispatcher,代理支持用) → 无需引入 bun/npmDeps
#   构建链,仅注入 nodejs + undici 两个运行时依赖。
#   注意:NODE_PATH 对 ESM 无效,undici 必须实体挂在 dist 同级的 node_modules/ 下
#   (上游 package.json 声明的 @clack/prompts/es-toolkit 等已内联,无需安装)。
#
# 上游仓库无 LICENSE 文件、package.json 无 license 字段 → meta 不声明 license
# opencode skill (users/fww/ai/skills/mmx-cli) 经 common/skills.nix 的 package 字段绑定此包
#
# 鉴权(2026-08-18 实测 v1.0.19 二进制,注意与官方 SKILL.md 文档不符,文档漂移):
#   凭据解析链只有 --api-key flag > ~/.mmx/config.json(oauth/api_key) > 报错。
#   MINIMAX_API_KEY env 不在链内,仅在交互式引导中触发"存入 config?"提示,
#   --non-interactive 下静默跳过 → env 注入 key 无效。
#   故 $out/bin/mmx 是注入包装器:参数无 --api-key 且 /run/secrets/minimax_api_key
#   可读时,自动追加 --api-key(sops 同源 key,key 不落盘;ps 可见命令行属官方
#   flag 语义,与错误提示推荐路径一致)。显式传 --api-key(含 =)则不注入。
#   顺带导出 MINIMAX_REGION=cn 默认(此 env 是真被 ze() 读取的,免每调用探测)。
{ lib, stdenv, fetchurl, nodejs, makeWrapper }:

stdenv.mkDerivation (finalAttrs: {
  pname = "mmx-cli";
  version = "1.0.19";

  # npm registry 成品(与 npm install -g mmx-cli 同源同物)
  src = fetchurl {
    url = "https://registry.npmjs.org/mmx-cli/-/mmx-cli-${finalAttrs.version}.tgz";
    hash = "sha256-OYESnGzoReby1flbIi/uN7x7kvZin218FX16SW+cwEY=";
  };

  # 唯一运行时依赖(上游约束 ^6.21.1,取 6.x 最新)
  undiciSrc = fetchurl {
    url = "https://registry.npmjs.org/undici/-/undici-6.28.0.tgz";
    hash = "sha256-Mqhsb6KP1IuRVVUEjAW703rTVFfZ6UWVODGkN0yIapw=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontConfigure = true;
  dontBuild = true;
  dontUnpack = true; # installPhase 直接消费 $src/undiciSrc 两个 tarball

  installPhase = ''
    runHook preInstall

    # 直接解进输出:npm tarball 顶层是 package/,--strip-components=1 摊平
    # (不走构建目录,避开 stdenv 对单顶层目录 tarball 的自动 cd 行为)
    mkdir -p $out/lib/mmx-cli $out/lib/mmx-cli/node_modules
    tar -xzf ${finalAttrs.src} -C $out/lib/mmx-cli --strip-components=1
    tar -xzf ${finalAttrs.undiciSrc} -C $out/lib/mmx-cli/node_modules
    mv $out/lib/mmx-cli/node_modules/package $out/lib/mmx-cli/node_modules/undici

    # 裸 node 入口放 libexec,bin 换成 secret 注入包装器(见文件头注释)
    mkdir -p $out/bin $out/libexec
    makeWrapper ${lib.getExe nodejs} $out/libexec/mmx-node \
      --add-flags "$out/lib/mmx-cli/dist/mmx.mjs"
    cat > $out/bin/mmx <<'WRAPPER'
    #!/usr/bin/env bash
    # secret 注入包装器:key 来自 sops(/run/secrets),不落盘;显式 --api-key 不干预
    for _a in "$@"; do
      case "$_a" in --api-key|--api-key=*) exec @mmx-node@ "$@" ;; esac
    done
    unset _a
    export MINIMAX_REGION="''${MINIMAX_REGION:-cn}"
    if [[ -r /run/secrets/minimax_api_key ]]; then
      exec @mmx-node@ "$@" --api-key "$(cat /run/secrets/minimax_api_key)"
    fi
    exec @mmx-node@ "$@"
    WRAPPER
    sed -i "s|@mmx-node@|$out/libexec/mmx-node|g" $out/bin/mmx
    chmod +x $out/bin/mmx

    runHook postInstall
  '';

  # 冒烟:--version 验证 bundle+undici 加载与包装器透传
  passthru.tests.smoke = finalAttrs.finalPackage.overrideAttrs (_: {
    doInstallCheck = true;
    installCheckPhase = ''
      $out/bin/mmx --version | grep -F "${finalAttrs.version}"
    '';
  });

  meta = {
    description = "CLI for the MiniMax AI Platform — Token Plan unified access to text/image/video/speech/music";
    homepage = "https://github.com/MiniMax-AI/cli";
    mainProgram = "mmx";
    platforms = lib.platforms.unix;
  };
})
