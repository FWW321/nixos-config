# 模型能力数据来源：opencode models zhipuai-coding-plan --verbose
{
  zhipu = {
    # 各 agent 按自己使用的协议取对应 endpoint
    endpoints = {
      anthropic = "https://open.bigmodel.cn/api/anthropic";        # Claude Code 等
      openai = "https://open.bigmodel.cn/api/coding/paas/v4";       # opencode 等(chat completions)
      responses = "https://open.bigmodel.cn/api/v1";                # codex 等(responses API,见 docs.bigmodel.cn/cn/coding-plan/tool/codex)
    };
    apiKey.secretFile = "/run/secrets/zhipu_api_key";
    models = {
      "glm-5.3" = {
        contextWindow = 1000000;
        maxOutput = 131072;
        supportsVision = false;
        # 思考控制(按端点独立;default = 省略参数时端点行为,官方文档+实测):
        # anthropic(Claude Code 通路): wire = thinking.type=adaptive +
        #   output_config.effort,实档仅 low/high/max;medium→high、xhigh→max
        #   官方自动转换不单列;GLM-5.3 强制思考,disabled 被端点转 low(无法真关)
        #   (2026-08-21 差分实测:low→0 思考块/high 1491 字/max 2333 字)
        # openai(coding paas): wire = thinking.type=enabled + reasoning_effort
        #   (官方 API 文档;2026-08-21 mainland 端点差分实测生效:
        #   low→0 reasoning tokens/max→322,推翻 6 月 z.ai 国际端"无效"
        #   的 glm-for-copilot#7 结论 —— 那是不同端点且可能已修);
        #   GLM-5.3 仅 low/high/max(none/minimal 是 5.2 语义),无 off
        # responses(/api/v1): wire = reasoning.effort(Responses API);
        #   档位同 openai,来源 = 官方 codex 接入文档(codex.nix 同源消费)
        thinking = {
          anthropic = {
            default = "max";
            levels = {
              off = "disabled"; # 端点转 low 轻思考(5.3 不能真关)
              low = "low";
              high = "high";
              max = "max";
            };
          };
          openai = {
            default = "max";
            levels = {
              low = "low";
              high = "high";
              max = "max";
            };
          };
          responses = {
            default = "max";
            levels = {
              low = "low";
              high = "high";
              max = "max";
            };
          };
        };
      };
    };
    defaultModel = "glm-5.3";
    smallModel = "glm-5.3"; # opencode 标题生成等轻任务用(与 defaultModel 同款,5.2 已下线)
  };

  # MiniMax Token Plan(官方名,非 coding plan):订阅 Key(sk-cp- 前缀)与按量 Key 不通用,
  # 仅推理端点可用(models 列表 401);国内域 minimaxi.com,国际版是 minimax.io(勿混)
  # anthropic 端点官方推荐(有 prompt cache 主动缓存,支持 thinking/interleaved thinking,
  # M3 thinking 默认关需 {"type":"adaptive"} 显式开);温度建议 1.0,top_p 默认 0.95
  # 额度:5 小时+周双窗口;maxOutput 128K 出自 models.dev,官方模型表只列 context 1M
  minimax = {
    endpoints = {
      anthropic = "https://api.minimaxi.com/anthropic";           # Claude Code 等
      openai = "https://api.minimaxi.com/v1";                      # opencode 等(chat completions)
      responses = "https://api.minimaxi.com/v1";                   # codex 等(responses API,与 openai 同 base 不同路由,均实测通)
    };
    apiKey.secretFile = "/run/secrets/minimax_api_key";
    models = {
      "MiniMax-M3" = {
        contextWindow = 1000000;
        maxOutput = 128000;
        supportsVision = true;
        # 思考控制(按端点独立;default = 省略参数时端点行为,官方文档):
        # 三端点默认各不相同 —— anthropic 省略=关、openai 省略=开、
        # responses 省略=关(官方三段 Thinking/reasoning 控制原文),
        # 跨端点迁移时最易踩的坑
        # anthropic: adaptive=开/disabled=关;无 effort 档(与 glm 的
        #   output_config.effort 语义不同);Claude Code 内默认开是客户端
        #   行为(Claude Code 主动发参数),裸 SDK 省略即关
        # openai: 另有 reasoning_split 只控输出拆分(reasoning_content/
        #   reasoning_details)不控开关;M2.x 系列不可关(非本路由模型,备注)
        # responses: wire = reasoning.effort;none=关(默认),
        #   minimal/low/medium/high 兼容接收但**不调深度**(纯开关)——
        #   单开档取 low(最弱语义,不虚标深度);effort=none 显式关
        thinking = {
          anthropic = {
            default = "off";
            levels = {
              off = null; # 不发参数 = 关(端点默认)
              on = "adaptive";
            };
          };
          openai = {
            default = "on";
            levels = {
              off = "disabled";
              on = "adaptive";
            };
          };
          responses = {
            default = "off";
            levels = {
              off = "none";
              low = "low"; # 四个开启值等价,low 语义最弱不虚标
            };
          };
        };
      };
    };
    defaultModel = "MiniMax-M3";
  };

  # SiliconFlow(硅基流动):OpenAI 兼容平台,代金券抵扣
  # 唯一消费者 jcode 已移除(其 embedding backend 硬编码读 OPENAI_API_KEY),
  # 暂留数据与 key 待复用;长期无消费者则连同 secret 一并删
  siliconflow = {
    endpoints.openai = "https://api.siliconflow.cn/v1";
    apiKey.secretFile = "/run/secrets/siliconflow_api_key";
    embedding = {
      model = "Qwen/Qwen3-Embedding-8B";  # MTEB 榜首;代金券覆盖
      dim = 4096;
    };
  };
}
