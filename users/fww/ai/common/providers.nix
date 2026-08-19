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
