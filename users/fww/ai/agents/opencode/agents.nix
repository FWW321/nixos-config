# filepath: ~/nww/nixos-config/users/fww/ai/agents/opencode/agents.nix
# 子 agent 定义:v2 发现 ~/.config/opencode/agents/<name>.md(路径即 ID)
# Markdown body = system prompt,frontmatter 同 agents.<id> 配置字段
# 参考 https://opencode.ai/v2/docs/agents
{ ... }:

{
  xdg.configFile = {
    # ── vision:识图 subagent(MiniMax M3 原生视觉;glm-5.3 不支持视觉)──
    # 模型走 minimax-cn-coding-plan 订阅(与 glm 同一套 /run/secrets 密钥注入)
    # 智谱识图 MCP 已退役(见 common/mcp.nix 注释),本 agent 是 opencode 侧
    # 识图主入口;frontmatter description 会被注入所有会话的 system prompt
    # 充当主模型的委派路由信号,调整触发词在此改、勿另设他处
    "opencode/agents/vision.md".source = ./agents/vision.md;
  };
}
