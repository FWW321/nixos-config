# filepath: ~/nixos-config/users/fww/development/rust.nix
# Rust 语言生态：fenix nightly 纯 nix 工具链 + cargo/openssl 运行环境
#
# - 工具链：fenix latest.toolchain = 最新 nightly 全套（rustc/cargo/rustfmt/clippy/rust-analyzer/rust-src）
#   声明式、可复现；删 home.packages 行即卸载，无 ~/.rustup 残留
#   rust-analyzer 随工具链上 PATH → nvim(native lsp) / emacs(eglot) / opencode 直接复用
# - cc linker（gcc）不在此：gcc 是 C/C++ 域编译器，见 c-cpp.nix；Rust 借之作 linker（跨域构建依赖）
# - nushell extraEnv 整体在此：以下每行都只服务 Rust 域
#   · openssl_*：openssl-sys crate 编译期定位（NixOS 不暴露 openssl）
#   · LD_LIBRARY_PATH：cargo install 二进制 interpreter=nix glibc ld（不走 nix-ld），需此找 libssl.so.3
#   · CARGO_NET_GIT_FETCH_WITH_CLI：git insteadOf https→ssh，libgit2 不读 ~/.ssh/config
#   (nodejs/bun 自带 openssl、zig 自含 cc、lean4/souffle 预编译 → 均不依赖这些)
{
  pkgs,
  inputs,
  ...
}:

{
  home.packages = with pkgs; [
    inputs.fenix.packages.${pkgs.stdenv.hostPlatform.system}.latest.toolchain
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
