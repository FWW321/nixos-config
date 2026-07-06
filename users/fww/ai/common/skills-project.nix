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
  # 运行时下载 skill(motion-ai-kit):非 nix store,activation script 下到中立目录
  "motion-ai-kit" = {
    runtime = {
      url = "https://api.motion.dev/registry/skills/motion-ai-kit";
      tokenFile = "/run/secrets/motion_plus_token";
    };
  };
}
