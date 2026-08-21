# opencode2:OpenCode v2 beta(AI coding agent,后台服务 + TUI 架构重写版)
# 源码:https://github.com/anomalyco/opencode (2.0 分支)  文档:https://opencode.ai/v2/docs
#
# 采用 npm 平台子包预构建二进制(Bun 编译的独立 ELF,仅依赖 glibc),autoPatchelf 适配 NixOS
# 官方安装脚本/npm postinstall 做的也是"选平台二进制"这一件事,这里直接取最终产物
# v1(opencode)与 v2(opencode2)是不同二进制,本包装的是 v2;beta 期间 nixpkgs 未收录
#
# 版本升级:npm view @opencode-ai/cli@beta version → 改 version + hash
# 注入为 nixpkgs overlay → pkgs.opencode2 可用(见 flake.nix 的 nixpkgs.overlays)
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  ripgrep,
}:

let
  # beta tag 发布流水号,与 @opencode-ai/cli 同步
  version = "0.0.0-beta-17793";

  # npm 平台子包名(fetchurl 直接拉 tarball,绕过 node 生态)
  platformPkg =
    if stdenv.hostPlatform.isAarch64 then
      "@opencode-ai/cli-linux-arm64"
    else
      "@opencode-ai/cli-linux-x64";
  # scope 下的 npm registry 路径
  scopeDir = builtins.head (lib.splitString "/" platformPkg);
  baseName = lib.last (lib.splitString "/" platformPkg);
in
stdenv.mkDerivation {
  pname = "opencode2";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/${scopeDir}/${baseName}/-/${baseName}-${version}.tgz";
    hash = "sha256-Wyd7kvFnO0lkiSsGijQtCHbT5p3+jFhyaQz6phcrAKc=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [ stdenv.cc.cc.lib ];

  # Bun 编译产物在 ELF 尾部带 embedded trailer,module graph 靠文件内偏移定位;
  # strip 会改动 ELF 结构导致退化为纯 bun CLI,必须禁用
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    # tarball 只有 bin/opencode2 单个二进制(bin/ 下其余是 sourcemap,不装)
    # sourceRoot 已是解包后的 package/,直接取 bin/
    install -Dm755 bin/opencode2 $out/bin/opencode2
    # rg 是功能性依赖(非泛用保险):二进制内嵌 @vscode/ripgrep 引用,
    # fork/grep 工具按名调 rg;宿主 shell 恰好有 rg 会掩盖此缺口,
    # 裸环境(容器/沙箱/最小 PATH)即现形 —— 故注入而非依赖环境
    wrapProgram $out/bin/opencode2 \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}

    runHook postInstall
  '';

  meta = {
    description = "OpenCode v2 beta — the open source AI coding agent (server + TUI rewrite)";
    homepage = "https://opencode.ai/v2/docs";
    changelog = "https://github.com/anomalyco/opencode/releases";
    license = lib.licenses.mit;
    mainProgram = "opencode2";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
