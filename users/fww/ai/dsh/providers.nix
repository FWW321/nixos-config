# filepath: ~/nixos-config/users/fww/ai/dsh/providers.nix
# LLM 供应商:ai/common 中立 provider 数据 → dsh llm-pi-ai 用户层路由
# 落盘面(实测 rc.5 源码):settings.yaml `llm-pi-ai.providers` 段 +
# `agent-default-model` 段(上游无 `models` 命名空间)
# 凭据:secretFile 声明内桥(nixdsh)—— wrapper 现读 /run/secrets 物化
# env,CLI/TUI/headless/web 服务统一,无 bash/EnvironmentFile 外部桥
{ config, pkgs, lib, inputs, ... }:

let
  common = import ../common { inherit pkgs inputs lib config; };

  p = common.providers.zhipu;

  # dsh 模型行:中立字段 → dsh catalog 条目键(maxOutput → maxTokens;
  # supportsVision → input 模态声明)。input 语义不对称:低报 = 附件期
  # 早拒(便宜),高报 = provider 中途拒且会话卡死 —— vision=false 时
  # 省略(回落 [ "text" ])而非显式写 [ "text" ],少一个键少一处漂移
  toDshModel = id: m:
    { inherit id; }
    // lib.optionalAttrs (m ? contextWindow) { inherit (m) contextWindow; }
    // lib.optionalAttrs (m ? maxOutput) { maxTokens = m.maxOutput; }
    // lib.optionalAttrs (m.supportsVision or false) {
      input = [ "text" "image" ];
    };
in
{
  programs.dsh = {
    # 手声明路由:zhipu coding plan 的 anthropic 兼容端点(dsh 走
    # anthropic-messages 线协议,同 Claude Code;模型元数据不进 Nix 之外的
    # 任何 catalog —— common/providers.nix 是唯一数据源)
    providers."zhipu-coding-plan" = {
      apiKeyEnv = "ZHIPU_API_KEY";
      secretFile = p.apiKey.secretFile;  # 声明内 env 桥,与消费者同处一行
      api = "anthropic-messages";
      baseURL = p.endpoints.anthropic;
      models = lib.mapAttrsToList toDshModel p.models;
    };

    # 默认模型选择(typed;渲染进 agent-default-model 命名空间段,
    # schema 实测于源码)
    defaultModel = {
      provider = "zhipu-coding-plan";
      model = p.defaultModel;
    };
  };
}
