# opencode2:OpenCode v2(AI coding agent,后台服务 + TUI 架构重写版)
# 源码:https://github.com/anomalyco/opencode (v2.0.x tag)  文档:https://opencode.ai/v2/docs
#
# 采用 npm 平台子包预构建二进制(Bun 编译的独立 ELF,仅依赖 glibc),autoPatchelf 适配 NixOS
# 官方安装脚本/npm postinstall 做的也是"选平台二进制"这一件事,这里直接取最终产物
# v2 正式版(2.0.0+)迁到新 scope @opencode/cli(beta 时代的 @opencode-ai/cli 不再发
# v2 正式版);tarball 内二进制名回归 opencode,本仓刻意保持 bin/opencode2 产出:
# 与 nixpkgs v1 包的 bin/opencode 区分 PATH,open-design patch 亦按 opencode2 解析。
# nixpkgs 至今只有 v1(1.18.x),v2 未收录
#
# 版本升级:npm view @opencode/cli version → 改 version + hash(注意 installPhase
# 的 tarball 内 bin 名若上游再改,需同步)
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
  # v2 正式版走 @opencode/cli 的 latest tag
  version = "2.0.11";

  # npm 平台子包名(fetchurl 直接拉 tarball,绕过 node 生态)
  platformPkg =
    if stdenv.hostPlatform.isAarch64 then "@opencode/cli-linux-arm64" else "@opencode/cli-linux-x64";
  # scope 下的 npm registry 路径
  scopeDir = builtins.head (lib.splitString "/" platformPkg);
  baseName = lib.last (lib.splitString "/" platformPkg);
in
stdenv.mkDerivation {
  pname = "opencode2";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/${scopeDir}/${baseName}/-/${baseName}-${version}.tgz";
    hash = "sha256-kCxnxGrJLwhfHP7WrssMRf329sGeQligdL80aulGZrs=";
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

    # tarball 只有 bin/opencode 单个二进制(bin/ 下其余是 sourcemap,不装);
    # 2.0.0+ tarball 内名回归 opencode,install 侧改名为 opencode2(见头注释)
    install -Dm755 bin/opencode $out/bin/opencode2
    # rg 是功能性依赖(非泛用保险):二进制内嵌 @vscode/ripgrep 引用,
    # fork/grep 工具按名调 rg;宿主 shell 恰好有 rg 会掩盖此缺口,
    # 裸环境(容器/沙箱/最小 PATH)即现形 —— 故注入而非依赖环境
    wrapProgram $out/bin/opencode2 \
      --prefix PATH : ${lib.makeBinPath [ ripgrep ]}

    runHook postInstall
  '';

  meta = {
    description = "OpenCode v2 — the open source AI coding agent (server + TUI rewrite)";
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
