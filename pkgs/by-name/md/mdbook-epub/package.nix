# filepath: ~/nixos-config/pkgs/by-name/md/mdbook-epub/package.nix
# mdbook-epub：mdBook 后端，markdown 书 → EPUB（电纸书/阅读软件最佳格式，
# 目录走原生 nav/NCX，字号重排自适应）
#
# 为何覆盖而非直用 nixpkgs：nixpkgs 的 mdbook-epub 停在 0.4.37（mdBook 0.4
# 时代产物），与本机 mdBook 0.5 的 RenderContext 协议（book.sections→items）
# 不兼容；crates.io 0.5.4 起改用 mdbook-core/mdbook-renderer 0.5.x，协议对齐。
# 本 overlay 定义同名属性即遮蔽 nixpkgs 版本。
#
# 用法：book.toml 加 [output.epub]，mdbook build → book/epub/<书名>.epub
# 可选：cover-image / additional-css / epub-version = 3
# 注入：pkgs/default.nix overlay → home users/fww/docs.nix
{
  lib,
  rustPlatform,
  fetchCrate,
}:

rustPlatform.buildRustPackage rec {
  pname = "mdbook-epub";
  version = "0.5.4";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-Dskgi8qhIJsqOgBiTWinBMq4NC+gpWhfu8Hu+P3iI4s=";
  };

  cargoHash = "sha256-HAq6jCFvmtFhNDu6KZvdUk2dBA74Cg4eioM7FSo9wTo=";

  # 49 测试中 2 个需真实网络(下载 cloudflare 头像/图标),沙箱必挂;其余 47 过
  doCheck = false;

  meta = {
    description = "mdBook backend for generating an e-book in the EPUB format (mdBook 0.5 compatible)";
    homepage = "https://github.com/Michael-F-Bryan/mdbook-epub";
    license = lib.licenses.mpl20;
    mainProgram = "mdbook-epub";
  };
}
