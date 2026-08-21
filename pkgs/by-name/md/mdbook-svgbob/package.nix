# filepath: ~/nixos-config/pkgs/mdbook-svgbob/default.nix
# mdbook-svgbob：mdBook 预处理器，把 ```bob 代码块里的 ASCII 图替换为 SVG
# nixpkgs 未收录，源码来自 https://github.com/boozook/mdbook-svgbob
#
# 用法：book.toml 加 [preprocessor.svgbob]，Markdown 用 ```bob 代码块
# 注入：通过 flake.nix 的 nixpkgs.overlays 暴露为 pkgs.mdbook-svgbob
{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "mdbook-svgbob";
  version = "0.3.1";

  src = fetchFromGitHub {
    owner = "boozook";
    repo = "mdbook-svgbob";
    rev = "v${version}";
    hash = "sha256-MBFdm0zoTVQjPK8kemYxQUtHivIYRWKgQcJE3lVWPsM=";
  };

  cargoHash = "sha256-T4sju92+BgfvE83v4DjL19BkQQJkz3n/me//J79QyeM=";

  meta = {
    description = "SvgBob mdbook preprocessor which swaps code-blocks with neat SVG";
    homepage = "https://github.com/boozook/mdbook-svgbob";
    license = lib.licenses.mpl20;
    mainProgram = "mdbook-svgbob";
  };
}
