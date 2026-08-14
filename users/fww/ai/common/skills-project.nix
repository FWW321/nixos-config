# 项目级 skill(特定技术栈,项目级 agent skill add 启用)
# defaultEnabled 由 common/default.nix 注入(false)
{ inputs, lib, ... }:
let
  makepadDirs = [
    "makepad-2.0-animation"
    "makepad-2.0-app-structure"
    "makepad-2.0-design-judgment"
    "makepad-2.0-dsl"
    "makepad-2.0-events"
    "makepad-2.0-layout"
    "makepad-2.0-migration"
    "makepad-2.0-performance"
    "makepad-2.0-shaders"
    "makepad-2.0-splash"
    "makepad-2.0-theme"
    "makepad-2.0-troubleshooting"
    "makepad-2.0-vector"
    "makepad-2.0-widgets"
  ];
in
{
  "surrealdb" = {
    source = inputs.surreal-skills;
  };
  "shadcn" = {
    source = "${inputs.shadcn-ui}/skills/shadcn";
  };
}
// (lib.genAttrs makepadDirs (dir: {
  source = "${inputs.makepad-skills}/skills/${dir}";
}))
// {
  # Motion AI Kit skill(官方单 skill 结构,含 best-practices/codex/css-spring/
  # performance-audit/transition-preview 五个子模块)
  # 来源即官方仓库 plugins/motion/skills/,与 npx motion-ai 安装器所装内容同源;
  # MCP 部分在 mcp-project.nix(motion/motion-plus 托管端点),此处只是静态指引
  motion = {
    source = "${inputs.motion-ai-kit}/plugins/motion/skills/motion";
  };
}
