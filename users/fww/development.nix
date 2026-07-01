# filepath: ~/nixos-config/users/fww/development.nix
# 开发环境：语言工具链 + Android SDK 集中安装
# LSP 由 opencode 自动下载、nvim 自行安装，此处不再放 LSP
# makepad 编译 SDK 由 cargo-makepad 自管（install-toolchain 下载到项目目录）
# 环境变量靠 nushell extraEnv 设置 → 子进程（opencode/bash/工具）自动继承
{
  pkgs,
  lib,
  ...
}:

let
  # ── Android SDK 组合（全局，AVD 模拟器 + adb + NDK）──
  # QEMU+KVM 加速，与 GPU 厂商无关（NVIDIA 也可用）
  # 前置条件：当前用户在 kvm 组（见 modules/system/users.nix）
  # 版本不指定 → platform-tools / cmdline-tools / system-image 全部取 nixpkgs 最新
  # 编译用 SDK（build-tools/platforms）由 cargo-makepad 自管（项目目录）
  androidComposition = pkgs.androidenv.composeAndroidPackages {
    includeEmulator = true;
    includeSystemImages = true;
    # android-37 尚无 system-image（nixpkgs repo.json 未收录），用 android-36（最新有镜像的稳定版）
    platformVersions = [ "36" ];
    systemImageTypes = [ "default" ]; # 纯 AOSP，无需 Google Services
    abiVersions = [ "x86_64" ]; # 与宿主同架构 → KVM 硬件加速
    includeNDK = true; # NDK（C/C++ 交叉编译）
  };
  androidSdk = androidComposition.androidsdk;
in
{
  home.packages = with pkgs; [
    # ── Rust ──
    # rustup 统一管理所有 Rust 工具链（stable + android targets）
    # cargo-makepad 硬依赖 rustup，工具链由下方 activation script 自动下载
    rustup
    # C 工具链：Rust 编译带原生依赖的 crate（如 makepad-miniz）需要 cc linker
    gcc
    # cargo-makepad 解压 NDK/SDK 调系统 unzip（NixOS 非默认暴露）
    unzip

    # ── JavaScript / TypeScript ──
    nodejs
    bun

    # ── Zig ──
    zig

    # ── Android ──
    # emulator / adb / sdkmanager / avdmanager 的 wrapper
    # AVD 数据放 ~/.android/avd/（Android 默认）
    androidSdk
    jdk21_headless # sdkmanager / avdmanager / Gradle 依赖（复用 androidenv 的传递依赖）
  ];

  # 自动确保 rustup stable + android targets + cargo-makepad 就位且为最新
  # activation 阶段联网（impure），幂等 + 容错（网络失败不阻塞，|| true）
  home.activation.rustToolchain = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    RUSTUP="${pkgs.rustup}/bin/rustup"

    # activation 非交互 shell，需显式设编译/运行环境
    export CARGO_NET_GIT_FETCH_WITH_CLI=true
    export LIBRARY_PATH="${pkgs.openssl.out}/lib"
    export LD_LIBRARY_PATH="${pkgs.openssl.out}/lib"
    export OPENSSL_DIR="${pkgs.openssl.out}"
    export OPENSSL_LIB_DIR="${pkgs.openssl.out}/lib"
    export OPENSSL_INCLUDE_DIR="${pkgs.openssl.dev}/include"

    # 1. Rust stable + android targets（对齐 cargo-makepad dev 分支）
    $RUSTUP install stable || true
    $RUSTUP default stable 2>/dev/null || true
    for target in aarch64-linux-android x86_64-linux-android; do
      $RUSTUP target list --installed --toolchain stable 2>/dev/null | grep -q "$target" \
        || $RUSTUP target add "$target" --toolchain stable || true
    done

    # 2. cargo-makepad（未装就装，已装且 makepad dev 有新提交才重编译）
    $RUSTUP run stable cargo install cargo-makepad \
      --git https://github.com/makepad/makepad \
      --locked || true
  '';

  # nushell extraEnv：设置后所有子进程（opencode / bash / 工具）自动继承
  programs.nushell.extraEnv = ''
    $env.PATH = ($env.PATH | prepend $"($env.HOME)/.cargo/bin")
    # openssl 编译期定位（openssl-sys crate + cc 链接器读，NixOS 不暴露 openssl）
    $env.OPENSSL_DIR = "${pkgs.openssl.out}"
    $env.OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib"
    $env.OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include"
    $env.LIBRARY_PATH = "${pkgs.openssl.out}/lib"
    # 运行期动态链接器搜索路径
    # cargo install 的二进制 interpreter 是 nix glibc ld（不走 nix-ld），需要此变量找 libssl.so.3
    $env.LD_LIBRARY_PATH = "${pkgs.openssl.out}/lib"
    # cargo 用 git CLI fetch（你的 git insteadOf 把 https→ssh，libgit2 不读 ~/.ssh/config）
    $env.CARGO_NET_GIT_FETCH_WITH_CLI = "true"
    # Android SDK 定位（avdmanager / sdkmanager / emulator / adb 读这些）
    $env.ANDROID_HOME = "${androidSdk}/libexec/android-sdk"
    $env.ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk"
    $env.JAVA_HOME = "${pkgs.jdk21_headless.home}"
  '';
}
