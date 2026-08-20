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
  mm = common.providers.minimax;

  # dsh 模型行:中立字段 → dsh catalog 条目键(maxOutput → maxTokens;
  # supportsVision → input 模态声明)。input 语义不对称:低报 = 附件期
  # 早拒(便宜),高报 = provider 中途拒且会话卡死 —— vision=false 时
  # 省略(回落 [ "text" ])而非显式写 [ "text" ],少一个键少一处漂移
  #
  # thinking.anthropic → dsh 行(走 pi-ai forceAdaptiveThinking 路径,
  # compat 必给:缺省走 budget 路径 = type:enabled+固定 1024 预算,
  # 档位全 placebo)。该路径 wire = thinking.type=adaptive +
  # output_config.effort=<值>,off=null 不发思考参数。翻译规则:
  #   档名 on → high:中立层二值档名,dsh 档名集固定(off/minimal/low/
  #     medium/high/xhigh/max),on 映射 high 呈现单开档(off/high 二选);
  #     键名不翻会被物化静默丢弃 → "off 外至少一档"校验炸(实测踩过)
  #   值 disabled → "low":官方转换表 disabled→low,行为等价(该路径无
  #     type 槽位可发 disabled;仅 glm 触发,MiniMax off 走 null)
  #   值 adaptive → "high":占位 effort(端点忽略)
  toDshThinking = t:
    lib.listToAttrs (map
      (name:
        let wire = t.levels.${name}; in
        {
          name = if name == "on" then "high" else name;
          value =
            if wire == "disabled" then "low"
            else if wire == "adaptive" then "high"
            else wire;
        })
      (builtins.attrNames t.levels));

  toDshModel = id: m:
    { inherit id; }
    // lib.optionalAttrs (m ? contextWindow) { inherit (m) contextWindow; }
    // lib.optionalAttrs (m ? maxOutput) { maxTokens = m.maxOutput; }
    // lib.optionalAttrs (m.thinking.anthropic != null) {
      reasoningEfforts = toDshThinking m.thinking.anthropic;
      compat.forceAdaptiveThinking = true;
    }
    // lib.optionalAttrs (m.supportsVision or false) {
      input = [ "text" "image" ];
    };
in
{
  programs.dsh = {
    # 手声明路由:zhipu coding plan 的 anthropic 兼容端点(dsh 走
    # anthropic-messages 线协议,同 Claude Code;模型元数据不进 Nix 之外的
    # 任何 catalog —— common/providers.nix 是唯一数据源)。
    # id 是本地路由键(zai-ai-cn),与上游 pi-ai 内置的 zai-coding-cn
    # (coding paas 端点,不同协议)无关;改名后 settings.yaml 旧键
    # zhipu-coding-plan 会残留(yq merge 只覆盖不删),须一次性手清
    providers."zai-ai-cn" = {
      apiKeyEnv = "ZHIPU_API_KEY";
      secretFile = p.apiKey.secretFile;  # 声明内 env 桥,与消费者同处一行
      api = "anthropic-messages";
      baseURL = p.endpoints.anthropic;
      models = lib.mapAttrsToList toDshModel p.models;
    };

    # minimax token plan:anthropic 兼容端点(官方推荐,prompt cache +
    # adaptive thinking;端点/模型元数据唯一来源 = common/providers.nix)
    providers.minimax = {
      apiKeyEnv = "MINIMAX_API_KEY";
      secretFile = mm.apiKey.secretFile;  # sops 同源,OD/agent 侧共用
      api = "anthropic-messages";
      baseURL = mm.endpoints.anthropic;
      models = lib.mapAttrsToList toDshModel mm.models;
    };

    # 默认模型选择(typed;渲染进 agent-default-model 命名空间段,
    # schema 实测于源码)。推理档 = 中立层 thinking.anthropic.default
    # (zhipu anthropic 端点省略参数时即 max 档,声明与端点默认一致)
    defaultModel = {
      provider = "zai-ai-cn";
      model = p.defaultModel;
      reasoningEffort = p.models.${p.defaultModel}.thinking.anthropic.default;
    };
  };
}
