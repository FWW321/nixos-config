# jcode:Rust 编写的极低内存 AI 编码 agent harness(TUI)
# 源码:https://github.com/1jehuang/jcode
#
# 采用上游预构建二进制(CentOS 7 / glibc 2.17 基线),autoPatchelf 适配 NixOS
# 源码编译方案(~100 crate workspace,edition 2024)维护成本过高:上游每周多次发版
#
# 版本升级:改 version + hash,`nix build` 自动校验 SHA256
# 注入为 nixpkgs overlay → pkgs.jcode 可用(见 flake.nix 的 nixpkgs.overlays)
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  openssl,
  zlib,
}:

let
  version = "0.72.0";
  suffix =
    if stdenv.hostPlatform.isAarch64 then "linux-aarch64"
    else "linux-x86_64";
in
stdenv.mkDerivation {
  pname = "jcode";
  inherit version;

  src = fetchurl {
    url = "https://github.com/1jehuang/jcode/releases/download/v${version}/jcode-${suffix}.tar.gz";
    hash = "sha256-YPy/q2yS5j4y2Kf/dXtWlkebM43kVeTrFxgM/JJ3Q+0=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [
    openssl
    zlib
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin

    # tarball 内 jcode-linux-x86_64 是 505B 启动器(非-Nix 下设 LD_LIBRARY_PATH)
    # 实际 ELF 是 jcode-linux-x86_64.bin(148.9MB);autoPatchelf 直接管 .bin 的 RUNPATH
    install -Dm755 jcode-${suffix}.bin $out/bin/jcode

    runHook postInstall
  '';

  # 禁用自动更新(NixStore 只读,版本由 flake 管理)和遥测
  # JCODE_INITIAL_PROVIDER_EXPLICIT:阻止 auth 检测事件覆盖 config.toml 的 default_provider
  #   (jcode 检测到 Copilot/Claude OAuth 后会强制切到"最强模型",此变量关掉该行为)
  # 首次启动的引导界面按一次 Esc 即永久跳过(靠 launch_count 判断,跳过后不再弹出)
  postFixup = ''
    wrapProgram $out/bin/jcode \
      --set JCODE_NO_TELEMETRY 1 \
      --set JCODE_INITIAL_PROVIDER_EXPLICIT 1 \
      --add-flags "--no-update"
  '';

  meta = {
    description = "RAM-efficient coding agent harness with built-in memory, swarm, and safety system";
    homepage = "https://github.com/1jehuang/jcode";
    license = lib.licenses.mit;
    mainProgram = "jcode";
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
