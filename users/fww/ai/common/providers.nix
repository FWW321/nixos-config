# 模型能力数据来源：opencode models zhipuai-coding-plan --verbose
{
  zhipu = {
    # 各 agent 按自己使用的协议取对应 endpoint
    endpoints = {
      anthropic = "https://open.bigmodel.cn/api/anthropic";        # Claude Code 等
      openai = "https://open.bigmodel.cn/api/coding/paas/v4";       # opencode 等
    };
    apiKey.secretFile = "/run/secrets/zhipu_api_key";
    models = {
      "glm-5.3" = {
        contextWindow = 1000000;
        maxOutput = 131072;
        supportsVision = false;
      };
      "glm-5.2" = {
        contextWindow = 1000000;
        maxOutput = 131072;
        supportsVision = false;
      };
    };
    defaultModel = "glm-5.3";
    smallModel = "glm-5.2";
  };

  # SiliconFlow(硅基流动):OpenAI 兼容平台,代金券抵扣
  # 当前仅用于 jcode 远程 embedding(jcode embedding backend 硬编码读 OPENAI_API_KEY)
  siliconflow = {
    endpoints.openai = "https://api.siliconflow.cn/v1";
    apiKey.secretFile = "/run/secrets/siliconflow_api_key";
    embedding = {
      model = "Qwen/Qwen3-Embedding-8B";  # MTEB 榜首;代金券覆盖
      dim = 4096;
    };
  };
}
