;;; init-completion.el —— 补全栈（minad 现代组合）
;;; -*- lexical-binding: t; -*-
;; 设计：orderless 设全局补全风格 → vertico（minibuffer UI）+ corfu（缓冲区内 UI）共用
;;       marginalia 加注解，consult 提供命令，cape 提供补全后端

;; orderless：空格分隔模糊匹配的补全 style。一次设定，vertico 与 corfu 同时受益
(use-package orderless
  :custom
  (completion-styles '(orderless basic))                                  ; basic 作回退，保证动态补全表可用
  (completion-category-overrides '((file (styles partial-completion))))   ; 文件路径支持通配（~/、*）
  (completion-category-defaults nil))

;; vertico：minibuffer 垂直补全 UI（C-x C-f / M-x / C-x b 等都受益）
(use-package vertico
  :init (vertico-mode)
  :custom (vertico-cycle t))                ; 候选到顶/底循环

;; marginalia：minibuffer 候选注解（函数文档、变量类型、文件大小等）
(use-package marginalia
  :init (marginalia-mode))

;; consult：基于 completing-read 的命令集（搜索/跳转/历史），带实时预览
(use-package consult
  :bind (;; 增强 switch-to-buffer：buffer + 最近文件 + 书签统一列表
         ([remap switch-to-buffer] . consult-buffer)
         ([remap switch-to-buffer-other-window] . consult-buffer-other-window)
         ([remap switch-to-buffer-other-frame] . consult-buffer-other-frame)
         ([remap yank-pop] . consult-yank-pop)     ; yank 历史可视化选择
         ("M-g g" . consult-goto-line)             ; 跳行（带预览）
         ("M-g i" . consult-imenu)                 ; 跳到当前 buffer 的函数/章节定义
         ("M-s l" . consult-line)                  ; 当前行搜索（含预览）
         ("M-s r" . consult-ripgrep)               ; 项目/目录内 ripgrep 搜索
         ("M-s f" . consult-find))                 ; 按文件名查找
  :config
  (setq consult-narrow-key "<")                    ; 收窄前缀（如 consult-buffer 里 < b 仅看 buffer）
  (setq xref-show-xrefs-function #'consult-xref    ; xref（查找引用）也走 consult
        xref-show-definitions-function #'consult-xref))

;; corfu：缓冲区内联补全弹窗（vertico 的 in-buffer 对应物）
(use-package corfu
  :init (global-corfu-mode)
  :custom
  (corfu-cycle t)                ; 候选循环
  (corfu-auto t)                 ; 自动弹窗（输入触发）
  (corfu-auto-delay 0.2)         ; 停顿 0.2s 后弹
  (corfu-auto-prefix 2)          ; 至少 2 字符才触发
  (corfu-preview-current nil)    ; 不预览当前候选（防意外插入）
  :config
  (corfu-popupinfo-mode))        ; 候选旁显示文档 popup（Emacs 29+ 扩展）

;; cape：补全后端（capf）扩展，给 corfu 喂更多候选来源
(use-package cape
  :init
  (add-to-list 'completion-at-point-functions #'cape-file)     ; 文件名补全
  (add-to-list 'completion-at-point-functions #'cape-dabbrev)  ; 缓冲区内词补全（M-/ 同源）
  (add-to-list 'completion-at-point-functions #'cape-elisp-block))

;; embark：在任意"目标"（symbol / 文件 / URL / buffer / S-exp / 候选）上执行上下文动作
;; 与 vertico / corfu / minibuffer 无缝集成——光标处或当前候选上按 C-. 弹动作菜单
(use-package embark
  :bind (("C-." . embark-act)                       ; 主入口：按对象类型弹动作菜单
         ("C-h B" . embark-bindings))               ; 大写 B：浏览按键（含 embark 动作）
  :config
  (setq prefix-help-command #'embark-prefix-help-command)) ; 按前缀键后 ? 用 embark 展示后续键

;; embark-consult：让 embark 能把 consult 的搜索结果导出到独立 buffer（可批量编辑）
(use-package embark-consult
  :after (embark consult)
  :hook (embark-collect-mode . consult-preview-mode)) ; 导出 buffer 保留 consult 实时预览

;; 补全相关全局设置（corfu 官方 README 推荐）
(setq tab-always-indent 'complete                          ; TAB 先缩进，再触发补全
      read-extended-command-predicate                      ; M-x 隐藏不适用当前 mode 的命令
      #'command-completion-default-include-p)
(when (>= emacs-major-version 30)
  (setq text-mode-ispell-word-completion nil))             ; Emacs 30+：关文本模式 ispell 补全干扰
