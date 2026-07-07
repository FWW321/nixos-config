;;; init-lsp.el —— LSP（eglot，Emacs 29+ 内置）
;;; -*- lexical-binding: t; -*-
;; eglot = Emacs polyGLOT，连各语言的 LSP server，获得 IDE 能力
;; 复用内建 flymake（诊断）/ xref（跳转）/ eldoc（签名）/ completion-at-point（补全）
;;   → 补全走 corfu，跳转走 consult-xref（init-completion 已设 xref-show-xrefs-function）
;; server 可执行文件见 emacs/default.nix 的 home.packages
;;   例外：rust-analyzer 由 rustup 提供（见 development.nix activation 的 component add）

(use-package eglot
  :hook (;; 各语言 tree-sitter 模式（+ markdown）打开文件即自动连 LSP
         (nix-ts-mode        . eglot-ensure)
         (rust-ts-mode       . eglot-ensure)
         (python-ts-mode     . eglot-ensure)
         (go-ts-mode         . eglot-ensure)
         (c-ts-mode          . eglot-ensure)
         (c++-ts-mode        . eglot-ensure)
         (zig-ts-mode        . eglot-ensure)
         (typescript-ts-mode . eglot-ensure)
         (tsx-ts-mode        . eglot-ensure)
         (js-ts-mode         . eglot-ensure)
         (toml-ts-mode       . eglot-ensure)
         (json-ts-mode       . eglot-ensure)
         (yaml-ts-mode       . eglot-ensure)
         (markdown-mode      . eglot-ensure))
  :custom
  (eglot-autoshutdown t)            ; 管理的 buffer 全关后自动停 server（省资源）
  (eglot-events-buffer-size 0)      ; 不留 *eglot-events* 调试 buffer（默认占内存）
  :config
  ;; 显式指定各 server（不依赖 eglot 版本默认值，更稳）
  (add-to-list 'eglot-server-programs '(nix-ts-mode        . ("nil")))
  (add-to-list 'eglot-server-programs '(python-ts-mode     . ("pyright-langserver" "--stdio")))
  (add-to-list 'eglot-server-programs '(rust-ts-mode       . ("rust-analyzer")))
  (add-to-list 'eglot-server-programs '(go-ts-mode         . ("gopls")))
  (add-to-list 'eglot-server-programs '(c-ts-mode          . ("clangd")))
  (add-to-list 'eglot-server-programs '(c++-ts-mode        . ("clangd")))
  (add-to-list 'eglot-server-programs '(zig-ts-mode        . ("zls")))
  (add-to-list 'eglot-server-programs '(typescript-ts-mode . ("typescript-language-server" "--stdio")))
  (add-to-list 'eglot-server-programs '(tsx-ts-mode        . ("typescript-language-server" "--stdio")))
  (add-to-list 'eglot-server-programs '(js-ts-mode         . ("typescript-language-server" "--stdio")))
  (add-to-list 'eglot-server-programs '(toml-ts-mode       . ("taplo" "lsp")))
  (add-to-list 'eglot-server-programs '(json-ts-mode       . ("vscode-json-language-server" "--stdio")))
  (add-to-list 'eglot-server-programs '(yaml-ts-mode       . ("yaml-language-server" "--stdio")))
  (add-to-list 'eglot-server-programs '(markdown-mode      . ("marksman"))))
