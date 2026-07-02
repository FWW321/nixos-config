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
      "glm-5.2" = {
        contextWindow = 1000000;
        maxOutput = 131072;
        supportsVision = false;
      };
      "glm-5.1" = {
        contextWindow = 200000;
        maxOutput = 131072;
        supportsVision = false;
      };
    };
    defaultModel = "glm-5.2";
    smallModel = "glm-5.1";
  };
}
