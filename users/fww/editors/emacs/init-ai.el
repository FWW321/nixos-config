;;; init-ai.el —— gptel（Emacs 内 LLM 客户端）
;;; -*- lexical-binding: t; -*-
;; 供应商 = zhipu（镜像 users/fww/ai/common/providers.nix 的 zhipu 配置）
;;   endpoint（coding，OpenAI 兼容）: https://open.bigmodel.cn/api/coding/paas/v4
;;   models: glm-5.2 / glm-5.1
;;   api key 从 /run/secrets/zhipu_api_key 读（sops 管理；系统契约见 modules/system/secrets.nix）

(require 'subr-x)                                  ; string-trim

(use-package gptel
  :bind ("C-c l" . gptel-menu)                     ; gptel transient 菜单（发消息 / 选模型 / 重定向…）
  :config
  ;; 注册 zhipu 为 OpenAI 兼容后端，并设为默认（gptel-make-openai 返回 backend 对象）
  (setq gptel-backend
        (gptel-make-openai "Zhipu"
          :host "open.bigmodel.cn"
          :endpoint "/api/coding/paas/v4/chat/completions"
          :stream t
          :key (lambda ()
                 (if (file-readable-p "/run/secrets/zhipu_api_key")
                     (string-trim
                      (with-temp-buffer
                        (insert-file-contents "/run/secrets/zhipu_api_key")
                        (buffer-string)))
                   ""))                            ; secret 未就绪时返回空（gptel 报 auth 错，不崩 emacs）
          :models '("glm-5.2" "glm-5.1"))
        gptel-model "glm-5.2"                      ; 默认模型
        gptel-default-mode 'org-mode))             ; 聊天 buffer 用 org（折叠 / 编辑 / 分叉对话）
