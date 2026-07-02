{ pkgs, inputs, lib, ... }:

let
  understandDirs = [
    "understand"
    "understand-chat"
    "understand-dashboard"
    "understand-diff"
    "understand-domain"
    "understand-explain"
    "understand-knowledge"
    "understand-onboard"
  ];

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
  # ── 单文件 skill（只取 SKILL.md）──
  "agent-browser" = {
    source = "${inputs.agent-browser-skill}/skills/agent-browser";
    entryFile = "SKILL.md";
    package = pkgs.agent-browser;
    env.AGENT_BROWSER_EXECUTABLE_PATH = "brave";
  };
  "humanizer-zh" = {
    source = inputs.humanizer-zh;
    entryFile = "SKILL.md";
  };
  "herdr" = {
    source = inputs.herdr;
    entryFile = "SKILL.md";
  };

  # ── 目录 skill（整个目录递归）──
  "git-workflow".source = inputs.git-workflow-skill;
  "surrealdb".source = inputs.surreal-skills;
  "shadcn".source = "${inputs.shadcn-ui}/skills/shadcn";
  "grill-with-docs".source = "${inputs.matt-skills}/skills/engineering/grill-with-docs";
  "grilling".source = "${inputs.matt-skills}/skills/productivity/grilling";
  "domain-modeling".source = "${inputs.matt-skills}/skills/engineering/domain-modeling";

  # ── 多目录 skill（同一 input 下的多个子目录）──
} // (lib.genAttrs understandDirs (dir: {
  source = "${inputs.understand-anything}/understand-anything-plugin/skills/${dir}";
})) // (lib.genAttrs makepadDirs (dir: {
  source = "${inputs.makepad-skills}/skills/${dir}";
}))

// {
  # ── 动态 skill（运行时下载）──
  "motion-ai-kit" = {
    runtime = {
      url = "https://api.motion.dev/registry/skills/motion-ai-kit";
      tokenFile = "/run/secrets/motion_plus_token";
    };
  };
}
