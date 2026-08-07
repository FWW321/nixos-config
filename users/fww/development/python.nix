# filepath: ~/nixos-config/users/fww/development/python.nix
# Python 语言生态：python3（解释器）
#
# - python3：nixpkgs 默认 CPython（不带版本后缀，跟踪 unstable 当前最新，同 nodejs / gcc / zig 约定）
#   nixpkgs 的 python3 默认剥离 pip —— Python 包统一走 nix 声明式：
#   python3.withPackages (p: [ p.requests p.numpy ])，可复现、GC 安全，由 HM 注入 PATH
#
# ── 不在此 ──
# - pip / uv / virtualenv 等 PyPI 包管理：Python 包统一走 nixpkgs 声明式
#   已收录的直接引（如 mcp.nix 的 ${pkgs.mcp-nixos}/bin/mcp-nixos）；项目内用 python3.withPackages
# - LSP：nvim 用 basedpyright（lsp.nix，nixvim 自动安装）；emacs 用 pyright（emacs/default.nix）
# - 格式化 / lint：ruff 在 nvim（default.nix extraPackages，conform + nvim-lint）与 emacs（default.nix home.packages，apheleia）
# - treesitter：python grammar 在 nvim（treesitter.nix）与 emacs（emacs/default.nix ts-grammars）各自声明
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    python3
  ];
}
