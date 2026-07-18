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
    mdbook            # 主程序：SUMMARY.md 驱动，mdbook build/serve
    mdbook-toc        # 内联目录（{{#toc}}）
    mdbook-pagetoc    # 侧边栏浮动目录（看长文必备）
    mdbook-mermaid    # Mermaid 流程图代码块
    mdbook-admonish   # Material 风格提示框

    # ── Typst：纯原生排版引擎（替代 LaTeX，输出 PDF）──
    # 注：tinymist LSP 由 nixvim lsp.servers.tinymist.enable 自动注入 nvim PATH（无需装到 home.packages）
    typst             # typst compile book.typ → book.pdf
  ];
}
