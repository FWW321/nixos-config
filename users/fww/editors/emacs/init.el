;;; init.el —— 用户主初始化入口
;;; -*- lexical-binding: t; -*-
;; lexical-binding 必须为首行（consult 等包的闭包依赖词法绑定——官方 README 强调）

;;; ── use-package：声明式包配置宏（Emacs 29+ 内置）──
;; 把一个包的「加载 + 配置 + 按键 + 懒加载」收拢进一个 S-表达式
;; 关键字：
;;   :ensure     缺包则自动装（nix 用 extraPackages 装包，可省略）
;;   :init       包加载【前】执行的代码（设 require 前必须就绪的变量）
;;   :config     包加载【后】执行的代码（主配置）
;;   :bind       绑定按键（同时声明懒加载）
;;   :hook       挂钩到 mode（同时声明懒加载）
;;   :commands   指定入口命令（触发懒加载）
;;   :mode       匹配文件扩展名时加载
;;   :after X    在 X 之后加载（控制顺序）
;;   :defer N    延迟 N 秒加载
;;   :custom     设置 defcustom 变量
;; 核心价值：懒加载——默认推迟到真正用到（调命令 / 开匹配文件 / 按绑定的键）才载入，启动快
(require 'use-package)

;;; 把配置目录加入 load-path
;; Emacs 默认【不】把 user-emacs-directory 纳入 load-path（实测 load-path 仅含 builtin lisp 目录），
;; 故 (load "init-xxx") 找不到同目录模块——必须显式加入，否则 init 中止、白屏无配置
(add-to-list 'load-path user-emacs-directory)

;;; 按序载入子模块
(load "init-basics")       ; 文件/编辑/滚动/UI/历史/窗口/scratch/行号
(load "init-completion")   ; 补全栈（orderless/vertico/marginalia/consult/corfu/cape）
(load "init-treesit")      ; tree-sitter grammar 路径（nix 注入）
(load "init-dev")          ; magit/which-key/helpful/vundo/treesit-auto/视觉
(load "init-lsp")          ; eglot（LSP）
(load "init-ai")           ; gptel（LLM 客户端，zhipu 后端）

;;; ido-mode（Interactively DO things）：Emacs 22+ 内置 minibuffer 补全增强
;; 开启后 C-x C-f（找文件）、C-x b（切 buffer）边输入边模糊收窄候选，方向键循环选择
;; 是现代补全栈 ivy/counsel、helm、vertico/consult 的前身；启用：(ido-mode 1)
;; 当前未启用（已由 init-completion 的 vertico + consult 栈取代）
