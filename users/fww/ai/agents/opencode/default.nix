# filepath: ~/nixos-config/users/fww/ai/agents/opencode/default.nix
# opencode agent — 目录聚合(dsh 同构拆分)
#
# 原 agents/opencode.nix 单文件拆为:
#   settings.nix  — programs.opencode 核心(model/provider/mcp/websearch)
#   mcp-hot-sync.nix — MCP 免重启热同步(activation 对账)
#   skills.nix    — skill/AGENTS.md 链接 + 依赖包 + env
#   agents.nix    — 子 agent 定义(~/.config/opencode/agents/*.md)
#   renderer.nix  — 项目级渲染器 + ai/registry.json
#
# 数据仍从 ../common 中立层拉取,本目录只做 opencode 格式转换
{ ... }:

{
  imports = [
    ./settings.nix
    ./skills.nix
    ./agents.nix
    ./renderer.nix
    ./mcp-hot-sync.nix
  ];
}
