# filepath: ~/nixos-config/users/fww/docs.nix
# 文档/写作域：把 markdown 组合成书（mdBook）+ Typst 排版引擎
#
# ── 归属依据 ──
# mdBook / Typst 都是文档工具，不属于任何语言生态（development/）也不属于桌面应用（desktop/）
# 故独立成域
#
# ── PDF 输出策略 ──
# mdbook 只走 HTML 路线（PDF 需引入 Chromium/LaTeX，不划算）
# PDF 需求由 typst 独立承担：写 typst 语法 → typst compile → PDF，纯原生零依赖
{
  pkgs,
  ...
}:

{
  home.packages = with pkgs; [
    # ── mdBook：Markdown → HTML 书 ──
    # mdbook 0.5 已内置 admonitions（GFM `> [!NOTE]` 风格）+ sidebar heading nav（页面侧栏目录）
    # 不再需要 mdbook-pagetoc（被 PR #2822 取代）/ mdbook-admonish（被 PR #2851 取代，且 issue #233 实测不兼容 0.5）
    mdbook            # 主程序：SUMMARY.md 驱动，mdbook build/serve
    mdbook-toc        # 内联目录（`<!-- toc -->` 标记 → 当前页章节目录）
    mdbook-mermaid    # Mermaid 流程图代码块（mdbook 无内置，仍需要）
    mdbook-svgbob     # ASCII 图表代码块 → SVG（nixpkgs 未收录，源码构建：见 pkgs/mdbook-svgbob/）

    # ── Typst：纯原生排版引擎（替代 LaTeX，输出 PDF）──
    # 注：tinymist LSP 由 nixvim lsp.servers.tinymist.enable 自动注入 nvim PATH（无需装到 home.packages）
    typst             # typst compile book.typ → book.pdf
  ];
}
