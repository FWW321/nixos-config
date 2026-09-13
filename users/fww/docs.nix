# filepath: ~/nixos-config/users/fww/docs.nix
# 文档/写作域：把 markdown 组合成书（mdBook）+ Typst 排版引擎
#
# ── 归属依据 ──
# mdBook / Typst 都是文档工具，不属于任何语言生态（development/）也不属于桌面应用（desktop/）
# 故独立成域
#
# ── PDF/EPUB 输出策略（2026-09-03 定稿，选型过程见包内注释）──
# mdbook build 一次多输出：HTML(内置) + PDF(mdbook-pdf 打印 print.html，chromium
# 万能渲染，generate-document-outline 书签) + EPUB(mdbook-epub，喂阅读软件)。
# typst/LaTeX 路线在真实书上全数阵亡：mdbook-typst-pdf/pandoc+typst 死于标题
# 上下标字符(f₂/n²，typst label 语法拒收)，pandoc+tectonic 死于 SVG 需 inkscape。
# 书仓库 book.toml 要点：katex renderers=["html","epub"](print.html 已含渲染
# 结果，epub 透传 MathML)；mermaid/svgbob renderers=["html"](pdf 打印的
# print.html 已含其产物，epub 端保留代码块)。
# 独立 typst 文档仍由 typst CLI 承担：typst compile book.typ → book.pdf
{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    # ── mdBook：Markdown → HTML 书 ──
    # mdbook 0.5 已内置 admonitions（GFM `> [!NOTE]` 风格）+ sidebar heading nav（页面侧栏目录）
    # 不再需要 mdbook-pagetoc（被 PR #2822 取代）/ mdbook-admonish（被 PR #2851 取代，且 issue #233 实测不兼容 0.5）
    mdbook # 主程序：SUMMARY.md 驱动，mdbook build/serve
    mdbook-toc # 内联目录（`<!-- toc -->` 标记 → 当前页章节目录）
    mdbook-mermaid # Mermaid 流程图代码块（mdbook 无内置，仍需要）
    mdbook-svgbob # ASCII 图表代码块 → SVG（nixpkgs 未收录，源码构建：见 pkgs/mdbook-svgbob/）
    mdbook-katex # LaTeX 数学公式 → 构建时渲染成静态 HTML(nixpkgs 0.10 已兼容 mdbook 0.5,自建包已删)
    # ↓ 输出后端。PDF=mdbook-pdf(打印 html 的 print.html,chromium 万能渲染:SVG/
    # katex数学/Unicode标题全吃+generate-document-outline 书签;典型 1853 页/5min)
    # 选型记录:mdbook-typst-pdf 与 pandoc+typst 双双死于标题上下标字符(f₂/n²,
    # typst label 语法拒收),pandoc+tectonic 死于 SVG 需 inkscape——包已移除,勿复活
    mdbook-pdf # [output.pdf] → book/pdf/output.pdf(nixpkgs,需 chromium 在 PATH)
    mdbook-epub # [output.epub] → book/epub/*.epub(覆盖 nixpkgs 0.4.37 旧协议版)

    # ── Typst：纯原生排版引擎（替代 LaTeX，输出 PDF）──
    # 注：tinymist LSP 由 nixvim lsp.servers.tinymist.enable 自动注入 nvim PATH（无需装到 home.packages）
    typst # typst compile book.typ → book.pdf
  ];
}
