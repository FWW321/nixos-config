;;; init-basics.el —— 编辑器基础选项
;;; -*- lexical-binding: t; -*-

;;; 文件处理
(setq make-backup-files nil       ; 不生成 file~（备份文件）
      auto-save-default nil       ; 不生成 #file#（自动保存）
      create-lockfiles nil        ; 不生成 .#file（互斥锁，防止多端同时编辑）
      require-final-newline t)    ; 文件末尾自动留换行（POSIX 规范）

;;; 编辑行为
(delete-selection-mode 1)             ; 选中后输入即替换（现代编辑器习惯）
(electric-pair-mode 1)                ; 自动配对括号/引号
(setq-default tab-width 4             ; Tab 显示宽度
              indent-tabs-mode nil)   ; 用空格缩进，不用 Tab（团队协作一致）
(show-paren-mode 1)                   ; 高亮匹配的括号（内置）
(save-place-mode 1)                   ; 记住每个文件上次光标位置
(global-auto-revert-mode 1)           ; 文件在外部被改时自动重载
(setq-default fill-column 80)         ; 填充列（fill-paragraph 对齐宽度）

;;; 滚动
(setq scroll-conservatively 101        ; 光标尽量不出屏（禁中心化重定位）
      scroll-preserve-screen-position t ; 滚动时光标保持屏位置
      scroll-margin 3)                 ; 上下留 3 行边距
(pixel-scroll-precision-mode 1)        ; 像素级平滑滚动（Emacs 29+）

;;; UI 反馈
(setq ring-bell-function 'ignore) ; 关蜂鸣/闪烁报警
(setq use-short-answers t)        ; y/n 替代 yes/no（Emacs 28+）
(column-number-mode 1)            ; mode-line 显示列号
(context-menu-mode 1)             ; 右键上下文菜单（Emacs 28+）
(setq echo-keystrokes 0.02)       ; 不完整按键序列的提示延迟（秒）

;;; 历史 / minibuffer
(savehist-mode 1)                        ; 持久化 minibuffer 历史
(recentf-mode 1)                         ; 记住最近打开文件列表
(setq history-length 100
      history-delete-duplicates t)

;;; 窗口管理
(winner-mode 1)   ; 窗口布局可撤销/重做：C-c ← 撤销，C-c → 重做

;;; scratch 缓冲区
(setq initial-scratch-message nil)          ; scratch 不留欢迎注释
(setq initial-major-mode 'fundamental-mode) ; scratch 默认模式（默认 lisp-interaction-mode）

;;; 行号
(setq display-line-numbers-type 'relative)  ; 相对行号：基于光标行，上下递增（vim 风格）
(global-display-line-numbers-mode 1)        ; 全局开启行号显示
