# filepath: ~/nixos-config/pkgs/mdbook-katex/default.nix
# mdbook-katex：mdBook 预处理器，构建时用 KaTeX 把 LaTeX 数学公式渲染成静态 HTML（无客户端 JS）
# nixpkgs 仅 0.9.4，不支持 mdbook 0.5（issue #130：missing field `sections`）
# 故源码构建 0.10.0（commit #131：Use mdbook v0.5.1），源码来自 https://github.com/lzanini/mdbook-katex
#
# 用法：book.toml 加 [preprocessor.katex]，Markdown 用 $...$（行内）/ $$...$$（块）
# 注入：通过 flake.nix 的 nixpkgs.overlays 暴露为 pkgs.mdbook-katex
{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "mdbook-katex";
  version = "0.10.0";

  src = fetchFromGitHub {
    owner = "lzanini";
    repo = "mdbook-katex";
    rev = "v${version}";
    hash = "sha256-bS8SUzpTqQNYKeGPBf1QD4/AL0TWn3NE4M7A8WLEjUE=";
  };

  cargoHash = "sha256-YqQ8Uai2mCG+1X/TmWJPszLYumOjF455Aa5WldgGXF0=";

  meta = {
    description = "Preprocessor for mdbook, rendering LaTeX equations to HTML at build time";
    homepage = "https://github.com/lzanini/mdbook-katex";
    license = lib.licenses.mit;
    mainProgram = "mdbook-katex";
  };
}
