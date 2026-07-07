# filepath: ~/nixos-config/users/fww/development/default.nix
# 开发环境：按【语言生态 / 编程范式】语义域拆分，每域一文件
#
# ── 分类标准 ──
# 拆分维度 = 语言生态 / 编程范式（problem domain），【不是】编译器名 / 运行时名。
#   ✅ rust.nix     = Rust 语言生态（fenix 只是该域的工具提供者）
#   ✅ js.nix       = JavaScript/TypeScript 生态（nodejs + bun 同域，不拆 bun.nix / node.nix）
#   ✅ c-cpp.nix    = C / C++ 语言生态（gcc 是该域编译器）
#   ✅ datalog.nix  = Datalog / 逻辑编程范式（souffle 是该范式编译器，不叫 souffle.nix）
#   ✅ lean.nix     = Lean 定理证明生态（依赖类型范式）
#   ✅ assembly.nix = 汇编语言域（nasm/gas/fasm 等汇编器归此，不叫 nasm.nix）
#   ❌ bun.nix / souffle.nix / nasm.nix = 反例：按单一工具/运行时拆，碎片化、无语义
#
# ── 本文件（default.nix）──
# 纯聚合入口：只 imports 各语义域文件 + 阐明分类标准，不在此放任何包。
# 工具一律归其所属语言域（含 gcc → c-cpp.nix）。
# 跨域构建依赖不改变归属：如 Rust 借 c-cpp.nix 的 gcc 作 cc linker —— 各域工具都上 PATH，互相可用。
#
# ── shell 环境变量归属 ──
# nushell extraEnv 现整体在 rust.nix：其每一行（openssl 定位 / cargo PATH / LD_LIBRARY_PATH）
# 都只服务 Rust 域（nodejs/bun 自带 openssl、zig 自含工具链、lean4/souffle 预编译均不需这些）。
# LSP：lean 内置（lean --server）、rust-analyzer 随 fenix 上 PATH；nvim/emacs/opencode 走 PATH 复用
{
  ...
}:

{
  imports = [
    ./rust.nix
    ./js.nix
    ./zig.nix
    ./c-cpp.nix
    ./lean.nix
    ./datalog.nix
    ./assembly.nix
  ];
}
