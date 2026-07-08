# filepath: ~/nixos-config/users/fww/editors/emacs/default.nix
# Emacs（Pure-GTK / Wayland）—— 现代化配置
#
# 架构（关注点分离）：
#   - 本文件（Nix）：装包（extraPackages 编辑器包 + home.packages 语言服务器）+ source 各 .el 配置
#   - early-init.el：frame 创建前执行（性能/启动屏/frame 装饰）
#   - init.el：用户主初始化入口，按序 load init-*.el 子模块
#       · init-basics.el     文件/编辑/滚动/UI/历史/窗口/scratch/行号
#       · init-completion.el 补全栈（orderless/vertico/marginalia/consult/corfu/cape/embark）
#       · init-treesit.el    tree-sitter grammar 路径（nix 注入，由 ts-grammars 生成）
#       · init-dev.el        magit/which-key/helpful/vundo/treesit-auto/apheleia/popper/视觉
#       · init-lsp.el        eglot（LSP）
#       · init-ai.el         gptel（LLM 客户端，zhipu 后端）
#   - ts-grammars（let 绑定）：显式列 14 语言的 tree-sitter grammar，nix 预编译 .so
#     treesit-grammars 只是 linkFarm（无自动注册），emacs 经 treesit-extra-load-path 发现
#
# 不用 HM 的 extraConfig（→ default.el，有 user-emacs-directory 解析歧义，且 inhibit-startup-screen 在其中无效）
# Emacs 启动顺序：early-init.el → site-start.el → init.el → default.el（Stylix 注入主题的 default.el 除外）
{ pkgs, ... }:

let
  # ── tree-sitter grammar 与 mode 的关系 ──
  # grammar（.so 解析器）：吃源码吐语法树，通用、与编辑器无关；下列即各语言 grammar
  # mode（.el 主模式）：消费 grammar，给 Emacs 做高亮/缩进/imenu； -ts-mode 后缀即基于此
  #
  # Python/C/Rust/Go/Zig/...：Emacs 29+ 内置了对应 -ts-mode（python-ts-mode 等），【只需 grammar】
  # Nix：Emacs 不内置 nix-ts-mode，【grammar 在此 + mode 在下方 extraPackages 的 nix-ts-mode】
  ts-grammars = pkgs.emacs.pkgs.treesit-grammars.with-grammars (p: [
    p.tree-sitter-nix           # Nix
    p.tree-sitter-python        # Python
    p.tree-sitter-rust          # Rust
    p.tree-sitter-go            # Go
    p.tree-sitter-c             # C
    p.tree-sitter-cpp           # C++
    p.tree-sitter-zig           # Zig
    p.tree-sitter-toml          # TOML
    p.tree-sitter-json          # JSON
    p.tree-sitter-yaml          # YAML
    p.tree-sitter-markdown      # Markdown
    p.tree-sitter-typescript    # TypeScript
    p.tree-sitter-tsx           # TSX
    p.tree-sitter-javascript    # JavaScript
  ]);
in
{
  programs.emacs = {
    enable = true;
    # pgtk 构建：Wayland 原生、不走 XWayland，配合 niri
    package = pkgs.emacs-pgtk;

    # 包由 nix 声明式安装（可复现）；init 里 use-package 的 :ensure 因此可省略
    extraPackages = epkgs: with epkgs; [
      # 补全栈（minad 系 + embark 上下文动作）
      vertico orderless marginalia consult corfu cape
      embark embark-consult
      # Git
      magit
      # 编辑 / 发现 / undo
      which-key helpful vundo
      # 格式化（保存时；外部 formatter 二进制见 home.packages）
      apheleia
      # tree-sitter 模式管理（grammar 由 ts-grammars 提供，不靠 treesit-auto 装）
      treesit-auto
      nix-ts-mode        # Nix 的 tree-sitter 主模式（Emacs 不内置，单独装；grammar 见 ts-grammars）
      # AI（LLM 客户端，后端配置见 init-ai.el）
      gptel
      # 弹窗 buffer 管理（*Help* / *Messages* / compilation 等一键显隐）
      popper
      # 状态栏
      nerd-icons doom-modeline
      # 视觉
      rainbow-delimiters
    ];
  };

  # Emacs daemon（systemd user 服务）——emacsclient 连常驻 daemon，秒开、不阻塞终端
  # daemon 经登录 shell 启动 → PATH 含 HM profile → apheleia 的 formatter / eglot 的 LSP server 都能找到
  # socketActivation：懒启动，首次 emacsclient 才经 systemd socket 拉起 daemon（省空闲内存）
  services.emacs = {
    enable = true;
    client.enable = true;            # 生成 emacsclient desktop 项
    socketActivation.enable = true;  # 懒启动（关掉则登录时 eager 常驻）
    # 不设 defaultEditor：EDITOR 已在 wrappers/hm.nix 设为 nvim，此处不覆盖
  };

  # 语言服务器（LSP server）——独立二进制，放 home.packages 而非 extraPackages；eglot 自动调用
  # 例外：rust-analyzer 由 fenix 工具链提供（见 development.nix home.packages），不在此——fenix latest.toolchain 已含 rust-analyzer 组件
  home.packages = with pkgs; [
    nil                            # Nix
    pyright                        # Python（提供 pyright-langserver）
    gopls                          # Go
    clang-tools                    # C/C++（提供 clangd）
    zls                            # Zig
    taplo                          # TOML
    marksman                       # Markdown
    typescript-language-server     # TypeScript / JavaScript
    vscode-langservers-extracted   # JSON / CSS / HTML
    yaml-language-server           # YAML
    # 格式化器（apheleia 保存时调用；clang-format 来自 clang-tools、taplo 已在上方 LSP 列）
    nixfmt                         # Nix
    ruff                           # Python（ruff format）
    prettier                       # JS / TS / JSON / YAML / Markdown / CSS
    # rustfmt 不在此：fenix 工具链（见 development.nix）已提供 rustfmt / cargo-fmt
    # 字体（doom-modeline 图标用）
    nerd-fonts.symbols-only        # Symbols Nerd Font Mono（图标字形回退字体）
  ];

  # elisp 配置：源引用同目录 .el 文件（改 .el 后 nix switch 生效；elisp 享语法高亮/工具支持）
  xdg.configFile."emacs/early-init.el".source = ./early-init.el;
  xdg.configFile."emacs/init.el".source = ./init.el;
  xdg.configFile."emacs/init-basics.el".source = ./init-basics.el;
  xdg.configFile."emacs/init-completion.el".source = ./init-completion.el;
  xdg.configFile."emacs/init-dev.el".source = ./init-dev.el;
  xdg.configFile."emacs/init-lsp.el".source = ./init-lsp.el;
  xdg.configFile."emacs/init-ai.el".source = ./init-ai.el;

  # tree-sitter grammar 路径注入（nix 把 ts-grammars 的 lib 写进 .el）
  # treesit-grammars 是 linkFarm 无自动注册，需显式加到 treesit-extra-load-path 才能发现 .so
  # 字符串引用 ${ts-grammars} 即让 nix 把该 derivation 纳入闭包，GC 安全
  xdg.configFile."emacs/init-treesit.el".text = ''
    ;;; init-treesit.el —— tree-sitter grammar 路径（nix 注入）
    ;;; -*- lexical-binding: t; -*-
    (with-eval-after-load 'treesit
      (add-to-list 'treesit-extra-load-path "${ts-grammars}/lib"))
  '';
}
