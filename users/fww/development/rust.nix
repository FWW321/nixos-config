# filepath: ~/nixos-config/users/fww/development/rust.nix
# Rust 语言生态：rust-overlay nightly 纯 nix 工具链 + cargo/openssl 运行环境
#
# - 工具链：rust-overlay selectLatestNightlyWith = 最新可用 nightly（自动跳过组件缺失的日期）
#   default profile（rustc/cargo/rustfmt/clippy）+ rust-src/rust-analyzer 扩展
#   只装 stable 也有的组件，不含 miri 等 nightly 专属实验组件
#   声明式、可复现；删 home.packages 行即卸载，无 ~/.rustup 残留
#   rust-analyzer 随工具链上 PATH → nvim(native lsp) / emacs(eglot) / opencode 直接复用
# - crane（github:ipetkov/crane）是nix上的rust构建工具，对比cargo build多了两个优势:
#   - 可复现 — 工具链版本、依赖全由 flake.lock 锁定，换机器换 CI 跑出来一模一样
#   - 依赖分层缓存 — 你的代码变了但依赖没变时，不重新编译依赖，只编译你的代码
#   不在此装——crane 是 nix 库而非 CLI，无 crane 命令；在每个 repo 的 flake.nix 声明 inputs.crane 即按需拉取
#   核心 buildPackage 编译 crate，配合 buildDepsOnly → cargoArtifacts 做依赖分层缓存（改代码不重编依赖）
#   与本文件分工：这里管【开发工具链】（cargo build/run/test 交互式），crane 管【出可部署 nix 包】
# - cc linker（gcc）不在此：gcc 是 C/C++ 域编译器，见 c-cpp.nix；Rust 借之作 linker（跨域构建依赖）
# - nushell extraEnv 整体在此：以下每行都只服务 Rust 域
#   · openssl_*：openssl-sys crate 编译期定位（NixOS 不暴露 openssl）
#   · LD_LIBRARY_PATH：cargo install 二进制 interpreter=nix glibc ld（不走 nix-ld），需此找 libssl.so.3
#   · CARGO_NET_GIT_FETCH_WITH_CLI：git insteadOf https→ssh，libgit2 不读 ~/.ssh/config
#   (nodejs/bun 自带 openssl、zig 自含 cc、lean4/souffle 预编译 → 均不依赖这些)
{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    # 最新 nightly 工具链（selectLatestNightlyWith 自动选组件齐全的最新日期，避免缺件构建失败）
    # default profile 已含 rustc/cargo/rustfmt/clippy；rust-src/rust-analyzer 作为扩展补齐（stable 组件）
    # 注意：列表里函数应用必须整体加括号——Nix 列表字面量用空格分元素，f (x) 会被拆成两个元素而非应用
    (rust-bin.selectLatestNightlyWith (
      toolchain:
      toolchain.default.override {
        extensions = [
          "rust-src"
          "rust-analyzer"
        ];
      }
    ))
    # cargo-dist（二进制名 dist）：Rust 发布打包工具（生成各平台可分发产物 + 上传归档，配合 GitHub Release）
    # 与 crane 分工：crane 出 /nix/store 的 derivation（可复现构建）；cargo-dist 出面向用户的安装包（发布用）
    # 注：0.14+ 上游已将二进制从 cargo-dist 改名为 dist，直接用 `dist init/build/plan`
    cargo-dist
  ];

  # cargo 凭证:token-from-stdout provider 从 sops 读,token 不落盘
  # ~/.cargo/config.toml 声明式(无 secret);cargo 需要 token 时执行 cat 读 /run/secrets/crates_token(tmpfs)
  # 副作用:不支持 cargo login/logout(token 由 sops 管,无需 login)
  home.file.".cargo/config.toml".text = ''
    [registry]
    global-credential-providers = ["cargo:token-from-stdout cat /run/secrets/crates_token"]
  '';

  programs.nushell.extraEnv = ''
    $env.PATH = ($env.PATH | prepend $"($env.HOME)/.cargo/bin")
    $env.OPENSSL_DIR = "${pkgs.openssl.out}"
    $env.OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib"
    $env.OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include"
    $env.LIBRARY_PATH = "${pkgs.openssl.out}/lib"
    # cargo install 的二进制 interpreter 是 nix glibc ld（不走 nix-ld），需此变量找 libssl.so.3
    $env.LD_LIBRARY_PATH = "${pkgs.openssl.out}/lib"
    # cargo 用 git CLI fetch（git insteadOf 把 https→ssh，libgit2 不读 ~/.ssh/config）
    $env.CARGO_NET_GIT_FETCH_WITH_CLI = "true"
  '';
}
