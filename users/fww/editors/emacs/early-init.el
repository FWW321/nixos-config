;;; early-init.el —— Emacs 27+ 最早执行的初始化文件（在 GUI frame 创建之前）
;;; -*- lexical-binding: t; -*-

;; S-表达式（S-expression，符号表达式）：Lisp 系语言的基本语法单元
;; 形如 (操作符 操作数1 操作数2 ...) 的圆括号列表
;; 求值规则：第一个元素决定动作（函数调用 / 特殊形式 / 宏），其余依次作为参数
;; 退化形态为「原子」——无括号的单个值（数字、字符串、符号、t/nil）

;;; 启动性能
(setq gc-cons-threshold most-positive-fixnum)  ; 启动期临时禁 GC，加速初始化
(setq read-process-output-max (* 1024 1024))   ; 子进程读取上限拉到 1MB（Emacs 27+，LSP/eglot 提速）
;; 启动后恢复 GC 阈值（否则 GC 几乎不跑，内存只增不减）
(add-hook 'emacs-startup-hook
          (lambda () (setq gc-cons-threshold (* 100 1024 1024))))  ; 恢复到 100MB

;;; 启动屏
(setq inhibit-startup-screen t)        ; 跳过启动欢迎界面
;; 跳过后默认进入 *scratch* 缓冲区：
;;   scratch 取自 scratchpad（草稿本/便签），即一次性草稿缓冲区
;;   不关联文件，内容不保存；默认 lisp-interaction-mode，可随手写 elisp 求值（C-x C-e）
;;   要开真正文件用 C-x C-f

;;; frame 装饰：在 frame 创建前关闭，避免先出现再消失的闪烁
(menu-bar-mode -1)                     ; 菜单栏（顶部 File/Edit/...）
(tool-bar-mode -1)                     ; 工具栏（图标按钮排）
(scroll-bar-mode -1)                   ; 滚动条
(modify-all-frames-parameters          ; 移除 Emacs 自绘边框（frame 参数 internal-border-width）
 '((internal-border-width . 0)))       ; 默认 1px，设 0 即无边框
