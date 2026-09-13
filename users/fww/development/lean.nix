# filepath: ~/nixos-config/users/fww/development/lean.nix
# Lean 4 生态（依赖类型函数式编程 + 交互式定理证明）
# - lean4：编译器 + lake 构建工具；LSP 内置于 lean（lean --server），无需独立 LSP 包
# - 编辑器：nvim 经 lean.nvim 连接（见 editors/nvim/plugins.nix）；emacs 暂无 lean4-mode（nixpkgs 未收录）
# - 走纯 nix 包（不用 elan）：声明式、可复现；生态版本对齐由项目 lean-toolchain 文件负责
{
  pkgs,
  lib,
  ...
}:

let
  # ⏳ 临时垫片(2026-09-13):lean4 4.30.0 × cmake ≥4.4 构建断裂
  # 根因:上游顶层 CMakeLists.txt 靠遍历 cache vars 的 HELPSTRING 判定
  # "命令行变量"进 CL_ARGS(转发给 stage1/stage2 的 ExternalProject),而
  # cmake 4.4.2(4.3.4→4.4.2,nixpkgs 8/22→9/11)对 CMAKE_INSTALL_PREFIX
  # 的路由掉进只喂 stage0 的 PLATFORM_ARGS 分支 → stage1 以默认 /usr/local
  # configure → install 阶段 "cannot make directory /usr/local/include"。
  # hydra 未建过新工具链组合(cache miss),本地构建必现。
  # 修法:显式把 prefix 追加进 CL_ARGS(单引号防 shell 展开,进文件的
  # 是字面 ${CMAKE_INSTALL_PREFIX},由 cmake 求值期展开)。
  # 拆除条件:上游 lean4 修 CL_ARGS 收集,或 nixpkgs 重写打包落地
  # (PR #537536/#545312 系,cmake-content.json 路线)后删除本 let 块,
  # home.packages 还原为 lean4。
  lean4' = pkgs.lean4.overrideAttrs (
    _finalAttrs: prevAttrs: {
      postPatch = prevAttrs.postPatch + ''
        substituteInPlace CMakeLists.txt \
          --replace-fail 'list(APPEND EXTRA_DEPENDS mimalloc)' 'list(APPEND EXTRA_DEPENDS mimalloc)
        list(APPEND CL_ARGS "-DCMAKE_INSTALL_PREFIX=''${CMAKE_INSTALL_PREFIX}")'
      '';
    }
  );
in
{
  home.packages = [ lean4' ];
}
