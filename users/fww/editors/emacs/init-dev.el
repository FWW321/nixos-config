;;; init-dev.el —— 开发工具：Git / 按键发现 / 帮助 / undo / tree-sitter / 视觉
;;; -*- lexical-binding: t; -*-

;;; Git
(use-package magit
  :bind ("C-x g" . magit-status)                           ; magit 主界面
  :custom (magit-display-buffer-function
            #'magit-display-buffer-same-window-except-diff-v1)) ; 同窗口显示，diff 另开

;;; GitHub issues / PRs（forge：magit 内管 GitHub）
(use-package forge
  :after magit
  :config
  ;; GitHub token 从 sops secret 读（/run/secrets/github_token）
  ;; 绕过 auth-source：advice ghub--token 短路返回 token，无需预设 github.user
  ;;   ghub 拿到 token 后反查 /user API 自动获取用户名
  (when (file-readable-p "/run/secrets/github_token")
    (advice-add 'ghub--token :before-until
                (lambda (host &rest _)
                  (when (string-prefix-p "api.github.com" (or host ""))
                    (string-trim
                     (with-temp-buffer
                       (insert-file-contents "/run/secrets/github_token")
                       (buffer-string))))))))

;;; 按键发现
(use-package which-key
  :init (which-key-mode)                                   ; 全局开启
  :custom (which-key-idle-delay 0.3))                      ; 按半截键停 0.3s 后弹后续可选项

;;; 帮助增强
(use-package helpful
  :bind (([remap describe-function] . helpful-callable)    ; C-h f：函数/宏/特殊形式，带源码
         ([remap describe-variable] . helpful-variable)    ; C-h v：变量，带来源与引用
         ([remap describe-key] . helpful-key)              ; C-h k：按键
         ([remap describe-command] . helpful-command)))    ; C-h x：命令

;;; 可视化 undo
(use-package vundo
  :bind ("C-x u" . vundo)                                  ; 打开可视化 undo 树
  :config (setq vundo-glyph-theme vundo-unicode-symbols-theme)) ; 用 unicode 符号画树节点

;;; tree-sitter（精确高亮 + 结构感知）
;; grammar 由 nix 的 ts-grammars 提供（见 init-treesit.el 的 treesit-extra-load-path）
(use-package treesit-auto
  :custom (treesit-auto-install nil)                   ; nix 已供 grammar，不联网装（仅用 treesit-auto 管 mode 映射）
  :config
  (treesit-auto-add-to-auto-mode-alist 'all)           ; 自动用 tree-sitter 模式打开支持的文件
  (global-treesit-auto-mode))

(use-package nix-ts-mode                                   ; Nix 的 tree-sitter 模式（比老 nix-mode 准）
  :mode "\\.nix\\'")

;;; 自动格式化（保存时）
;; apheleia：保存时跑外部 formatter，用 RCS diff 回填——【不挪光标位置】
;; formatter 二进制见 default.nix 的 home.packages（nixfmt / ruff / prettier）
;;   rustfmt 由 fenix 工具链提供（development.nix）、clang-format 来自 clang-tools、taplo 已装
;;   clang-format 来自 clang-tools（已装）、taplo 已装；某语言缺 formatter 时自动跳过（不报错）
(use-package apheleia
  :hook (prog-mode . apheleia-mode)                  ; 所有编程模式：保存即格式化
  :config
  ;; 补 NixOS/HM profile 到 exec-path（GUI Emacs 启动时 exec-path 可能未含 profile，导致找不到 formatter）
  (dolist (d (list (expand-file-name ".nix-profile/bin" (getenv "HOME"))
                   (format "/etc/profiles/per-user/%s/bin" (getenv "USER"))))
    (when (file-directory-p d)
      (add-to-list 'exec-path d)
      (setenv "PATH" (concat d path-separator (getenv "PATH"))))))

;;; 弹窗 buffer 管理（popper）
;; 把 *Help*/*Messages*/compilation/grep 等临时 buffer 收为"popup"，一键显隐 / 循环 / echo 跳转
(use-package popper
  :bind (("C-`"   . popper-toggle)                   ; 显/隐最近 popup（前缀：显隐全部）
         ("M-`"   . popper-cycle)                    ; 循环切换 popup
         ("C-M-`" . popper-toggle-type))             ; 当前 buffer 升/降级为 popup
  :init
  (setq popper-reference-buffers                     ; 下列 buffer 自动归为 popup
        '("\\*Messages\\*"
          "\\*Async Shell Command\\*"
          "\\*Completions\\*"
          help-mode                                  ; C-h 帮助
          helpful-mode                               ; helpful 包的增强帮助
          compilation-mode                           ; 编译输出
          occur-mode                                 ; occur 结果
          grep-mode                                  ; rg / grep 结果
          magit-process-mode))                       ; magit 子进程输出
  (popper-mode +1)
  (popper-echo-mode +1))                            ; echo 区显示 popup 列表（数字键跳转）

;;; 状态栏（modeline）
(use-package nerd-icons)                       ; 图标字体支持（doom-modeline 依赖）
(use-package doom-modeline
  :init (doom-modeline-mode 1)                 ; 全局启用
  :custom
  (doom-modeline-height 15)                    ; modeline 高度（像素，紧凑）
  (doom-modeline-bar-width 3)                  ; 左侧色条宽度
  (doom-modeline-icon t)                       ; 显示图标（需 nerd-fonts.symbols-only 字体）
  (doom-modeline-lsp t))                       ; 显示 LSP 状态（配合 eglot）

;;; 视觉
(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))             ; 编程模式：括号按嵌套深度着色
