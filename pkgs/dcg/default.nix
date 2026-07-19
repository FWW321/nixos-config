# filepath: ~/nixos-config/pkgs/dcg/default.nix
# dcg (Destructive Command Guard):拦截 AI agent 的破坏性 shell 命令
# 源码:https://github.com/Dicklesworthstone/destructive_command_guard
#
# 工具链:rust-toolchain.toml 锁 nightly-2026-06-06(rustix 1.1.4 在 stable 回归,issue #147)
# 通过 rust-overlay 取对应日期 nightly,makeRustPlatform 注入给 buildRustPackage
# 注入为 nixpkgs overlay → pkgs.dcg 可用(见 flake.nix 的 nixpkgs.overlays)
#
# 与 rtk 形状一致:二进制 + plugin 同 derivation 产出(postInstall 装进 store)
# → common/plugins.nix 用 source = "${pkgs.dcg}/share/opencode-plugins" 引用
# → agents/opencode.nix 写 xdg.configFile "opencode/plugins/dcg-guard.js"
# 避免二进制升级而 plugin 没升级的版本漂移
{
  lib,
  fetchFromGitHub,
  makeRustPlatform,
  pkgs,
}:

let
  toolchain = pkgs.rust-bin.nightly."2026-06-06".default;
  rustPlatform = makeRustPlatform {
    cargo = toolchain;
    rustc = toolchain;
  };
in
rustPlatform.buildRustPackage rec {
  pname = "dcg";
  version = "0.6.9";

  src = fetchFromGitHub {
    owner = "Dicklesworthstone";
    repo = "destructive_command_guard";
    rev = "v${version}";
    hash = "sha256-z9GK8YuFR+b/zNsJVXDnO4TR6eneDhcR78v15yn4aXo=";
  };

  cargoHash = "sha256-XjyUVeVnZR+vfbrR9qmZ0AoYPTXhOkbTx0GxFErrtFA=";

  # vergen-gix (build.rs) 构建期读 git 元数据嵌入 --version
  nativeBuildInputs = [ pkgs.git ];

  # 跳过上游 80+ 测试文件(e2e/security/regression corpus 等)
  # 上游 CI 已覆盖;此包只做 packaging,不 own 上游代码;且部分测试需网络/git fixture 在 sandbox 会挂
  doCheck = false;

  # dcg 无官方 opencode plugin;此桥接源自 aspiers/ai-config(社区),~40 行,协议稳定
  # 直接内联进 pkgs/dcg 避免依赖无关 dotfiles repo
  # 二进制 + plugin 同 derivation 产出,避免版本漂移
  postInstall = ''
    install -Dm644 ${./dcg-guard.js} $out/share/opencode-plugins/dcg-guard.js
  '';

  meta = {
    description = "Destructive Command Guard — intercepts destructive shell commands from AI coding agents";
    homepage = "https://github.com/Dicklesworthstone/destructive_command_guard";
    # MIT + OpenAI/Anthropic rider(自定义 license),自用 OK,不能推上游 nixpkgs
    license = lib.licenses.unfree;
    mainProgram = "dcg";
  };
}
